use std::{
    collections::{HashMap, HashSet},
    error::Error,
    fmt::{self, Display, Formatter},
    str::FromStr,
};

use crate::components::{Catalog, Component};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    Install,
    Update,
    Uninstall,
}

impl Action {
    pub fn next(self) -> Self {
        match self {
            Self::Install => Self::Update,
            Self::Update => Self::Uninstall,
            Self::Uninstall => Self::Install,
        }
    }
}

impl Display for Action {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Install => "install",
            Self::Update => "update",
            Self::Uninstall => "uninstall",
        })
    }
}

impl FromStr for Action {
    type Err = PlanError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "install" => Ok(Self::Install),
            "update" => Ok(Self::Update),
            "uninstall" => Ok(Self::Uninstall),
            _ => Err(PlanError::new(format!(
                "unknown action {value}; expected install, update, or uninstall"
            ))),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ComponentState {
    Missing,
    Managed,
    ManagedBroken,
    External,
}

impl Display for ComponentState {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Missing => "missing",
            Self::Managed => "managed",
            Self::ManagedBroken => "managed-broken",
            Self::External => "external",
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanStep {
    pub component_id: String,
    pub action: Action,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Plan {
    pub action: Action,
    pub requested: Vec<String>,
    pub steps: Vec<PlanStep>,
    pub skipped: Vec<String>,
}

#[derive(Debug)]
pub struct PlanError(String);

impl PlanError {
    pub fn new(message: impl Into<String>) -> Self {
        Self(message.into())
    }
}

impl Display for PlanError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.0)
    }
}

impl Error for PlanError {}

pub fn plan(
    catalog: &Catalog,
    action: Action,
    requested: &[String],
    states: &HashMap<String, ComponentState>,
) -> Result<Plan, PlanError> {
    if requested.is_empty() {
        return Err(PlanError::new("select at least one component"));
    }
    validate_inventory(catalog, states)?;
    let requested = normalize_requested(catalog, requested)?;

    match action {
        Action::Install => plan_install(catalog, &requested, states),
        Action::Update => plan_update(catalog, &requested, states),
        Action::Uninstall => plan_uninstall(catalog, &requested, states),
    }
}

pub fn assumed_states(catalog: &Catalog, action: Action) -> HashMap<String, ComponentState> {
    let state = match action {
        Action::Install => ComponentState::Missing,
        Action::Update | Action::Uninstall => ComponentState::Managed,
    };
    catalog
        .components()
        .iter()
        .map(|component| (component.id.clone(), state))
        .collect()
}

fn plan_install(
    catalog: &Catalog,
    requested: &[String],
    states: &HashMap<String, ComponentState>,
) -> Result<Plan, PlanError> {
    let mut steps = Vec::new();
    let mut skipped = Vec::new();
    let mut visited = HashSet::new();
    for id in requested {
        ensure_installed(catalog, id, states, &mut visited, &mut steps, &mut skipped)?;
    }
    Ok(Plan {
        action: Action::Install,
        requested: requested.to_vec(),
        steps,
        skipped,
    })
}

fn plan_update(
    catalog: &Catalog,
    requested: &[String],
    states: &HashMap<String, ComponentState>,
) -> Result<Plan, PlanError> {
    let mut steps = Vec::new();
    let mut skipped = Vec::new();
    let mut visited = HashSet::new();
    let requested_set: HashSet<_> = requested.iter().cloned().collect();

    for id in requested {
        ensure_ready_for_update(
            catalog,
            id,
            &requested_set,
            states,
            &mut visited,
            &mut steps,
            &mut skipped,
        )?;
    }

    Ok(Plan {
        action: Action::Update,
        requested: requested.to_vec(),
        steps,
        skipped,
    })
}

fn ensure_ready_for_update(
    catalog: &Catalog,
    id: &str,
    requested: &HashSet<String>,
    states: &HashMap<String, ComponentState>,
    visited: &mut HashSet<String>,
    steps: &mut Vec<PlanStep>,
    skipped: &mut Vec<String>,
) -> Result<(), PlanError> {
    if visited.contains(id) {
        return Ok(());
    }

    let component = catalog
        .require(id)
        .map_err(|error| PlanError::new(error.to_string()))?;
    for dependency in &component.requires {
        ensure_ready_for_update(
            catalog, dependency, requested, states, visited, steps, skipped,
        )?;
    }

    let state = state_of(states, id)?;
    if state == ComponentState::Missing || requested.contains(id) {
        for dependency in &component.install_requires {
            ensure_ready_for_update(
                catalog, dependency, requested, states, visited, steps, skipped,
            )?;
        }
    }

    match state {
        ComponentState::Missing => steps.push(PlanStep {
            component_id: id.to_string(),
            action: Action::Install,
        }),
        ComponentState::Managed | ComponentState::ManagedBroken if requested.contains(id) => steps
            .push(PlanStep {
                component_id: id.to_string(),
                action: Action::Update,
            }),
        ComponentState::External if requested.contains(id) => {
            return Err(PlanError::new(format!(
                "cannot update external component {id}; it is not managed by oh-my-devpod"
            )))
        }
        ComponentState::Managed | ComponentState::ManagedBroken | ComponentState::External => {
            if !skipped.iter().any(|item| item == id) {
                skipped.push(id.to_string());
            }
        }
    }

    visited.insert(id.to_string());
    Ok(())
}

fn plan_uninstall(
    catalog: &Catalog,
    requested: &[String],
    states: &HashMap<String, ComponentState>,
) -> Result<Plan, PlanError> {
    let selected: HashSet<_> = requested.iter().cloned().collect();

    for id in requested {
        let component = catalog
            .require(id)
            .map_err(|error| PlanError::new(error.to_string()))?;
        if !component.uninstall {
            return Err(PlanError::new(format!(
                "{} cannot be removed by the normal uninstall flow",
                component.name
            )));
        }
        match state_of(states, id)? {
            ComponentState::External => {
                return Err(PlanError::new(format!(
                    "cannot uninstall external component {id}; it is not managed by oh-my-devpod"
                )))
            }
            ComponentState::Missing | ComponentState::Managed | ComponentState::ManagedBroken => {}
        }
    }

    for component in catalog.components() {
        if selected.contains(&component.id)
            || state_of(states, &component.id)? == ComponentState::Missing
        {
            continue;
        }
        if depends_on_any(catalog, component, &selected, &mut HashSet::new())? {
            let targets = requested.join(", ");
            return Err(PlanError::new(format!(
                "cannot uninstall {targets} while installed dependant {} remains",
                component.id,
            )));
        }
    }

    let mut ordered = runtime_dependency_order(catalog, requested)?;
    ordered.retain(|id| selected.contains(id));
    ordered.reverse();

    let mut steps = Vec::new();
    let mut skipped = Vec::new();
    for id in ordered {
        match state_of(states, &id)? {
            ComponentState::Managed | ComponentState::ManagedBroken => steps.push(PlanStep {
                component_id: id,
                action: Action::Uninstall,
            }),
            ComponentState::Missing => skipped.push(id),
            ComponentState::External => unreachable!("external components are rejected above"),
        }
    }

    Ok(Plan {
        action: Action::Uninstall,
        requested: requested.to_vec(),
        steps,
        skipped,
    })
}

fn ensure_installed(
    catalog: &Catalog,
    id: &str,
    states: &HashMap<String, ComponentState>,
    visited: &mut HashSet<String>,
    steps: &mut Vec<PlanStep>,
    skipped: &mut Vec<String>,
) -> Result<(), PlanError> {
    if visited.contains(id) {
        return Ok(());
    }

    let component = catalog
        .require(id)
        .map_err(|error| PlanError::new(error.to_string()))?;
    for dependency in &component.requires {
        ensure_installed(catalog, dependency, states, visited, steps, skipped)?;
    }

    match state_of(states, id)? {
        ComponentState::Missing => {
            for dependency in &component.install_requires {
                ensure_installed(catalog, dependency, states, visited, steps, skipped)?;
            }
            visited.insert(id.to_string());
            steps.push(PlanStep {
                component_id: id.to_string(),
                action: Action::Install,
            });
        }
        ComponentState::ManagedBroken => {
            for dependency in &component.install_requires {
                ensure_installed(catalog, dependency, states, visited, steps, skipped)?;
            }
            visited.insert(id.to_string());
            steps.push(PlanStep {
                component_id: id.to_string(),
                action: Action::Update,
            });
        }
        ComponentState::Managed | ComponentState::External => {
            visited.insert(id.to_string());
            if !skipped.iter().any(|item| item == id) {
                skipped.push(id.to_string());
            }
        }
    }
    Ok(())
}

fn depends_on_any(
    catalog: &Catalog,
    component: &Component,
    targets: &HashSet<String>,
    visiting: &mut HashSet<String>,
) -> Result<bool, PlanError> {
    if !visiting.insert(component.id.clone()) {
        return Ok(false);
    }

    for dependency in &component.requires {
        if targets.contains(dependency) {
            return Ok(true);
        }
        let dependency_component = catalog
            .require(dependency)
            .map_err(|error| PlanError::new(error.to_string()))?;
        if depends_on_any(catalog, dependency_component, targets, visiting)? {
            return Ok(true);
        }
    }
    Ok(false)
}

fn normalize_requested(catalog: &Catalog, requested: &[String]) -> Result<Vec<String>, PlanError> {
    let requested_set: HashSet<_> = requested.iter().cloned().collect();
    for id in &requested_set {
        catalog
            .require(id)
            .map_err(|error| PlanError::new(error.to_string()))?;
    }
    Ok(catalog
        .components()
        .iter()
        .filter(|component| requested_set.contains(&component.id))
        .map(|component| component.id.clone())
        .collect())
}

fn runtime_dependency_order(
    catalog: &Catalog,
    requested: &[String],
) -> Result<Vec<String>, PlanError> {
    let mut visited = HashSet::new();
    let mut ordered = Vec::new();
    for id in requested {
        visit_runtime_dependencies(catalog, id, &mut visited, &mut ordered)?;
    }
    Ok(ordered)
}

fn visit_runtime_dependencies(
    catalog: &Catalog,
    id: &str,
    visited: &mut HashSet<String>,
    ordered: &mut Vec<String>,
) -> Result<(), PlanError> {
    if !visited.insert(id.to_string()) {
        return Ok(());
    }
    let component = catalog
        .require(id)
        .map_err(|error| PlanError::new(error.to_string()))?;
    for dependency in &component.requires {
        visit_runtime_dependencies(catalog, dependency, visited, ordered)?;
    }
    ordered.push(id.to_string());
    Ok(())
}

fn validate_inventory(
    catalog: &Catalog,
    states: &HashMap<String, ComponentState>,
) -> Result<(), PlanError> {
    for component in catalog.components() {
        if !states.contains_key(&component.id) {
            return Err(PlanError::new(format!(
                "component state is missing for {}",
                component.id
            )));
        }
    }
    Ok(())
}

fn state_of(
    states: &HashMap<String, ComponentState>,
    id: &str,
) -> Result<ComponentState, PlanError> {
    states
        .get(id)
        .copied()
        .ok_or_else(|| PlanError::new(format!("component state is missing for {id}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn catalog() -> Catalog {
        Catalog::parse(
            r#"
schema_version = 1

[[component]]
id = "base"
name = "Base"
description = "base"
category = "foundation"
module = "modules/base.sh"
requires = []
install_requires = []
uninstall = false

[[component]]
id = "editor"
name = "Editor"
description = "editor"
category = "editor"
module = "modules/editor.sh"
requires = []
install_requires = ["base"]
uninstall = true

[[component]]
id = "config"
name = "Config"
description = "config"
category = "configuration"
module = "modules/config.sh"
requires = ["editor"]
install_requires = []
uninstall = true
"#,
        )
        .unwrap()
    }

    #[test]
    fn install_orders_install_requirements_and_runtime_dependencies_first() {
        let catalog = catalog();
        let states = assumed_states(&catalog, Action::Install);
        let plan = plan(&catalog, Action::Install, &["config".into()], &states).unwrap();
        let ids: Vec<_> = plan
            .steps
            .iter()
            .map(|step| step.component_id.as_str())
            .collect();
        assert_eq!(ids, vec!["base", "editor", "config"]);
    }

    #[test]
    fn external_dependency_stops_provider_traversal() {
        let catalog = catalog();
        let mut states = assumed_states(&catalog, Action::Install);
        states.insert("editor".into(), ComponentState::External);
        let plan = plan(&catalog, Action::Install, &["config".into()], &states).unwrap();
        let ids: Vec<_> = plan
            .steps
            .iter()
            .map(|step| step.component_id.as_str())
            .collect();
        assert_eq!(ids, vec!["config"]);
        assert_eq!(plan.skipped, vec!["editor"]);
    }

    #[test]
    fn installed_component_still_repairs_missing_runtime_dependency() {
        let catalog = catalog();
        let mut states = assumed_states(&catalog, Action::Install);
        states.insert("config".into(), ComponentState::Managed);
        states.insert("editor".into(), ComponentState::Missing);
        let plan = plan(&catalog, Action::Install, &["config".into()], &states).unwrap();
        let ids: Vec<_> = plan
            .steps
            .iter()
            .map(|step| step.component_id.as_str())
            .collect();
        assert_eq!(ids, vec!["base", "editor"]);
    }

    #[test]
    fn install_repairs_broken_managed_component() {
        let catalog = catalog();
        let mut states = assumed_states(&catalog, Action::Install);
        states.insert("editor".into(), ComponentState::ManagedBroken);
        let plan = plan(&catalog, Action::Install, &["editor".into()], &states).unwrap();
        assert_eq!(
            plan.steps,
            vec![
                PlanStep {
                    component_id: "base".into(),
                    action: Action::Install,
                },
                PlanStep {
                    component_id: "editor".into(),
                    action: Action::Update,
                }
            ]
        );
    }

    #[test]
    fn update_installs_missing_install_requirements() {
        let catalog = catalog();
        let mut states = assumed_states(&catalog, Action::Update);
        states.insert("base".into(), ComponentState::Missing);
        let plan = plan(&catalog, Action::Update, &["editor".into()], &states).unwrap();
        assert_eq!(
            plan.steps,
            vec![
                PlanStep {
                    component_id: "base".into(),
                    action: Action::Install
                },
                PlanStep {
                    component_id: "editor".into(),
                    action: Action::Update
                }
            ]
        );
    }

    #[test]
    fn requested_dependency_is_still_updated_after_satisfying_another_request() {
        let catalog = catalog();
        let states = assumed_states(&catalog, Action::Update);
        let plan = plan(
            &catalog,
            Action::Update,
            &["config".into(), "editor".into()],
            &states,
        )
        .unwrap();
        let updates: Vec<_> = plan
            .steps
            .iter()
            .filter(|step| step.action == Action::Update)
            .map(|step| step.component_id.as_str())
            .collect();
        assert_eq!(updates, vec!["editor", "config"]);
    }

    #[test]
    fn uninstall_blocks_installed_runtime_dependants() {
        let catalog = catalog();
        let states = assumed_states(&catalog, Action::Uninstall);
        let error = plan(&catalog, Action::Uninstall, &["editor".into()], &states).unwrap_err();
        assert!(error.to_string().contains("dependant config"));
    }

    #[test]
    fn uninstall_orders_dependants_first() {
        let catalog = catalog();
        let states = assumed_states(&catalog, Action::Uninstall);
        let plan = plan(
            &catalog,
            Action::Uninstall,
            &["config".into(), "editor".into()],
            &states,
        )
        .unwrap();
        let ids: Vec<_> = plan
            .steps
            .iter()
            .map(|step| step.component_id.as_str())
            .collect();
        assert_eq!(ids, vec!["config", "editor"]);
    }

    #[test]
    fn uninstall_does_not_treat_install_provider_as_runtime_dependant() {
        let catalog = catalog();
        let mut states = assumed_states(&catalog, Action::Uninstall);
        states.insert("config".into(), ComponentState::Missing);
        let error = plan(&catalog, Action::Uninstall, &["base".into()], &states).unwrap_err();
        assert!(error.to_string().contains("cannot be removed"));
    }

    #[test]
    fn uninstall_rejects_external_components() {
        let catalog = catalog();
        let mut states = assumed_states(&catalog, Action::Uninstall);
        states.insert("config".into(), ComponentState::Missing);
        states.insert("editor".into(), ComponentState::External);
        let error = plan(&catalog, Action::Uninstall, &["editor".into()], &states).unwrap_err();
        assert!(error.to_string().contains("external component editor"));
    }

    #[test]
    fn missing_inventory_entry_is_an_error() {
        let catalog = catalog();
        let mut states = assumed_states(&catalog, Action::Install);
        states.remove("base");
        let error = plan(&catalog, Action::Install, &["config".into()], &states).unwrap_err();
        assert!(error.to_string().contains("state is missing for base"));
    }
}
