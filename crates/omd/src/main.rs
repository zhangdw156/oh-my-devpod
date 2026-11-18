use std::{
    collections::HashMap,
    env,
    error::Error,
    io::{self, Write},
    process::ExitCode,
};

mod components;
mod planner;
mod runtime;
mod tui;

use components::Catalog;
use planner::{assumed_states, plan, Action, ComponentState};
use runtime::{Runner, RuntimePaths};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum UpdateRequest {
    SavedSource,
    GitHub,
    Gitee,
}

impl UpdateRequest {
    fn source_flag(self) -> Option<&'static str> {
        match self {
            Self::SavedSource => None,
            Self::GitHub => Some("--github"),
            Self::Gitee => Some("--gitee"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SourceRequest {
    GitHub,
    Gitee,
}

impl SourceRequest {
    fn name(self) -> &'static str {
        match self {
            Self::GitHub => "github",
            Self::Gitee => "gitee",
        }
    }
}

fn main() -> ExitCode {
    match run(env::args().skip(1)) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("omd: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run<I>(args: I) -> Result<(), Box<dyn Error>>
where
    I: IntoIterator<Item = String>,
{
    let args: Vec<String> = args.into_iter().collect();
    reject_npm_self_update(
        &args,
        env::var("OHMYDEVPOD_INSTALL_CHANNEL").ok().as_deref(),
    )?;
    let paths = RuntimePaths::discover()?;
    let runner = Runner::new(&paths);

    if let Some(request) = parse_update_request(&args)? {
        return runner.self_update(request.source_flag());
    }
    if let Some(request) = parse_source_request(&args)? {
        return runner.switch_source(request.name());
    }

    let catalog = Catalog::load(&paths.manifest)?;
    match args.as_slice() {
        [] => {
            if let Some(preview) = tui::run(&catalog, &runner)? {
                runner.execute_confirmed_plan(&catalog, &preview)?;
            }
            Ok(())
        }
        [flag] if flag == "--version" || flag == "-V" => {
            finish_output(writeln!(io::stdout().lock(), "omd {}", paths.version))
        }
        [flag] if flag == "--list-components" => finish_output(print_components(&catalog)),
        [flag] if flag == "--status" => {
            let states = runner.inventory(&catalog)?;
            finish_output(print_status(&catalog, &states))
        }
        [flag] if flag == "--dry-run" => {
            let requested = catalog
                .components()
                .iter()
                .map(|component| component.id.clone())
                .collect::<Vec<_>>();
            let states = assumed_states(&catalog, Action::Install);
            let plan = plan(&catalog, Action::Install, &requested, &states)?;
            print_plan(&catalog, &plan)?;
            runner.dry_run_plan(&catalog, &plan)?;
            Ok(())
        }
        [flag, action, ids @ ..] if flag == "--plan" => {
            let action = action.parse::<Action>()?;
            let requested = ids.to_vec();
            let states = assumed_states(&catalog, action);
            let plan = plan(&catalog, action, &requested, &states)?;
            finish_output(print_plan(&catalog, &plan))
        }
        [flag, action, ids @ ..] if flag == "--plan-current" => {
            let action = action.parse::<Action>()?;
            let requested = ids.to_vec();
            let states = runner.inventory(&catalog)?;
            let plan = plan(&catalog, action, &requested, &states)?;
            finish_output(print_plan(&catalog, &plan))
        }
        [flag, action, ids @ ..] if flag == "--execute" => {
            let action = action.parse::<Action>()?;
            let requested = ids.to_vec();
            let states = runner.inventory(&catalog)?;
            let plan = plan(&catalog, action, &requested, &states)?;
            print_plan(&catalog, &plan)?;
            runner.execute_confirmed_plan(&catalog, &plan)
        }
        [flag] if flag == "--help" || flag == "-h" => {
            finish_output(io::stdout().lock().write_all(HELP.as_bytes()))
        }
        [unknown, ..] => Err(format!("unknown argument: {unknown}").into()),
    }
}

// A read-only pipeline is complete when its consumer has all the output it needs.
fn finish_output(result: io::Result<()>) -> Result<(), Box<dyn Error>> {
    match result {
        Err(error) if error.kind() == io::ErrorKind::BrokenPipe => Ok(()),
        result => result.map_err(Into::into),
    }
}

const HELP: &str = "omd - oh-my-devpod productivity tool manager

Usage:
  omd
  omd --list-components
  omd --status
  omd --plan <install|update|uninstall> <component>...
  omd --plan-current <install|update|uninstall> <component>...
  omd --execute <install|update|uninstall> <component>...
  omd --dry-run
  omd --update [--github|--gitee]
  omd --source <github|gitee>
  omd --version

Self-update:
  --update           update from the saved source (default: GitHub)
  --update --github  update from GitHub and switch managed sources upstream
  --update --gitee   update from Gitee and switch managed sources to China mirrors

Source switching:
  --source github    switch installed managed tools and future operations upstream
  --source gitee     switch installed managed tools and future operations to China mirrors
";

fn parse_update_request(args: &[String]) -> Result<Option<UpdateRequest>, Box<dyn Error>> {
    if args.first().map(String::as_str) != Some("--update") {
        return Ok(None);
    }

    let mut source_flag = None;
    for argument in &args[1..] {
        match argument.as_str() {
            "--github" if source_flag.is_none() => source_flag = Some(UpdateRequest::GitHub),
            "--gitee" if source_flag.is_none() => source_flag = Some(UpdateRequest::Gitee),
            "--github" | "--gitee" => {
                return Err("--github and --gitee are mutually exclusive".into());
            }
            unknown => return Err(format!("unknown self-update option: {unknown}").into()),
        }
    }
    Ok(Some(source_flag.unwrap_or(UpdateRequest::SavedSource)))
}

fn parse_source_request(args: &[String]) -> Result<Option<SourceRequest>, Box<dyn Error>> {
    if args.first().map(String::as_str) != Some("--source") {
        return Ok(None);
    }

    match args {
        [_, source] if source == "github" => Ok(Some(SourceRequest::GitHub)),
        [_, source] if source == "gitee" => Ok(Some(SourceRequest::Gitee)),
        [_] => Err("source name is required; expected github or gitee".into()),
        [_, source] => Err(format!("unknown source: {source}; expected github or gitee").into()),
        _ => Err("source switching accepts exactly one source: github or gitee".into()),
    }
}

fn reject_npm_self_update(
    args: &[String],
    install_channel: Option<&str>,
) -> Result<(), Box<dyn Error>> {
    if args.first().map(String::as_str) == Some("--update") && install_channel == Some("npm") {
        return Err(
            "self-update is unavailable for npm installations; run `npm update -g oh-my-devpod` instead"
                .into(),
        );
    }
    Ok(())
}

fn print_components(catalog: &Catalog) -> io::Result<()> {
    let mut out = io::stdout().lock();
    for component in catalog.components() {
        let requires = if component.requires.is_empty() {
            "-".to_string()
        } else {
            component.requires.join(",")
        };
        let install_requires = if component.install_requires.is_empty() {
            "-".to_string()
        } else {
            component.install_requires.join(",")
        };
        writeln!(
            out,
            "{}\t{}\trequires={}\tinstall_requires={}\tscope={}\t{}\t{}",
            component.id,
            component.category,
            requires,
            install_requires,
            component.scope(),
            if component.uninstall {
                "removable"
            } else {
                "protected"
            },
            component.module
        )?;
    }
    Ok(())
}

fn print_status(catalog: &Catalog, states: &HashMap<String, ComponentState>) -> io::Result<()> {
    let mut out = io::stdout().lock();
    for component in catalog.components() {
        writeln!(
            out,
            "{}\t{}\tscope={}",
            component.id,
            states
                .get(&component.id)
                .copied()
                .unwrap_or(ComponentState::Missing),
            component.scope()
        )?;
    }
    Ok(())
}

fn print_plan(catalog: &Catalog, plan: &planner::Plan) -> io::Result<()> {
    let mut out = io::stdout().lock();
    writeln!(out, "omd plan")?;
    for step in &plan.steps {
        let component = catalog
            .require(&step.component_id)
            .map_err(io::Error::other)?;
        writeln!(
            out,
            "{}\t{}\t{}\tscope={}",
            step.action,
            component.id,
            component.name,
            component.scope()
        )?;
    }
    for id in &plan.skipped {
        writeln!(out, "skip\t{id}")?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(values: &[&str]) -> Vec<String> {
        values.iter().map(|value| value.to_string()).collect()
    }

    #[test]
    fn parses_self_update_source_flags() {
        assert_eq!(
            parse_update_request(&args(&["--update"])).unwrap(),
            Some(UpdateRequest::SavedSource)
        );
        assert_eq!(
            parse_update_request(&args(&["--update", "--github"])).unwrap(),
            Some(UpdateRequest::GitHub)
        );
        assert_eq!(
            parse_update_request(&args(&["--update", "--gitee"])).unwrap(),
            Some(UpdateRequest::Gitee)
        );
        assert_eq!(parse_update_request(&args(&["--version"])).unwrap(), None);
    }

    #[test]
    fn rejects_multiple_self_update_source_flags() {
        let error = parse_update_request(&args(&["--update", "--github", "--gitee"])).unwrap_err();
        assert!(error.to_string().contains("mutually exclusive"));
    }

    #[test]
    fn parses_source_switch_requests() {
        assert_eq!(
            parse_source_request(&args(&["--source", "github"])).unwrap(),
            Some(SourceRequest::GitHub)
        );
        assert_eq!(
            parse_source_request(&args(&["--source", "gitee"])).unwrap(),
            Some(SourceRequest::Gitee)
        );
        assert_eq!(parse_source_request(&args(&["--version"])).unwrap(), None);
    }

    #[test]
    fn rejects_invalid_source_switch_requests() {
        for arguments in [
            args(&["--source"]),
            args(&["--source", "mirror"]),
            args(&["--source", "github", "extra"]),
        ] {
            let error = parse_source_request(&arguments).unwrap_err();
            assert!(error.to_string().contains("source"));
        }
    }

    #[test]
    fn rejects_all_npm_self_update_forms() {
        for arguments in [
            args(&["--update"]),
            args(&["--update", "--github"]),
            args(&["--update", "--gitee"]),
        ] {
            let error = reject_npm_self_update(&arguments, Some("npm")).unwrap_err();
            assert!(error.to_string().contains("npm update -g oh-my-devpod"));
        }
    }

    #[test]
    fn leaves_non_npm_commands_and_channels_unchanged() {
        reject_npm_self_update(&args(&["--version"]), Some("npm")).unwrap();
        reject_npm_self_update(&args(&["--update"]), None).unwrap();
        reject_npm_self_update(&args(&["--update"]), Some("bootstrap")).unwrap();
    }
}
