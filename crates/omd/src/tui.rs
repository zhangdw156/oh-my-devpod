use std::io;

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
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Frame, Terminal,
};

use crate::components::{catalog, SelectionState};

pub fn run() -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = run_app(&mut terminal);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    result
}

fn run_app(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> io::Result<()> {
    let mut state = SelectionState::new(catalog());

    loop {
        terminal.draw(|frame| draw(frame, &state))?;

        if let Event::Key(key) = event::read()? {
            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                KeyCode::Down | KeyCode::Char('j') => state.move_next(),
                KeyCode::Up | KeyCode::Char('k') => state.move_previous(),
                KeyCode::Char(' ') => {
                    state.toggle_current();
                }
                _ => {}
            }
        }
    }
}

fn draw(frame: &mut Frame<'_>, state: &SelectionState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(5),
            Constraint::Length(3),
        ])
        .split(frame.size());

    let title = Paragraph::new("oh-my-devpod installer (omd)")
        .block(Block::default().borders(Borders::ALL).title("Installer"));
    frame.render_widget(title, chunks[0]);

    let items: Vec<ListItem> = state
        .components()
        .iter()
        .enumerate()
        .map(|(index, component)| {
            let marker = if component.required {
                "[required]"
            } else if state.is_selected(component.id) {
                "[x]"
            } else {
                "[ ]"
            };
            let cursor = if index == state.cursor() { "›" } else { " " };
            let style = if component.required {
                Style::default().fg(Color::Yellow)
            } else {
                Style::default()
            };
            ListItem::new(Line::from(vec![
                Span::styled(cursor, Style::default().add_modifier(Modifier::BOLD)),
                Span::raw(" "),
                Span::styled(marker, style),
                Span::raw(" "),
                Span::raw(component.name),
                Span::raw("  "),
                Span::styled(component.id, Style::default().fg(Color::DarkGray)),
            ]))
        })
        .collect();

    let list = List::new(items).block(Block::default().borders(Borders::ALL).title("Components"));
    frame.render_widget(list, chunks[1]);

    let help = Paragraph::new("↑/↓ move · Space toggle optional · q/Esc quit")
        .block(Block::default().borders(Borders::ALL).title("Keys"));
    frame.render_widget(help, chunks[2]);
}
