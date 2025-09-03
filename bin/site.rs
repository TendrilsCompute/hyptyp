use anyhow::Result;

pub const HTML_ARGS: [&str; 4] = ["--features", "html", "--format", "html"];

#[derive(Default, Debug)]
pub struct Site {
  pub files: Vec<File>,
}

#[derive(Debug)]
pub struct File {
  pub slug: String,
  pub path: String,
  pub content: Vec<u8>,
}

impl Site {
  pub fn parse(src: &str) -> Result<Site> {
    let mut site = Site::default();
    let dom = tl::parse(src, tl::ParserOptions::default())?;

    for node in dom.query_selector("html[hyptyp-slug][hyptyp-path]").unwrap() {
      let tag = node.get(dom.parser()).unwrap().as_tag().unwrap();
      site.files.push(File {
        slug: get_attr(tag, "hyptyp-slug").unwrap(),
        path: get_attr(tag, "hyptyp-path").unwrap(),
        content: format!("<!doctype html>\n<html>{}</html>", tag.inner_html(dom.parser()))
          .into_bytes(),
      });
    }

    for node in dom.query_selector("pre[hyptyp-slug][hyptyp-path]").unwrap() {
      let tag = node.get(dom.parser()).unwrap().as_tag().unwrap();
      site.files.push(File {
        slug: get_attr(tag, "hyptyp-slug").unwrap(),
        path: get_attr(tag, "hyptyp-path").unwrap(),
        content: hex::decode(&*tag.inner_text(dom.parser()))?,
      });
    }

    Ok(site)
  }
}

fn get_attr(tag: &tl::HTMLTag, name: &str) -> Option<String> {
  Some(tag.attributes().get(name)??.try_as_utf8_str()?.into())
}
