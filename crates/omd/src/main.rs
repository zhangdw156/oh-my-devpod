use std::{env, error::Error, process::ExitCode};

mod components;
mod tui;

use components::catalog;

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
    match args.as_slice() {
        [] => tui::run().map_err(Into::into),
        [flag] if flag == "--version" || flag == "-V" => {
            println!("omd {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
        [flag] if flag == "--dry-run" => {
            print_dry_run();
            Ok(())
        }
        [flag] if flag == "--list-components" => {
            print_components();
            Ok(())
        }
        [flag] if flag == "--help" || flag == "-h" => {
            print_help();
            Ok(())
        }
        [unknown, ..] => Err(format!("unknown argument: {unknown}").into()),
    }
}

fn print_help() {
    println!("omd - oh-my-devpod host installer");
    println!();
    println!("Usage: omd [--version|--dry-run|--list-components]");
}

fn print_dry_run() {
    let components = catalog();
    let required = components
        .iter()
        .filter(|component| component.required)
        .map(|component| component.id)
        .collect::<Vec<_>>()
        .join(",");
    let optional = components
        .iter()
        .filter(|component| !component.required)
        .map(|component| component.id)
        .collect::<Vec<_>>()
        .join(",");

    println!("omd dry run");
    println!("required: {required}");
    println!("optional: {optional}");
}

fn print_components() {
    for component in catalog() {
        let kind = if component.required {
            "required"
        } else {
            "optional"
        };
        println!("{}\t{}\t{}", component.id, kind, component.module);
    }
}
