(function () {
  var overlay = document.getElementById("search-overlay");
  var trigger = document.getElementById("search-trigger");
  var input = document.getElementById("search-input");
  var results = document.getElementById("search-results");
  var backdrop = overlay && overlay.querySelector(".search-backdrop");
  if (!overlay || !trigger || !input || !results) return;

  var idx = null;
  var docs = null;
  var docsByPath = {};
  var loading = false;
  var active = -1;

  // Injected by page.xslt from the site's base-url. Without it, a page at
  // /guides/install.html would fetch /guides/search-index.json.
  var BASE = window.CRUCIBLE_BASE || "/";
  if (BASE.charAt(BASE.length - 1) !== "/") BASE += "/";

  // Mirrors c:page-url in _base/urls.xslt: URLs are extensionless and a
  // trailing "index" segment collapses to its directory, so a search result,
  // a nav link and the canonical tag all name the same URL for a page.
  //   index          -> <base>
  //   guides/install -> <base>guides/install
  //   guides/index   -> <base>guides/
  function pageUrl(path) {
    return BASE + path.replace(/(^|\/)index$/, "$1");
  }

  function ensureIndex() {
    if (idx || loading) return Promise.resolve();
    loading = true;
    return fetch(BASE + "search-index.json").then(function (r) {
      if (!r.ok) throw new Error("search-index.json missing");
      return r.json();
    }).then(function (data) {
      // search-index.json is a top-level array of
      // { path, title, description, headings[], body }.
      docs = Array.isArray(data) ? data : [];
      docs.forEach(function (d) { docsByPath[d.path] = d; });
      idx = lunr(function () {
        this.ref("path");
        this.field("title", { boost: 10 });
        this.field("description", { boost: 5 });
        this.field("headings", { boost: 3 });
        this.field("body");
        var self = this;
        docs.forEach(function (d) {
          self.add({
            path: d.path,
            title: d.title || "",
            description: d.description || "",
            headings: (d.headings || []).join(" "),
            body: d.body || ""
          });
        });
      });
    }).finally(function () { loading = false; });
  }

  function open() {
    overlay.hidden = false;
    ensureIndex().then(function () {
      input.value = "";
      render("");
      input.focus();
    });
  }

  function close() {
    overlay.hidden = true;
    active = -1;
  }

  function snippet(text, query) {
    if (!text) return "";
    var q = query.trim().split(/\s+/)[0];
    if (!q) return text.slice(0, 140);
    var at = text.toLowerCase().indexOf(q.toLowerCase());
    if (at < 0) return text.slice(0, 140);
    var start = Math.max(0, at - 30);
    return (start > 0 ? "… " : "") + text.slice(start, start + 140);
  }

  function clearChildren(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function makeMessage(cls, text) {
    var div = document.createElement("div");
    div.className = cls;
    div.textContent = text;
    return div;
  }

  function makeResult(doc, query, isActive) {
    var a = document.createElement("a");
    a.className = "search-result" + (isActive ? " active" : "");
    a.href = pageUrl(doc.path);

    var title = document.createElement("div");
    title.className = "search-result-title";
    title.textContent = doc.title || doc.path;

    var path = document.createElement("div");
    path.className = "search-result-path";
    path.textContent = doc.path;

    var snip = document.createElement("div");
    snip.className = "search-result-snippet";
    snip.textContent = snippet(doc.description || doc.body, query);

    a.appendChild(title);
    a.appendChild(path);
    a.appendChild(snip);
    return a;
  }

  function render(query) {
    clearChildren(results);
    active = -1;

    if (!query) {
      results.appendChild(makeMessage("search-empty", "Start typing to search…"));
      return;
    }

    var matches = idx ? idx.search(query + "*") : [];
    if (!matches.length) {
      results.appendChild(makeMessage("search-none", "No results"));
      return;
    }

    matches.slice(0, 20).forEach(function (m, i) {
      var doc = docsByPath[m.ref];
      if (!doc) return;
      results.appendChild(makeResult(doc, query, i === 0));
    });
    active = 0;
  }

  function move(delta) {
    var items = results.querySelectorAll(".search-result");
    if (!items.length) return;
    if (active >= 0) items[active].classList.remove("active");
    active = (active + delta + items.length) % items.length;
    items[active].classList.add("active");
    items[active].scrollIntoView({ block: "nearest" });
  }

  function activate() {
    var items = results.querySelectorAll(".search-result");
    if (active >= 0 && items[active]) items[active].click();
  }

  trigger.addEventListener("click", open);
  if (backdrop) backdrop.addEventListener("click", close);

  input.addEventListener("input", function () { render(input.value); });
  input.addEventListener("keydown", function (e) {
    if (e.key === "ArrowDown") { e.preventDefault(); move(1); }
    else if (e.key === "ArrowUp") { e.preventDefault(); move(-1); }
    else if (e.key === "Enter") { e.preventDefault(); activate(); }
    else if (e.key === "Escape") { e.preventDefault(); close(); }
  });

  document.addEventListener("keydown", function (e) {
    var isK = (e.key === "k" || e.key === "K") && (e.metaKey || e.ctrlKey);
    var active = document.activeElement;
    var isSlash = e.key === "/" && !e.metaKey && !e.ctrlKey &&
                  active && active.tagName !== "INPUT" && active.tagName !== "TEXTAREA";
    if (isK || isSlash) { e.preventDefault(); open(); }
    else if (e.key === "Escape" && !overlay.hidden) { close(); }
  });
})();
