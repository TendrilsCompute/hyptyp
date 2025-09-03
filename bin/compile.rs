use std::{
  fs,
  path::PathBuf,
  process::{Command, ExitCode},
};

use anyhow::Result;

use crate::{
  TypstArgs,
  site::{HTML_ARGS, Site},
};

pub fn compile(input: PathBuf, output: PathBuf, typst: TypstArgs) -> Result<ExitCode> {
  _ = fs::remove_dir_all(&output);

  let status = Command::new(typst.typst_bin)
    .arg("compile")
    .arg(input)
    .arg(&output)
    .args(HTML_ARGS)
    .args(typst.typst_args)
    .status()?;
  if !status.success() {
    anyhow::bail!("typst compilation failed");
  }

  let site = Site::parse(&fs::read_to_string(&output)?)?;

  fs::remove_file(&output)?;
  fs::create_dir(&output)?;

  for file in &site.files {
    let path = output.join(&file.path[1..]);
    fs::create_dir_all(path.parent().unwrap())?;
    fs::write(&path, &file.content)?;
  }

  Ok(ExitCode::SUCCESS)
}
