use std::{
    collections::{HashMap, HashSet},
    error::Error,
    io,
};

use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Wrap},
    Frame, Terminal,
};

use crate::{
    components::Catalog,
    planner::{plan, Action, ComponentState, Plan},
    runtime::Runner,
};

struct App {
    action: Action,
    selected: Vec<bool>,
    cursor: usize,
    states: HashMap<String, ComponentState>,
    expanded: HashSet<String>,
    search: String,
    searching: bool,
    preview: Option<Result<Plan, String>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct VisibleRow {
    component_index: usize,
    depth: usize,
    is_last: bool,
    has_children: bool,
    expanded: bool,
}

impl App {
    fn new(catalog: &Catalog, states: HashMap<String, ComponentState>) -> Self {
        Self {
            action: Action::Install,
            selected: vec![false; catalog.components().len()],
            cursor: 0,
            states,
            expanded: catalog
                .components()
                .iter()
                .filter_map(|component| component.provider().map(str::to_owned))
                .collect(),
            search: String::new(),
            searching: false,
            preview: None,
        }
    }

    fn move_next(&mut self, catalog: &Catalog) {
        let row_count = self.visible_rows(catalog).len();
        if row_count > 0 {
            self.cursor = (self.cursor + 1) % row_count;
        }
    }

    fn move_previous(&mut self, catalog: &Catalog) {
        let row_count = self.visible_rows(catalog).len();
        if row_count == 0 {
            return;
        }
        self.cursor = if self.cursor == 0 {
            row_count - 1
        } else {
            self.cursor - 1
        };
    }

    fn toggle(&mut self, catalog: &Catalog) {
        let component_index = self
            .visible_rows(catalog)
            .get(self.cursor)
            .map(|row| row.component_index);
        if let Some(selected) = component_index.and_then(|index| self.selected.get_mut(index)) {
            *selected = !*selected;
        }
        self.preview = None;
    }

    fn expand(&mut self, catalog: &Catalog) {
        let row = self.visible_rows(catalog).get(self.cursor).copied();
        if let Some(row) = row.filter(|row| row.has_children) {
            self.expanded
                .insert(catalog.components()[row.component_index].id.clone());
        }
    }

    fn collapse_or_move_to_parent(&mut self, catalog: &Catalog) {
        let rows = self.visible_rows(catalog);
        let Some(row) = rows.get(self.cursor).copied() else {
            return;
        };
        let component = &catalog.components()[row.component_index];
        if row.has_children && row.expanded && self.search.is_empty() {
            self.expanded.remove(&component.id);
            return;
        }
        let Some(provider) = component.provider() else {
            return;
        };
        if let Some(parent_cursor) = rows
            .iter()
            .position(|row| catalog.components()[row.component_index].id == provider)
        {
            self.cursor = parent_cursor;
        }
    }

    fn visible_rows(&self, catalog: &Catalog) -> Vec<VisibleRow> {
        let indexes: HashMap<&str, usize> = catalog
            .components()
            .iter()
            .enumerate()
            .map(|(index, component)| (component.id.as_str(), index))
            .collect();
        let mut roots = Vec::new();
        let mut children: HashMap<usize, Vec<usize>> = HashMap::new();
        for (index, component) in catalog.components().iter().enumerate() {
            if let Some(provider_index) = component
                .provider()
                .and_then(|provider| indexes.get(provider))
                .copied()
            {
                children.entry(provider_index).or_default().push(index);
            } else {
                roots.push(index);
            }
        }

        let query = self.search.trim().to_ascii_lowercase();
        let visible_roots: Vec<_> = roots
            .into_iter()
            .filter(|index| subtree_matches(catalog, &children, *index, &query))
            .collect();
        let mut rows = Vec::new();
        for (position, index) in visible_roots.iter().copied().enumerate() {
            append_visible_rows(
                catalog,
                &children,
                index,
                0,
                position + 1 == visible_roots.len(),
                &query,
                &self.expanded,
                &mut rows,
            );
        }
        rows
    }

    fn search_push(&mut self, character: char) {
        self.search.push(character);
        self.cursor = 0;
    }

    fn search_pop(&mut self) {
        self.search.pop();
        self.cursor = 0;
    }

    fn clear_search(&mut self) {
        self.search.clear();
        self.searching = false;
        self.cursor = 0;
    }

    fn cycle_action(&mut self) {
        self.action = self.action.next();
        self.selected.fill(false);
        self.preview = None;
    }

    fn requested(&self, catalog: &Catalog) -> Vec<String> {
        catalog
            .components()
            .iter()
            .zip(&self.selected)
            .filter(|(_, selected)| **selected)
            .map(|(component, _)| component.id.clone())
            .collect()
    }

    fn build_preview(&mut self, catalog: &Catalog) {
        let requested = self.requested(catalog);
        self.preview = Some(
            plan(catalog, self.action, &requested, &self.states).map_err(|error| error.to_string()),
        );
    }
}

fn subtree_matches(
    catalog: &Catalog,
    children: &HashMap<usize, Vec<usize>>,
    index: usize,
    query: &str,
) -> bool {
    query.is_empty()
        || component_matches(&catalog.components()[index], query)
        || children.get(&index).is_some_and(|child_indexes| {
            child_indexes
                .iter()
                .any(|child| subtree_matches(catalog, children, *child, query))
        })
}

fn component_matches(component: &crate::components::Component, query: &str) -> bool {
    component.id.to_ascii_lowercase().contains(query)
        || component.name.to_ascii_lowercase().contains(query)
        || component.description.to_ascii_lowercase().contains(query)
        || component.category.to_string().contains(query)
}

#[allow(clippy::too_many_arguments)]
fn append_visible_rows(
    catalog: &Catalog,
    children: &HashMap<usize, Vec<usize>>,
    index: usize,
    depth: usize,
    is_last: bool,
    query: &str,
    expanded_ids: &HashSet<String>,
    rows: &mut Vec<VisibleRow>,
) {
    let visible_children: Vec<_> = children
        .get(&index)
        .into_iter()
        .flatten()
        .copied()
        .filter(|child| subtree_matches(catalog, children, *child, query))
        .collect();
    let has_children = !visible_children.is_empty();
    let expanded = has_children
        && (!query.is_empty() || expanded_ids.contains(&catalog.components()[index].id));
    rows.push(VisibleRow {
        component_index: index,
        depth,
        is_last,
        has_children,
        expanded,
    });
    if !expanded {
        return;
    }
    for (position, child) in visible_children.iter().copied().enumerate() {
        append_visible_rows(
            catalog,
            children,
            child,
            depth + 1,
            position + 1 == visible_children.len(),
            query,
            expanded_ids,
            rows,
        );
    }
}

pub fn run(catalog: &Catalog, runner: &Runner) -> Result<Option<Plan>, Box<dyn Error>> {
    let states = runner.inventory(catalog)?;
    let mut app = App::new(catalog, states);

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = run_app(&mut terminal, catalog, &mut app);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    result.map_err(Into::into)
}

fn run_app(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    catalog: &Catalog,
    app: &mut App,
) -> io::Result<Option<Plan>> {
    loop {
        terminal.draw(|frame| draw(frame, catalog, app))?;

        if let Event::Key(key) = event::read()? {
            if app.preview.is_some() {
                match key.code {
                    KeyCode::Char('q') => return Ok(None),
                    KeyCode::Esc => app.preview = None,
                    KeyCode::Enter => {
                        if let Some(Ok(plan)) = app.preview.take() {
                            return Ok(Some(plan));
                        }
                    }
                    _ => {}
                }
                continue;
            }

            if app.searching {
                match key.code {
                    KeyCode::Esc => app.clear_search(),
                    KeyCode::Enter => app.searching = false,
                    KeyCode::Backspace => app.search_pop(),
                    KeyCode::Char(character) => app.search_push(character),
                    _ => {}
                }
                continue;
            }

            match key.code {
                KeyCode::Char('q') => return Ok(None),
                KeyCode::Esc if !app.search.is_empty() => app.clear_search(),
                KeyCode::Esc => return Ok(None),
                KeyCode::Tab => app.cycle_action(),
                KeyCode::Down | KeyCode::Char('j') => app.move_next(catalog),
                KeyCode::Up | KeyCode::Char('k') => app.move_previous(catalog),
                KeyCode::Left | KeyCode::Char('h') => app.collapse_or_move_to_parent(catalog),
                KeyCode::Right | KeyCode::Char('l') => app.expand(catalog),
                KeyCode::Char('/') => app.searching = true,
                KeyCode::Char(' ') => app.toggle(catalog),
                KeyCode::Enter => app.build_preview(catalog),
                _ => {}
            }
        }
    }
}

fn draw(frame: &mut Frame<'_>, catalog: &Catalog, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(8),
            Constraint::Length(4),
        ])
        .split(frame.size());

    let search_status = if app.searching || !app.search.is_empty() {
        format!(
            "  ·  search: {}{}",
            app.search,
            if app.searching { "_" } else { "" }
        )
    } else {
        String::new()
    };
    let title = Paragraph::new(format!(
        "Action: {}  ·  selected: {}{}",
        app.action,
        app.selected.iter().filter(|selected| **selected).count(),
        search_status
    ))
    .block(Block::default().borders(Borders::ALL).title("oh-my-devpod"));
    frame.render_widget(title, chunks[0]);

    if let Some(preview) = &app.preview {
        draw_preview(frame, chunks[1], catalog, preview);
        let help = Paragraph::new("Enter execute · Esc back · q quit")
            .block(Block::default().borders(Borders::ALL).title("Review"));
        frame.render_widget(help, chunks[2]);
        return;
    }

    let rows = app.visible_rows(catalog);
    let mut items: Vec<ListItem> = rows
        .iter()
        .enumerate()
        .map(|(visible_index, row)| {
            let component = &catalog.components()[row.component_index];
            let marker = if app.selected[row.component_index] {
                "[x]"
            } else {
                "[ ]"
            };
            let cursor = if visible_index == app.cursor {
                "›"
            } else {
                " "
            };
            let state = app
                .states
                .get(&component.id)
                .copied()
                .unwrap_or(ComponentState::Missing);
            let state_style = match state {
                ComponentState::Missing => Style::default().fg(Color::DarkGray),
                ComponentState::Managed => Style::default().fg(Color::Green),
                ComponentState::ManagedBroken => Style::default().fg(Color::Red),
                ComponentState::External => Style::default().fg(Color::Yellow),
            };
            let indentation = "  ".repeat(row.depth.saturating_sub(1));
            let branch = if row.depth == 0 {
                String::new()
            } else if row.is_last {
                format!("{indentation}└─")
            } else {
                format!("{indentation}├─")
            };
            let fold = match (row.has_children, row.expanded) {
                (true, true) => "▾ ",
                (true, false) => "▸ ",
                (false, _) => "  ",
            };
            ListItem::new(Line::from(vec![
                Span::styled(cursor, Style::default().add_modifier(Modifier::BOLD)),
                Span::raw(" "),
                Span::styled(branch, Style::default().fg(Color::DarkGray)),
                Span::raw(fold),
                Span::raw(marker),
                Span::raw(" "),
                Span::raw(&component.name),
                Span::raw("  "),
                Span::styled(format!("[{state}]"), state_style),
                Span::raw("  "),
                Span::styled(
                    component.category.to_string(),
                    Style::default().fg(Color::DarkGray),
                ),
                Span::raw("  "),
                Span::styled(
                    format!("scope={}", component.scope()),
                    Style::default().fg(Color::DarkGray),
                ),
            ]))
        })
        .collect();

    if items.is_empty() {
        items.push(ListItem::new(Line::from(Span::styled(
            "  No components match the current search.",
            Style::default().fg(Color::DarkGray),
        ))));
    }

    let list = List::new(items).block(Block::default().borders(Borders::ALL).title("Components"));
    let mut list_state = ListState::default();
    if !rows.is_empty() {
        list_state.select(Some(app.cursor.min(rows.len() - 1)));
    }
    frame.render_stateful_widget(list, chunks[1], &mut list_state);

    let help = Paragraph::new(
        "Tab action · ↑/↓ or j/k move · ←/→ or h/l fold · Space select\n/ search · Enter review · q/Esc quit",
    )
    .block(Block::default().borders(Borders::ALL).title("Keys"));
    frame.render_widget(help, chunks[2]);
}

fn draw_preview(
    frame: &mut Frame<'_>,
    area: ratatui::layout::Rect,
    catalog: &Catalog,
    preview: &Result<Plan, String>,
) {
    let lines = match preview {
        Ok(plan) if plan.steps.is_empty() => {
            vec![Line::from(
                "Nothing to do; selected components already match the requested state.",
            )]
        }
        Ok(plan) => plan
            .steps
            .iter()
            .enumerate()
            .map(|(index, step)| {
                let component = catalog.get(&step.component_id);
                let name = component
                    .map(|component| component.name.as_str())
                    .unwrap_or(&step.component_id);
                let scope = component
                    .map(|component| component.scope())
                    .unwrap_or("user");
                Line::from(format!(
                    "{}. {} {} ({}, scope={})",
                    index + 1,
                    step.action,
                    name,
                    step.component_id,
                    scope
                ))
            })
            .collect(),
        Err(error) => vec![Line::from(Span::styled(
            error,
            Style::default().fg(Color::Red),
        ))],
    };

    let preview = Paragraph::new(lines).wrap(Wrap { trim: false }).block(
        Block::default()
            .borders(Borders::ALL)
            .title("Resolved execution plan"),
    );
    frame.render_widget(preview, area);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn catalog() -> Catalog {
        Catalog::parse(
            r#"
schema_version = 1

[[component]]
id = "linuxbrew"
name = "Linuxbrew"
description = "package manager"
category = "foundation"
module = "modules/linuxbrew.sh"
requires = []
install_requires = []
uninstall = false

[[component]]
id = "uv"
name = "uv"
description = "Python package manager"
category = "foundation"
module = "modules/uv.sh"
provider = "linuxbrew"
requires = []
install_requires = ["linuxbrew"]
uninstall = true

[[component]]
id = "gitee"
name = "Gitee CLI"
description = "standalone client"
category = "development"
module = "modules/gitee.sh"
requires = []
install_requires = []
uninstall = true

[[component]]
id = "ripgrep"
name = "ripgrep"
description = "recursive search"
category = "terminal"
module = "modules/ripgrep.sh"
provider = "linuxbrew"
requires = []
install_requires = ["linuxbrew"]
uninstall = true
"#,
        )
        .unwrap()
    }

    fn app(catalog: &Catalog) -> App {
        let states = catalog
            .components()
            .iter()
            .map(|component| (component.id.clone(), ComponentState::Missing))
            .collect();
        App::new(catalog, states)
    }

    fn visible_ids<'a>(app: &App, catalog: &'a Catalog) -> Vec<&'a str> {
        app.visible_rows(catalog)
            .iter()
            .map(|row| catalog.components()[row.component_index].id.as_str())
            .collect()
    }

    #[test]
    fn groups_components_below_their_provider_in_catalog_order() {
        let catalog = catalog();
        let app = app(&catalog);

        assert_eq!(
            visible_ids(&app, &catalog),
            vec!["linuxbrew", "uv", "ripgrep", "gitee"]
        );
        assert_eq!(
            app.visible_rows(&catalog)
                .iter()
                .map(|row| row.depth)
                .collect::<Vec<_>>(),
            vec![0, 1, 1, 0]
        );
    }

    #[test]
    fn collapses_and_expands_provider_children() {
        let catalog = catalog();
        let mut app = app(&catalog);

        app.collapse_or_move_to_parent(&catalog);
        assert_eq!(visible_ids(&app, &catalog), vec!["linuxbrew", "gitee"]);

        app.expand(&catalog);
        assert_eq!(
            visible_ids(&app, &catalog),
            vec!["linuxbrew", "uv", "ripgrep", "gitee"]
        );
    }

    #[test]
    fn left_on_child_moves_to_its_provider() {
        let catalog = catalog();
        let mut app = app(&catalog);
        app.cursor = 2;

        app.collapse_or_move_to_parent(&catalog);

        assert_eq!(app.cursor, 0);
        assert_eq!(
            visible_ids(&app, &catalog),
            vec!["linuxbrew", "uv", "ripgrep", "gitee"]
        );
    }

    #[test]
    fn search_reveals_matching_child_and_expands_its_ancestor() {
        let catalog = catalog();
        let mut app = app(&catalog);
        app.expanded.clear();
        app.search = "RIP".into();

        let rows = app.visible_rows(&catalog);
        assert_eq!(visible_ids(&app, &catalog), vec!["linuxbrew", "ripgrep"]);
        assert!(rows[0].expanded);
        assert_eq!(rows[1].depth, 1);
    }

    #[test]
    fn selecting_visible_child_resolves_the_correct_component() {
        let catalog = catalog();
        let mut app = app(&catalog);
        app.cursor = 2;

        app.toggle(&catalog);

        assert_eq!(app.requested(&catalog), vec!["ripgrep"]);
    }
}
