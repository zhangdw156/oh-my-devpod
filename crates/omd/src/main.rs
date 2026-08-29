use std::{env, error::Error, process::ExitCode};

mod components;
mod planner;
mod runtime;
mod tui;

use components::Catalog;
use planner::{assumed_states, plan, Action};
use runtime::{Runner, RuntimePaths};

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
    let paths = RuntimePaths::discover()?;
    let catalog = Catalog::load(&paths.manifest)?;
    let runner = Runner::new(&paths);

    match args.as_slice() {
        [] => {
            if let Some(preview) = tui::run(&catalog, &runner)? {
                runner.execute_confirmed_plan(&catalog, &preview)?;
            }
            Ok(())
        }
        [flag] if flag == "--version" || flag == "-V" => {
            println!("omd {}", paths.version);
            Ok(())
        }
        [flag] if flag == "--list-components" => {
            print_components(&catalog);
            Ok(())
        }
        [flag] if flag == "--status" => {
            print_status(&catalog, &runner)?;
            Ok(())
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
            print_plan(&catalog, &plan)
        }
        [flag, action, ids @ ..] if flag == "--plan-current" => {
            let action = action.parse::<Action>()?;
            let requested = ids.to_vec();
            let states = runner.inventory(&catalog)?;
            let plan = plan(&catalog, action, &requested, &states)?;
            print_plan(&catalog, &plan)
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
            print_help();
            Ok(())
        }
        [unknown, ..] => Err(format!("unknown argument: {unknown}").into()),
    }
}

fn print_help() {
    println!("omd - oh-my-devpod productivity tool manager");
    println!();
    println!("Usage:");
    println!("  omd");
    println!("  omd --list-components");
    println!("  omd --status");
    println!("  omd --plan <install|update|uninstall> <component>...");
    println!("  omd --plan-current <install|update|uninstall> <component>...");
    println!("  omd --execute <install|update|uninstall> <component>...");
    println!("  omd --dry-run");
    println!("  omd --version");
}

fn print_components(catalog: &Catalog) {
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
        println!(
            "{}\t{}\trequires={}\tinstall_requires={}\t{}\t{}",
            component.id,
            component.category,
            requires,
            install_requires,
            if component.uninstall {
                "removable"
            } else {
                "protected"
            },
            component.module
        );
    }
}

fn print_status(catalog: &Catalog, runner: &Runner) -> Result<(), Box<dyn Error>> {
    let states = runner.inventory(catalog)?;
    for component in catalog.components() {
        println!(
            "{}\t{}",
            component.id,
            states
                .get(&component.id)
                .copied()
                .unwrap_or(planner::ComponentState::Missing)
        );
    }
    Ok(())
}

fn print_plan(catalog: &Catalog, plan: &planner::Plan) -> Result<(), Box<dyn Error>> {
    println!("omd plan");
    for step in &plan.steps {
        let component = catalog.require(&step.component_id)?;
        println!("{}\t{}\t{}", step.action, component.id, component.name);
    }
    for id in &plan.skipped {
        println!("skip\t{id}");
    }
    Ok(())
}
