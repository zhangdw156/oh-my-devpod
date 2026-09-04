use std::{collections::HashMap, error::Error, io};

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
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
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
    preview: Option<Result<Plan, String>>,
}

impl App {
    fn new(catalog: &Catalog, states: HashMap<String, ComponentState>) -> Self {
        Self {
            action: Action::Install,
            selected: vec![false; catalog.components().len()],
            cursor: 0,
            states,
            preview: None,
        }
    }

    fn move_next(&mut self, catalog: &Catalog) {
        if !catalog.components().is_empty() {
            self.cursor = (self.cursor + 1) % catalog.components().len();
        }
    }

    fn move_previous(&mut self, catalog: &Catalog) {
        if catalog.components().is_empty() {
            return;
        }
        self.cursor = if self.cursor == 0 {
            catalog.components().len() - 1
        } else {
            self.cursor - 1
        };
    }

    fn toggle(&mut self) {
        if let Some(selected) = self.selected.get_mut(self.cursor) {
            *selected = !*selected;
        }
        self.preview = None;
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

            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => return Ok(None),
                KeyCode::Tab => app.cycle_action(),
                KeyCode::Down | KeyCode::Char('j') => app.move_next(catalog),
                KeyCode::Up | KeyCode::Char('k') => app.move_previous(catalog),
                KeyCode::Char(' ') => app.toggle(),
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

    let title = Paragraph::new(format!(
        "Action: {}  ·  selected: {}",
        app.action,
        app.selected.iter().filter(|selected| **selected).count()
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

    let items: Vec<ListItem> = catalog
        .components()
        .iter()
        .enumerate()
        .map(|(index, component)| {
            let marker = if app.selected[index] { "[x]" } else { "[ ]" };
            let cursor = if index == app.cursor { "›" } else { " " };
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
            ListItem::new(Line::from(vec![
                Span::styled(cursor, Style::default().add_modifier(Modifier::BOLD)),
                Span::raw(" "),
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

    let list = List::new(items).block(Block::default().borders(Borders::ALL).title("Components"));
    frame.render_widget(list, chunks[1]);

    let help =
        Paragraph::new("Tab action · ↑/↓ or j/k move · Space select · Enter review · q/Esc quit")
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
