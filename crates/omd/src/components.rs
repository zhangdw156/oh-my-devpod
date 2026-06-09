#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Component {
    pub id: &'static str,
    pub name: &'static str,
    pub required: bool,
    pub module: &'static str,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ToggleResult {
    ToggledOn,
    ToggledOff,
    RequiredUnchanged,
    UnknownComponent,
}

#[derive(Debug, Clone)]
pub struct SelectionState {
    components: Vec<Component>,
    selected: Vec<bool>,
    cursor: usize,
}

pub fn catalog() -> Vec<Component> {
    vec![
        Component {
            id: "brew",
            name: "Homebrew on Linux",
            required: true,
            module: "modules/core/brew.sh",
        },
        Component {
            id: "zsh",
            name: "zsh environment",
            required: true,
            module: "modules/core/zsh.sh",
        },
        Component {
            id: "base-tools",
            name: "Baseline development tools",
            required: true,
            module: "modules/core/base-tools.sh",
        },
        Component {
            id: "claude-code",
            name: "Claude Code",
            required: false,
            module: "modules/optional/claude-code.sh",
        },
        Component {
            id: "codex",
            name: "Codex CLI",
            required: false,
            module: "modules/optional/codex.sh",
        },
        Component {
            id: "opencode",
            name: "OpenCode",
            required: false,
            module: "modules/optional/opencode.sh",
        },
        Component {
            id: "copilot",
            name: "GitHub Copilot CLI",
            required: false,
            module: "modules/optional/copilot.sh",
        },
        Component {
            id: "gemini",
            name: "Gemini CLI",
            required: false,
            module: "modules/optional/gemini.sh",
        },
    ]
}

impl SelectionState {
    pub fn new(components: Vec<Component>) -> Self {
        let selected = components
            .iter()
            .map(|component| component.required)
            .collect();
        Self {
            components,
            selected,
            cursor: 0,
        }
    }

    pub fn components(&self) -> &[Component] {
        &self.components
    }

    pub fn cursor(&self) -> usize {
        self.cursor
    }

    pub fn is_selected(&self, id: &str) -> bool {
        self.components
            .iter()
            .position(|component| component.id == id)
            .map(|index| self.selected[index])
            .unwrap_or(false)
    }

    pub fn selected_component(&self) -> Option<&Component> {
        self.components.get(self.cursor)
    }

    pub fn move_next(&mut self) {
        if self.components.is_empty() {
            return;
        }
        self.cursor = (self.cursor + 1) % self.components.len();
    }

    pub fn move_previous(&mut self) {
        if self.components.is_empty() {
            return;
        }
        if self.cursor == 0 {
            self.cursor = self.components.len() - 1;
        } else {
            self.cursor -= 1;
        }
    }

    pub fn toggle_current(&mut self) -> ToggleResult {
        match self.selected_component() {
            Some(component) => self.toggle(component.id),
            None => ToggleResult::UnknownComponent,
        }
    }

    pub fn toggle(&mut self, id: &str) -> ToggleResult {
        let Some(index) = self
            .components
            .iter()
            .position(|component| component.id == id)
        else {
            return ToggleResult::UnknownComponent;
        };

        if self.components[index].required {
            return ToggleResult::RequiredUnchanged;
        }

        self.selected[index] = !self.selected[index];
        if self.selected[index] {
            ToggleResult::ToggledOn
        } else {
            ToggleResult::ToggledOff
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_has_required_core_components() {
        let catalog = catalog();
        let required: Vec<_> = catalog
            .iter()
            .filter(|c| c.required)
            .map(|c| c.id)
            .collect();
        assert_eq!(required, vec!["brew", "zsh", "base-tools"]);
    }

    #[test]
    fn optional_components_start_unselected() {
        let state = SelectionState::new(catalog());
        assert!(!state.is_selected("claude-code"));
        assert!(!state.is_selected("codex"));
        assert!(!state.is_selected("opencode"));
        assert!(!state.is_selected("copilot"));
        assert!(!state.is_selected("gemini"));
    }

    #[test]
    fn required_components_cannot_be_toggled_off() {
        let mut state = SelectionState::new(catalog());
        assert!(state.is_selected("brew"));
        assert_eq!(state.toggle("brew"), ToggleResult::RequiredUnchanged);
        assert!(state.is_selected("brew"));
    }
}
