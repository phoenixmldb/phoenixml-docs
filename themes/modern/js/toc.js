(function () {
  var toc = document.querySelector(".toc");
  if (!toc) return;

  var links = toc.querySelectorAll("a[href^='#']");
  if (!links.length) return;

  var byId = {};
  links.forEach(function (a) {
    var id = a.getAttribute("href").slice(1);
    byId[id] = a;
  });

  var headings = document.querySelectorAll("article h2[id], article h3[id]");
  if (!headings.length) return;

  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (!e.isIntersecting) return;
      var a = byId[e.target.id];
      if (!a) return;
      links.forEach(function (l) { l.classList.remove("active"); });
      a.classList.add("active");
    });
  }, { rootMargin: "-10% 0px -70% 0px", threshold: 0 });

  headings.forEach(function (h) { observer.observe(h); });
})();
