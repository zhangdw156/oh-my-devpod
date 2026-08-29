use std::{
    collections::HashMap,
    env,
    error::Error,
    fmt::{self, Display, Formatter},
    fs::{self, OpenOptions},
    io::Write,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

use crate::{
    components::{Catalog, Component},
    planner::{Action, ComponentState, Plan, PlanStep},
};

#[derive(Debug, Clone)]
pub struct RuntimePaths {
    pub root: PathBuf,
    pub manifest: PathBuf,
    pub version: String,
    pub mirror_profile: MirrorProfile,
    pub config_dir: PathBuf,
    pub prefix: PathBuf,
    pub bin_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub state_dir: PathBuf,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MirrorProfile {
    Upstream,
    China,
}

impl MirrorProfile {
    fn discover(config_dir: &Path) -> Result<Self, Box<dyn Error>> {
        let source_file = config_dir.join("source");
        match fs::read_to_string(source_file) {
            Ok(source) => {
                for line in source.lines() {
                    let value = line.trim();
                    if let Some(profile) = value.strip_prefix("mirror_profile=") {
                        return Self::parse(profile);
                    }
                    if value == "gitee" || value == "source=gitee" {
                        return Ok(Self::China);
                    }
                    if value == "github" || value == "source=github" {
                        return Ok(Self::Upstream);
                    }
                }
                eprintln!("Warning: invalid saved source; using the upstream mirror profile");
                return Ok(Self::Upstream);
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(error) => return Err(error.into()),
        }

        let mirror_file = config_dir.join("mirror-profile");
        match fs::read_to_string(&mirror_file) {
            Ok(profile) => match Self::parse(&profile) {
                Ok(profile) => return Ok(profile),
                Err(error) => eprintln!("Warning: {error}; using the upstream mirror profile"),
            },
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(error) => return Err(error.into()),
        }

        if let Ok(value) = env::var("OHMYDEVPOD_MIRROR_PROFILE") {
            return Self::parse(&value);
        }
        Ok(Self::Upstream)
    }

    fn parse(value: &str) -> Result<Self, Box<dyn Error>> {
        match value.trim() {
            "upstream" | "github" => Ok(Self::Upstream),
            "cn" | "gitee" => Ok(Self::China),
            value => Err(RuntimeError::new(format!(
                "invalid mirror profile {value}; expected upstream or cn"
            ))
            .into()),
        }
    }
}

impl RuntimePaths {
    pub fn discover() -> Result<Self, Box<dyn Error>> {
        let root = discover_root()?;
        let manifest = root.join("components.toml");
        if !manifest.is_file() {
            return Err(RuntimeError::new(format!(
                "component manifest not found: {}",
                manifest.display()
            ))
            .into());
        }
        let version = fs::read_to_string(root.join("VERSION"))
            .map(|value| value.trim().to_string())
            .unwrap_or_else(|_| env!("CARGO_PKG_VERSION").to_string());
        if version.is_empty() {
            return Err(RuntimeError::new("bundle VERSION is empty").into());
        }
        if !root.join("modules/lib/common.sh").is_file() {
            return Err(RuntimeError::new("bundle is missing modules/lib/common.sh").into());
        }
        if !root.join("modules/lib/postflight.sh").is_file() {
            return Err(RuntimeError::new("bundle is missing modules/lib/postflight.sh").into());
        }
        if !root.join("install/update.sh").is_file() {
            return Err(RuntimeError::new("bundle is missing install/update.sh").into());
        }
        let home = env::var_os("HOME")
            .map(PathBuf::from)
            .ok_or_else(|| RuntimeError::new("HOME is not set"))?;
        let config_dir = env::var_os("OHMYDEVPOD_CONFIG_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                env::var_os("XDG_CONFIG_HOME")
                    .map(PathBuf::from)
                    .unwrap_or_else(|| home.join(".config"))
                    .join("oh-my-devpod")
            });
        let data_home = env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/share"));
        let prefix = env::var_os("OHMYDEVPOD_PREFIX")
            .map(PathBuf::from)
            .or_else(|| installed_prefix(&root))
            .or_else(|| configured_path(&config_dir.join("install-prefix")))
            .unwrap_or_else(|| data_home.join("oh-my-devpod"));
        let bin_dir = env::var_os("OHMYDEVPOD_BIN_DIR")
            .map(PathBuf::from)
            .or_else(|| configured_path(&config_dir.join("bin-dir")))
            .or_else(active_bin_dir)
            .unwrap_or_else(|| home.join(".local/bin"));
        let cache_dir = env::var_os("OHMYDEVPOD_CACHE_DIR")
            .map(PathBuf::from)
            .or_else(|| configured_path(&config_dir.join("cache-dir")))
            .unwrap_or_else(|| {
                env::var_os("XDG_CACHE_HOME")
                    .map(PathBuf::from)
                    .unwrap_or_else(|| home.join(".cache"))
                    .join("oh-my-devpod")
            });
        let state_dir = env::var_os("OHMYDEVPOD_STATE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                env::var_os("XDG_STATE_HOME")
                    .map(PathBuf::from)
                    .unwrap_or_else(|| home.join(".local/state"))
                    .join("oh-my-devpod")
            });
        Ok(Self {
            root,
            manifest,
            version,
            mirror_profile: MirrorProfile::discover(&config_dir)?,
            config_dir,
            prefix,
            bin_dir,
            cache_dir,
            state_dir,
        })
    }
}

#[derive(Debug, Clone)]
pub struct Runner {
    root: PathBuf,
    version: String,
    mirror_profile: MirrorProfile,
    config_dir: PathBuf,
    prefix: PathBuf,
    bin_dir: PathBuf,
    cache_dir: PathBuf,
    state_dir: PathBuf,
}

impl Runner {
    pub fn new(paths: &RuntimePaths) -> Self {
        Self {
            root: paths.root.clone(),
            version: paths.version.clone(),
            mirror_profile: paths.mirror_profile,
            config_dir: paths.config_dir.clone(),
            prefix: paths.prefix.clone(),
            bin_dir: paths.bin_dir.clone(),
            cache_dir: paths.cache_dir.clone(),
            state_dir: paths.state_dir.clone(),
        }
    }

    pub fn self_update(&self, source_flag: Option<&str>) -> Result<(), Box<dyn Error>> {
        let _lock = ExecutionLock::acquire_at(&self.state_dir)?;
        let script = self.root.join("install/update.sh");
        let mut command = self.base_script_command(&script);
        command.env("OHMYDEVPOD_CURRENT_VERSION", &self.version);
        if let Some(flag) = source_flag {
            command.arg(flag);
        }
        let status = command
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()?;
        if status.success() {
            Ok(())
        } else {
            Err(RuntimeError::new(format!("self-update failed with {status}")).into())
        }
    }

    pub fn component_state(&self, component: &Component) -> Result<ComponentState, Box<dyn Error>> {
        let managed = self.query(component, "managed")?;
        let present = self.query(component, "status")?;
        match (managed, present) {
            (true, true) => Ok(ComponentState::Managed),
            (true, false) => Ok(ComponentState::ManagedBroken),
            (false, true) => Ok(ComponentState::External),
            (false, false) => Ok(ComponentState::Missing),
        }
    }

    pub fn inventory(
        &self,
        catalog: &Catalog,
    ) -> Result<HashMap<String, ComponentState>, Box<dyn Error>> {
        catalog
            .components()
            .iter()
            .map(|component| {
                self.component_state(component)
                    .map(|state| (component.id.clone(), state))
            })
            .collect()
    }

    pub fn execute_confirmed_plan(
        &self,
        catalog: &Catalog,
        reviewed: &Plan,
    ) -> Result<(), Box<dyn Error>> {
        let _lock = ExecutionLock::acquire_at(&self.state_dir)?;
        let states = self.inventory(catalog)?;
        let current = crate::planner::plan(catalog, reviewed.action, &reviewed.requested, &states)?;
        if &current != reviewed {
            return Err(RuntimeError::new(
                "component state changed after plan review; reopen omd and confirm the new plan",
            )
            .into());
        }
        self.execute_plan_locked(catalog, reviewed)
    }

    fn execute_plan_locked(&self, catalog: &Catalog, plan: &Plan) -> Result<(), Box<dyn Error>> {
        if plan.steps.is_empty() {
            self.execute_postflight(plan.action)?;
            println!("Nothing to do.");
            return Ok(());
        }

        for (index, step) in plan.steps.iter().enumerate() {
            let component = catalog.require(&step.component_id)?;
            println!(
                "==> [{}/{}] {} {}",
                index + 1,
                plan.steps.len(),
                step.action,
                component.name
            );
            self.execute_step(component, step, false)?;
        }
        self.execute_postflight(plan.action)?;
        println!("==> Completed {} step(s).", plan.steps.len());
        Ok(())
    }

    pub fn dry_run_plan(&self, catalog: &Catalog, plan: &Plan) -> Result<(), Box<dyn Error>> {
        for step in &plan.steps {
            let component = catalog.require(&step.component_id)?;
            self.execute_step(component, step, true)?;
        }
        Ok(())
    }

    fn query(&self, component: &Component, action: &str) -> Result<bool, Box<dyn Error>> {
        let status = self
            .command(component, action)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()?;
        match status.code() {
            Some(0) => Ok(true),
            Some(1) => Ok(false),
            Some(code) => Err(RuntimeError::new(format!(
                "module {} returned invalid status code {code} for {action}",
                component.id
            ))
            .into()),
            None => Err(RuntimeError::new(format!(
                "module {} terminated by signal during {action}",
                component.id
            ))
            .into()),
        }
    }

    fn execute_step(
        &self,
        component: &Component,
        step: &PlanStep,
        dry_run: bool,
    ) -> Result<(), Box<dyn Error>> {
        let mut command = self.command(component, &step.action.to_string());
        if dry_run {
            command.arg("--dry-run");
        }
        let status = command
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()?;
        if status.success() {
            Ok(())
        } else {
            Err(RuntimeError::new(format!(
                "{} {} failed with {}",
                step.action, component.id, status
            ))
            .into())
        }
    }

    fn execute_postflight(&self, action: Action) -> Result<(), Box<dyn Error>> {
        if action == Action::Uninstall {
            return Ok(());
        }

        let script = self.root.join("modules/lib/postflight.sh");
        let status = self
            .script_command(&script, &action.to_string())
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()?;
        if status.success() {
            Ok(())
        } else {
            Err(RuntimeError::new(format!("{} postflight failed with {status}", action)).into())
        }
    }

    fn command(&self, component: &Component, action: &str) -> Command {
        let module = self.root.join(&component.module);
        let mut command = self.base_script_command(&module);
        command.arg(action).env("OHMYDEVPOD_VERSION", &self.version);
        command
    }

    fn script_command(&self, script: &Path, action: &str) -> Command {
        let mut command = self.base_script_command(script);
        command.arg(action).env("OHMYDEVPOD_VERSION", &self.version);
        command
    }

    fn base_script_command(&self, script: &Path) -> Command {
        let mut command = Command::new("bash");
        command
            .arg(script)
            .env_remove("OHMYDEVPOD_BIN_DIR")
            .env_remove("OHMYDEVPOD_PREFIX")
            .env_remove("OHMYDEVPOD_CACHE_DIR")
            .env_remove("OHMYDEVPOD_CONFIG_DIR")
            .env_remove("OHMYDEVPOD_STATE_DIR")
            .env_remove("OHMYDEVPOD_MANAGED_DIR")
            .env_remove("OHMYDEVPOD_ASSET_ROOT")
            .env_remove("OHMYDEVPOD_NEOVIM_DIR")
            .env_remove("OHMYDEVPOD_BTOP_DIR")
            .env_remove("OHMYDEVPOD_NVM_CONFIG_DIR")
            .env_remove("OHMYDEVPOD_NVM_DATA_DIR")
            .env_remove("OHMYDEVPOD_NVM_STATE_DIR")
            .env_remove("OHMYDEVPOD_NVM_CACHE_DIR")
            .env_remove("OHMYDEVPOD_ZSH_DIR")
            .env_remove("OHMYDEVPOD_ZSHRC")
            .env_remove("OHMYDEVPOD_P10K_CONFIG")
            .env_remove("HOMEBREW_BREW_GIT_REMOTE")
            .env_remove("HOMEBREW_BOTTLE_DOMAIN")
            .env_remove("HOMEBREW_API_DOMAIN")
            .env_remove("UV_CONFIG_FILE")
            .env("OHMYDEVPOD_BUNDLE_ROOT", &self.root)
            .env("OHMYDEVPOD_BIN_DIR", &self.bin_dir)
            .env("OHMYDEVPOD_PREFIX", &self.prefix)
            .env("OHMYDEVPOD_CACHE_DIR", &self.cache_dir)
            .env("OHMYDEVPOD_CONFIG_DIR", &self.config_dir)
            .env("OHMYDEVPOD_STATE_DIR", &self.state_dir)
            .env(
                "OHMYDEVPOD_ASSET_ROOT",
                self.root.join("vendor").join("releases"),
            );
        match self.mirror_profile {
            MirrorProfile::Upstream => {
                command.env("OHMYDEVPOD_MIRROR_PROFILE", "upstream");
            }
            MirrorProfile::China => {
                command
                    .env("OHMYDEVPOD_MIRROR_PROFILE", "cn")
                    .env(
                        "HOMEBREW_BREW_GIT_REMOTE",
                        "https://mirrors.ustc.edu.cn/brew.git",
                    )
                    .env(
                        "HOMEBREW_BOTTLE_DOMAIN",
                        "https://mirrors.ustc.edu.cn/homebrew-bottles",
                    )
                    .env(
                        "HOMEBREW_API_DOMAIN",
                        "https://mirrors.ustc.edu.cn/homebrew-bottles/api",
                    )
                    .env("UV_CONFIG_FILE", self.config_dir.join("uv.toml"));
            }
        }
        command
    }
}

struct ExecutionLock {
    path: PathBuf,
}

impl ExecutionLock {
    fn acquire_at(state_dir: &Path) -> Result<Self, Box<dyn Error>> {
        fs::create_dir_all(state_dir)?;
        let path = state_dir.join("execution.lock");
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .map_err(|error| {
                RuntimeError::new(format!(
                    "another omd operation may be active ({}): {error}",
                    path.display()
                ))
            })?;
        writeln!(file, "pid={}", std::process::id())?;
        Ok(Self { path })
    }
}

impl Drop for ExecutionLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

#[derive(Debug)]
struct RuntimeError(String);

impl RuntimeError {
    fn new(message: impl Into<String>) -> Self {
        Self(message.into())
    }
}

impl Display for RuntimeError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.0)
    }
}

impl Error for RuntimeError {}

fn discover_root() -> Result<PathBuf, Box<dyn Error>> {
    if let Some(root) = env::var_os("OHMYDEVPOD_BUNDLE_ROOT") {
        return validate_root(PathBuf::from(root));
    }

    if let Ok(executable) = env::current_exe().and_then(|path| path.canonicalize()) {
        if let Some(bin_dir) = executable.parent() {
            if bin_dir.file_name().is_some_and(|name| name == "bin") {
                if let Some(root) = bin_dir.parent() {
                    if root.join("components.toml").is_file() {
                        return validate_root(root.to_path_buf());
                    }
                }
            }
        }
    }

    #[cfg(debug_assertions)]
    {
        let development_root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        validate_root(development_root)
    }

    #[cfg(not(debug_assertions))]
    Err(RuntimeError::new(
        "cannot locate the oh-my-devpod runtime bundle; reinstall with install/bootstrap.sh",
    )
    .into())
}

fn validate_root(root: PathBuf) -> Result<PathBuf, Box<dyn Error>> {
    let root = root.canonicalize()?;
    if !root.join("components.toml").is_file() {
        return Err(
            RuntimeError::new(format!("{} is not an oh-my-devpod bundle", root.display())).into(),
        );
    }
    Ok(root)
}

fn installed_prefix(root: &Path) -> Option<PathBuf> {
    let releases_dir = root.parent()?;
    if releases_dir.file_name()? != "releases" {
        return None;
    }
    releases_dir.parent().map(Path::to_path_buf)
}

fn configured_path(path: &Path) -> Option<PathBuf> {
    let value = fs::read_to_string(path).ok()?;
    let path = PathBuf::from(value.trim());
    path.is_absolute().then_some(path)
}

fn active_bin_dir() -> Option<PathBuf> {
    let current = env::current_exe().ok()?.canonicalize().ok()?;
    let argument = env::args_os().next().map(PathBuf::from);
    if let Some(path) = argument.filter(|path| path.components().count() > 1) {
        let candidate = if path.is_absolute() {
            path
        } else {
            env::current_dir().ok()?.join(path)
        };
        if candidate.canonicalize().ok().as_ref() == Some(&current) {
            return candidate.parent().map(Path::to_path_buf);
        }
    }

    env::var_os("PATH")
        .into_iter()
        .flat_map(|paths| env::split_paths(&paths).collect::<Vec<_>>())
        .map(|directory| directory.join("omd"))
        .find(|candidate| candidate.canonicalize().ok().as_ref() == Some(&current))
        .and_then(|candidate| candidate.parent().map(Path::to_path_buf))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn development_root_contains_manifest() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        assert!(root.join("components.toml").is_file());
    }

    #[test]
    fn saved_source_is_authoritative_for_mirror_profile() {
        let config_dir =
            env::temp_dir().join(format!("omd-source-profile-test-{}", std::process::id()));
        fs::create_dir_all(&config_dir).unwrap();

        fs::write(config_dir.join("source"), "github\n").unwrap();
        fs::write(config_dir.join("mirror-profile"), "cn\n").unwrap();
        assert_eq!(
            MirrorProfile::discover(&config_dir).unwrap(),
            MirrorProfile::Upstream
        );

        fs::write(config_dir.join("source"), "source=gitee\n").unwrap();
        fs::write(config_dir.join("mirror-profile"), "upstream\n").unwrap();
        assert_eq!(
            MirrorProfile::discover(&config_dir).unwrap(),
            MirrorProfile::China
        );

        fs::remove_dir_all(config_dir).unwrap();
    }

    #[test]
    fn install_postflight_runs_after_an_unrelated_component_step() {
        let root = env::temp_dir().join(format!("omd-postflight-test-{}", std::process::id()));
        let postflight = root.join("modules/lib/postflight.sh");
        let component_script = root.join("modules/example.sh");
        let marker = root.join("postflight-action");
        fs::create_dir_all(postflight.parent().unwrap()).unwrap();
        fs::write(&component_script, "#!/usr/bin/env bash\nexit 0\n").unwrap();
        fs::write(
            &postflight,
            format!(
                "#!/usr/bin/env bash\nprintf '%s\\n' \"$1\" > '{}'\n",
                marker.display()
            ),
        )
        .unwrap();

        let runner = Runner {
            root: root.clone(),
            version: "test".to_string(),
            mirror_profile: MirrorProfile::Upstream,
            config_dir: root.join("config"),
            prefix: root.join("prefix"),
            bin_dir: root.join("bin"),
            cache_dir: root.join("cache"),
            state_dir: root.join("state"),
        };
        let catalog = Catalog::parse(
            r#"
schema_version = 1

[[component]]
id = "example"
name = "Example"
description = "Example component"
category = "terminal"
module = "modules/example.sh"
requires = []
install_requires = []
uninstall = true
"#,
        )
        .unwrap();
        let plan = Plan {
            action: Action::Install,
            requested: vec!["example".to_string()],
            steps: vec![PlanStep {
                component_id: "example".to_string(),
                action: Action::Install,
            }],
            skipped: vec![],
        };

        runner.execute_plan_locked(&catalog, &plan).unwrap();

        assert_eq!(fs::read_to_string(&marker).unwrap(), "install\n");
        fs::remove_dir_all(root).unwrap();
    }
}
