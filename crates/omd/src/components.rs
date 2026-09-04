use std::{
    collections::{HashMap, HashSet},
    error::Error,
    fmt::{self, Display, Formatter},
    fs,
    path::Path,
};

use serde::Deserialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Category {
    Foundation,
    Development,
    Terminal,
    Editor,
    Configuration,
}

impl Display for Category {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Foundation => "foundation",
            Self::Development => "development",
            Self::Terminal => "terminal",
            Self::Editor => "editor",
            Self::Configuration => "configuration",
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Component {
    pub id: String,
    pub name: String,
    pub description: String,
    pub category: Category,
    pub module: String,
    #[serde(default)]
    pub provider: Option<String>,
    pub requires: Vec<String>,
    pub install_requires: Vec<String>,
    pub uninstall: bool,
}

impl Component {
    pub fn scope(&self) -> &'static str {
        if self.id == "linuxbrew"
            || self
                .install_requires
                .iter()
                .any(|dependency| dependency == "linuxbrew")
        {
            "host"
        } else {
            "user"
        }
    }

    pub fn provider(&self) -> Option<&str> {
        self.provider.as_deref()
    }
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct ComponentManifest {
    schema_version: u32,
    #[serde(rename = "component")]
    components: Vec<Component>,
}

#[derive(Debug, Clone)]
pub struct Catalog {
    components: Vec<Component>,
    indexes: HashMap<String, usize>,
}

#[derive(Debug)]
pub struct CatalogError(String);

impl CatalogError {
    fn new(message: impl Into<String>) -> Self {
        Self(message.into())
    }
}

impl Display for CatalogError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.0)
    }
}

impl Error for CatalogError {}

impl Catalog {
    pub fn load(path: &Path) -> Result<Self, Box<dyn Error>> {
        let source = fs::read_to_string(path)?;
        let catalog = Self::parse(&source)?;
        catalog.validate_modules(path)?;
        Ok(catalog)
    }

    pub fn parse(source: &str) -> Result<Self, CatalogError> {
        let manifest: ComponentManifest =
            toml::from_str(source).map_err(|error| CatalogError::new(error.to_string()))?;

        if manifest.schema_version != 1 {
            return Err(CatalogError::new(format!(
                "unsupported component manifest schema version: {}",
                manifest.schema_version
            )));
        }

        if manifest.components.is_empty() {
            return Err(CatalogError::new("component manifest is empty"));
        }

        let mut indexes = HashMap::new();
        for (index, component) in manifest.components.iter().enumerate() {
            validate_component(component)?;
            if indexes.insert(component.id.clone(), index).is_some() {
                return Err(CatalogError::new(format!(
                    "duplicate component id: {}",
                    component.id
                )));
            }
        }

        for component in &manifest.components {
            for dependency in component
                .requires
                .iter()
                .chain(component.install_requires.iter())
            {
                if !indexes.contains_key(dependency) {
                    return Err(CatalogError::new(format!(
                        "component {} has unknown dependency {}",
                        component.id, dependency
                    )));
                }
            }

            if let Some(provider) = component.provider() {
                if !indexes.contains_key(provider) {
                    return Err(CatalogError::new(format!(
                        "component {} has unknown provider {}",
                        component.id, provider
                    )));
                }
                if !component
                    .install_requires
                    .iter()
                    .any(|dependency| dependency == provider)
                {
                    return Err(CatalogError::new(format!(
                        "component {} provider {} is not an install requirement",
                        component.id, provider
                    )));
                }
            }
        }

        let catalog = Self {
            components: manifest.components,
            indexes,
        };
        catalog.validate_acyclic()?;
        Ok(catalog)
    }

    pub fn components(&self) -> &[Component] {
        &self.components
    }

    pub fn get(&self, id: &str) -> Option<&Component> {
        self.indexes
            .get(id)
            .and_then(|index| self.components.get(*index))
    }

    pub fn require(&self, id: &str) -> Result<&Component, CatalogError> {
        self.get(id)
            .ok_or_else(|| CatalogError::new(format!("unknown component: {id}")))
    }

    fn validate_modules(&self, manifest_path: &Path) -> Result<(), CatalogError> {
        let root = manifest_path
            .parent()
            .ok_or_else(|| CatalogError::new("component manifest has no parent directory"))?;
        let modules_root = root.join("modules").canonicalize().map_err(|error| {
            CatalogError::new(format!("cannot resolve modules directory: {error}"))
        })?;

        for component in &self.components {
            let module = root
                .join(&component.module)
                .canonicalize()
                .map_err(|error| {
                    CatalogError::new(format!(
                        "cannot resolve module for {}: {} ({error})",
                        component.id, component.module
                    ))
                })?;
            if !module.starts_with(&modules_root) || !module.is_file() {
                return Err(CatalogError::new(format!(
                    "component {} module is outside the bundle modules directory: {}",
                    component.id,
                    module.display()
                )));
            }
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                if module
                    .metadata()
                    .map_err(|error| {
                        CatalogError::new(format!(
                            "cannot inspect module for {}: {error}",
                            component.id
                        ))
                    })?
                    .permissions()
                    .mode()
                    & 0o111
                    == 0
                {
                    return Err(CatalogError::new(format!(
                        "component {} module is not executable: {}",
                        component.id,
                        module.display()
                    )));
                }
            }
        }
        Ok(())
    }

    fn validate_acyclic(&self) -> Result<(), CatalogError> {
        let mut visiting = HashSet::new();
        let mut visited = HashSet::new();
        for component in &self.components {
            self.visit_for_cycle(&component.id, &mut visiting, &mut visited)?;
        }
        Ok(())
    }

    fn visit_for_cycle(
        &self,
        id: &str,
        visiting: &mut HashSet<String>,
        visited: &mut HashSet<String>,
    ) -> Result<(), CatalogError> {
        if visited.contains(id) {
            return Ok(());
        }
        if !visiting.insert(id.to_string()) {
            return Err(CatalogError::new(format!(
                "dependency cycle detected at component {id}"
            )));
        }

        let component = self.require(id)?;
        for dependency in component
            .requires
            .iter()
            .chain(component.install_requires.iter())
        {
            self.visit_for_cycle(dependency, visiting, visited)?;
        }

        visiting.remove(id);
        visited.insert(id.to_string());
        Ok(())
    }
}

fn validate_component(component: &Component) -> Result<(), CatalogError> {
    if component.id.is_empty()
        || !component.id.chars().all(|character| {
            character.is_ascii_lowercase()
                || character.is_ascii_digit()
                || character == '-'
                || character == '_'
        })
    {
        return Err(CatalogError::new(format!(
            "invalid component id: {}",
            component.id
        )));
    }

    if component.name.trim().is_empty() {
        return Err(CatalogError::new(format!(
            "component {} has an empty name",
            component.id
        )));
    }

    if component.module.starts_with('/')
        || component
            .module
            .split('/')
            .any(|segment| segment == ".." || segment.is_empty())
    {
        return Err(CatalogError::new(format!(
            "component {} has an unsafe module path: {}",
            component.id, component.module
        )));
    }

    let mut dependencies = HashSet::new();
    for dependency in component
        .requires
        .iter()
        .chain(component.install_requires.iter())
    {
        if dependency == &component.id {
            return Err(CatalogError::new(format!(
                "component {} depends on itself",
                component.id
            )));
        }
        if !dependencies.insert(dependency) {
            return Err(CatalogError::new(format!(
                "component {} declares duplicate dependency {}",
                component.id, dependency
            )));
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn manifest(components: &str) -> String {
        format!("schema_version = 1\n{components}")
    }

    #[test]
    fn parses_dependencies() {
        let source = manifest(
            r#"
[[component]]
id = "base"
name = "Base"
description = "base"
category = "foundation"
module = "modules/base.sh"
requires = []
install_requires = []
uninstall = true

[[component]]
id = "tool"
name = "Tool"
description = "tool"
category = "terminal"
module = "modules/tool.sh"
requires = ["base"]
install_requires = []
uninstall = true
"#,
        );

        let catalog = Catalog::parse(&source).unwrap();
        assert_eq!(catalog.require("tool").unwrap().requires, vec!["base"]);
    }

    #[test]
    fn parses_installation_provider() {
        let source = manifest(
            r#"
[[component]]
id = "linuxbrew"
name = "Linuxbrew"
description = "provider"
category = "foundation"
module = "modules/linuxbrew.sh"
requires = []
install_requires = []
uninstall = false

[[component]]
id = "tool"
name = "Tool"
description = "tool"
category = "terminal"
module = "modules/tool.sh"
provider = "linuxbrew"
requires = []
install_requires = ["linuxbrew"]
uninstall = true
"#,
        );

        let catalog = Catalog::parse(&source).unwrap();
        assert_eq!(
            catalog.require("tool").unwrap().provider(),
            Some("linuxbrew")
        );
    }

    #[test]
    fn rejects_provider_that_is_not_an_install_requirement() {
        let source = manifest(
            r#"
[[component]]
id = "linuxbrew"
name = "Linuxbrew"
description = "provider"
category = "foundation"
module = "modules/linuxbrew.sh"
requires = []
install_requires = []
uninstall = false

[[component]]
id = "tool"
name = "Tool"
description = "tool"
category = "terminal"
module = "modules/tool.sh"
provider = "linuxbrew"
requires = []
install_requires = []
uninstall = true
"#,
        );

        let error = Catalog::parse(&source).unwrap_err();
        assert!(error
            .to_string()
            .contains("provider linuxbrew is not an install requirement"));
    }

    #[test]
    fn rejects_unknown_dependencies() {
        let source = manifest(
            r#"
[[component]]
id = "tool"
name = "Tool"
description = "tool"
category = "terminal"
module = "modules/tool.sh"
requires = ["missing"]
install_requires = []
uninstall = true
"#,
        );

        let error = Catalog::parse(&source).unwrap_err();
        assert!(error.to_string().contains("unknown dependency missing"));
    }

    #[test]
    fn rejects_dependency_cycles() {
        let source = manifest(
            r#"
[[component]]
id = "one"
name = "One"
description = "one"
category = "terminal"
module = "modules/one.sh"
requires = ["two"]
install_requires = []
uninstall = true

[[component]]
id = "two"
name = "Two"
description = "two"
category = "terminal"
module = "modules/two.sh"
requires = ["one"]
install_requires = []
uninstall = true
"#,
        );

        let error = Catalog::parse(&source).unwrap_err();
        assert!(error.to_string().contains("dependency cycle"));
    }

    #[test]
    fn rejects_unsafe_module_paths() {
        let source = manifest(
            r#"
[[component]]
id = "tool"
name = "Tool"
description = "tool"
category = "terminal"
module = "../tool.sh"
requires = []
install_requires = []
uninstall = true
"#,
        );

        let error = Catalog::parse(&source).unwrap_err();
        assert!(error.to_string().contains("unsafe module path"));
    }

    #[test]
    fn rejects_unknown_manifest_fields() {
        let source = manifest(
            r#"
[[component]]
id = "tool"
name = "Tool"
description = "tool"
category = "terminal"
module = "modules/tool.sh"
requires = []
install_requires = []
uninstall = true
dependecies = ["typo"]
"#,
        );

        let error = Catalog::parse(&source).unwrap_err();
        assert!(error.to_string().contains("unknown field"));
    }

    #[test]
    fn rejects_duplicate_dependencies_across_dependency_types() {
        let source = manifest(
            r#"
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
id = "tool"
name = "Tool"
description = "tool"
category = "terminal"
module = "modules/tool.sh"
requires = ["base"]
install_requires = ["base"]
uninstall = true
"#,
        );

        let error = Catalog::parse(&source).unwrap_err();
        assert!(error.to_string().contains("duplicate dependency base"));
    }
}
