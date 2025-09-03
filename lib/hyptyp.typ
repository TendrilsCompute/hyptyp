
#let site = state("hyptyp:site", none)
#let slug = state("hyptyp:slug", none)
#let path = state("hyptyp:path", none)
#let site_ = site
#let slug_ = slug
#let path_ = path

#let footnotes = state("hyptyp:footnotes", ())

#let hex = "0123456789abcdef".codepoints()

#let path-parent = (path) => path.replace(regex("[^/]+/?$"), "")
#let path-basename = (path) => path.replace(regex("^.*/"), "")
#let path-join = (a, b) => (a + "/" + b).replace(regex("//+"), "/")

#import "tags.typ" as t

#let defaults = (
  root: none,

  root-slug: "/",

  path-to-slug: site => (path) => {
    let path = path.replace(regex("\\.typ$"), "").replace("_", "-")
    let name = path-basename(path)
    if path.ends-with("/" + name + "/" + name) {
      path-parent(path)
    } else {
      path
    }
  },

  slug-to-html-path: site => (slug) => {
    if slug.ends-with("/") {
      slug + "index.html"
    } else {
      slug + ".html"
    }
  },

  content-text: site => (content) => {
    if content == none {
      ""
    } else if content.has("body") {
      context-text(content.body)
    } else if content.has("children") {
      content.children.map(site.content-text).join()
    } else if content.has("text") {
      content.text
    } else {
      ""
    }
  },

  extract-title: site => (content) => {
    if content.func() == [].func() {
      for child in content.children {
        let title = (site.extract-title)(child)
        if title != none {
          return title
        }
      }
    } else if content.func() == heading and content.depth == 1 {
      content.body
    }
  },

  build-tree: site => (cwd, path, root: false) => {
    let path = path-join(cwd, path)
    import path as module
    let module = dictionary(module)
    let slug = module.at("slug", default: if root { site.root-slug } else { (site.path-to-slug)(path) })
    let content = {
      slug_.update(slug)
      path_.update(path)
      include path
      slug_.update(none)
      path_.update(none)
    }
    let children = module.at("children", default: ())
    let cwd = path-parent(path);
    (
      slug: slug,
      title: (site.extract-title)(content),
      content: content,
      children: children.map(child => (site.build-tree)(cwd, child))
    )
  },

  sidebar-header: site => node => [],

  sidebar-tree: site => (tree, current) => [
    #t.a(
      ..if tree.slug == current { (class: "current") } else { (:) },
      href: tree.slug,
    )[#tree.title]
    #enum(
      ..tree.children.map(child => (site.sidebar-tree)(child, current))
    )
  ],

  sidebar-footer: site => node => [],

  sidebar-toggle: site => () => [
    #t.input(id: "sidebar-toggle", type: "checkbox", style: "display:none")
    #t.label(id: "sidebar-toggle-label", ..("for": "sidebar-toggle"))
  ],

  head: site => node => [
    #t.meta(charset: "utf-8")
    #(site.head-title)(node)
    #t.meta(name: "viewport", content: "width=device-width, initial-scale=1")
    #t.meta(name: "darkreader-lock")
    #t.link(rel: "stylesheet", href: "/hyptyp.css")
    #if "hyptyp-dev" in sys.inputs {
      t.script("new EventSource('/hyptyp-sse').onmessage = () => location = location")
    }
    #(site.head-fonts)()
    #(site.head-extra)(node)
  ],

  head-title: site => node => [
    #t.title[#(site.content-text)(node.title)]
  ],

  head-fonts: site => () => [
    #t.link(rel: "preconnect", href: "https://fonts.googleapis.com")
    #t.link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: "")
    #t.link(rel: "stylesheet", href: "https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:ital,wght@0,200..800;1,200..800&family=Atkinson+Hyperlegible+Next:ital,wght@0,200..800;1,200..800&display=swap", crossorigin: "https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:ital,wght@0,200..800;1,200..800&family=Atkinson+Hyperlegible+Next:ital,wght@0,200..800;1,200..800&display=swap")
  ],

  head-extra: site => node => [],

  body: site => node => [
    #t.nav(id: "sidebar")[
      #(site.sidebar-header)(node)
      #(site.sidebar-tree)(site.tree, node.slug)
      #(site.sidebar-footer)(node)
    ]
    #(site.sidebar-toggle)()
    #t.main[
      #show: site.show-page
      #show ref: site.show-ref
      #show heading: site.show-heading
      #show footnote: site.show-footnote
      #footnotes.update(())
      #node.content
      #(site.footnotes)()
    ]
    #t.nav(id: "prev-next", {
      let prev = (site.prev-page)(node.slug)
      let next = (site.next-page)(node.slug)
      if prev != none {
        t.a(class: "prev", href: prev.slug)[#prev.title]
      }
      if next != none {
        t.a(class: "next", href: next.slug)[#next.title]
      }
    })
  ],

  show-page: site => content => content,

  show-doc: site => content => content,

  render-page: site => (tree, node) => {
    t.html(hyptyp-slug: node.slug, hyptyp-path: (site.slug-to-html-path)(node.slug))[
      #t.head[#(site.head)(node)]
      #t.body[#(site.body)(node)]
    ]
  },

  flatten-tree: site => (tree, parent: none) => {
    ((..tree, parent: parent),)
    for child in tree.children {
      (site.flatten-tree)(child, parent: tree.slug)
    }
  },

  show-ref: site => it => {
    if it.element == none {
      it
    } else {
      link(
        slug.at(it.element.location())
        + if it.element.func() == heading and it.element.level == 1 {
          ""
        } else {
          "#" + str(it.target)
        }
      )[#it.supplement]
    }
  },

  show-heading: site => it => {
    html.elem(
      "h" + str(it.level),
      attrs: if it.has("label") and it.level != 1 {
        (id: str(it.label))
      } else {
        (:)
      }
    )[#it.body]
  },

  show-footnote: site => it => {
    let id = footnotes.get().len() + 1
    footnotes.update((..footnotes.get(), it.body))
    t.sup(
      id: "footnote-" + str(id) + "-ref",
      class: "footnote",
      t.a(href: "#footnote-" + str(id), str(id)),
    )
  },

  footnotes: site => () => context {
    let footnotes = footnotes.get()
    if footnotes.len() != 0 {
      t.div(class: "footnotes", {
        for (i, footnote) in footnotes.enumerate() {
          let id = i + 1
          t.div({
            t.sup(id: "footnote-" + str(id), class: "footnote", str(id))
            [ ]
            footnote
            [ ]
            t.a(class: "footnote-back", href: "#footnote-" + str(id) + "-ref")[↩]
          })
        }
      })
    }
  },

  page-index: site => slug => {
    (site.flatten-tree)(site.tree).position(x => x.slug == slug)
  },

  prev-page: site => slug => {
    let index = (site.page-index)(slug)
    if index == 0 {
      none
    } else {
      (site.flatten-tree)(site.tree).at(index - 1, default: none)
    }
  },

  next-page: site => slug => {
    (site.flatten-tree)(site.tree).at((site.page-index)(slug) + 1, default: none)
  },
)

#let resource = (path, content, slug: auto) => {
  if slug == auto { slug = path }
  [#metadata((path: path, slug: slug, content: content)) <hyptyp-resource>]
}

#let build-site(dict) = {
  dict.pairs().map(((key, val)) =>
    ((key): if type(val) == function { (..args) => val(build-site(dict))(..args) } else { val })
  ).join()
}

#let show-site = (..args) => _ => context {
  let args = args.named()
  let args = (:..defaults, ..args)

  let site = build-site(args)

  if site.root == none {
    panic("root must be specified")
  }

  let tree = (site.build-tree)("/", site.root, root: true)
  let site = build-site((..args, tree: tree))

  site_.update(site)

  resource("/hyptyp.css", read("./hyptyp.css"))

  if target() == "html" {
    t.html[
      #for node in (site.flatten-tree)(tree) {
        (site.render-page)(tree, node)
      }
      #context for node in query(<hyptyp-resource>) {
        let resource = node.value
        t.pre(hyptyp-path: resource.path, hyptyp-slug: resource.slug)[
          #for byte in bytes(resource.content) {
            hex.at(calc.div-euclid(byte, 16))
            hex.at(calc.rem-euclid(byte, 16))
          }
        ]
      }
    ]
  } else {
    set page(numbering: "1")
    show: site.show-doc

    for node in (site.flatten-tree)(tree) {
      node.content
    }
  }
}

