use std::{ffi::OsString, path::PathBuf, process::ExitCode};

use anyhow::Result;

use clap::Parser as _;

mod compile;
mod site;
mod watch;

#[derive(clap::Parser)]
enum Hyptyp {
  Compile {
    input: PathBuf,

    #[arg(default_value = "site")]
    output: PathBuf,

    #[command(flatten)]
    typst: TypstArgs,
  },

  Watch {
    input: PathBuf,

    #[arg(long, default_value = "3046")]
    port: u16,

    #[command(flatten)]
    typst: TypstArgs,
  },
}

#[derive(clap::Args)]
struct TypstArgs {
  #[arg(long, default_value = "typst")]
  typst_bin: OsString,
  #[arg(last = true, action = clap::ArgAction::Append)]
  typst_args: Vec<OsString>,
}

fn main() -> Result<ExitCode> {
  match Hyptyp::parse() {
    Hyptyp::Compile { input, output, typst } => compile::compile(input, output, typst),
    Hyptyp::Watch { input, port, typst } => watch::watch(input, port, typst),
  }
}
