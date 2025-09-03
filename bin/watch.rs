use std::{
  convert::Infallible,
  fs,
  io::Write as _,
  path::PathBuf,
  process::{Command, ExitCode},
  sync::{Arc, RwLock},
};

use anyhow::Result;
use tempfile::NamedTempFile;

use futures::stream::StreamExt as _;
use notify::Watcher as _;
use warp::Filter as _;

use crate::{
  TypstArgs,
  site::{HTML_ARGS, Site},
};

pub fn watch(input: PathBuf, port: u16, typst: TypstArgs) -> Result<ExitCode> {
  let typst_out = NamedTempFile::new()?;

  Command::new(typst.typst_bin)
    .arg("watch")
    .arg(input)
    .arg(typst_out.path())
    .args(HTML_ARGS)
    .arg("--no-serve")
    .args(["--input", "hyptyp-dev=1"])
    .args(typst.typst_args)
    .spawn()?;

  let (send_reload, recv_reload) = tokio::sync::watch::channel(());
  let server = Arc::new(Server { typst_out, recv_reload, site: Default::default() });

  let watcher = Watcher { server: server.clone(), send_reload };
  watcher.reload()?;
  let mut watcher = notify::recommended_watcher(watcher)?;
  watcher.watch(server.typst_out.path(), notify::RecursiveMode::NonRecursive)?;

  let handler = warp::get().and(warp::path::full()).map({
    let server = server.clone();
    move |path: warp::path::FullPath| {
      let path = path.as_str();
      let site = server.site.read().unwrap();
      for file in &site.files {
        if file.slug == path {
          let mime = mime_guess::from_path(&file.path).first_or_octet_stream();
          return http::Response::builder()
            .header("Content-Type", mime.as_ref())
            .body(file.content.clone());
        }
      }
      http::Response::builder()
        .status(http::StatusCode::NOT_FOUND)
        .body("404".to_owned().into_bytes())
    }
  });

  let sse = warp::path("hyptyp-sse").and(warp::path::end()).and(warp::get()).map({
    let server = server.clone();
    move || {
      let mut recv = server.recv_reload.clone();
      recv.mark_unchanged();
      warp::sse::reply(
        warp::sse::keep_alive().stream(
          tokio_stream::wrappers::WatchStream::from_changes(recv)
            .map(|_| Result::<_, Infallible>::Ok(warp::sse::Event::default().data("reload"))),
        ),
      )
    }
  });

  let runtime = tokio::runtime::Builder::new_multi_thread().enable_all().build().unwrap();

  runtime.spawn(async move {
    let mut recv = server.recv_reload.clone();
    loop {
      _ = recv.changed().await;
      tokio::time::sleep(std::time::Duration::from_millis(200)).await;
      eprint!("\x1b[s\x1b[2H\x1b[K\x1b[92;1mserving on\x1b[m http://localhost:{port}/\x1b[u");
      std::io::stderr().flush().unwrap();
    }
  });

  runtime.block_on(warp::serve(sse.or(handler)).run(([0, 0, 0, 0], port)));

  Ok(ExitCode::SUCCESS)
}

struct Server {
  typst_out: NamedTempFile,
  recv_reload: tokio::sync::watch::Receiver<()>,
  site: RwLock<Site>,
}

struct Watcher {
  server: Arc<Server>,
  send_reload: tokio::sync::watch::Sender<()>,
}

impl notify::EventHandler for Watcher {
  fn handle_event(&mut self, event: notify::Result<notify::Event>) {
    use notify::{EventKind, event::ModifyKind};
    if let EventKind::Any | EventKind::Modify(ModifyKind::Any | ModifyKind::Data(_)) =
      event.unwrap().kind
    {
      self.reload().unwrap()
    }
  }
}

impl Watcher {
  fn reload(&self) -> Result<()> {
    let site = Site::parse(&fs::read_to_string(&self.server.typst_out)?)?;
    *self.server.site.write().unwrap() = site;
    self.send_reload.send(())?;
    Ok(())
  }
}
