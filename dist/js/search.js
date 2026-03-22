(function () {
  "use strict";

  var searchInput = document.getElementById("search-input");
  var searchResults = document.getElementById("search-results");
  if (!searchInput || !searchResults) return;

  var index = null;
  var documents = null;
  var debounceTimer = null;

  // Load the search index on first focus
  searchInput.addEventListener("focus", loadIndex, { once: true });

  function loadIndex() {
    fetch("/search-index.json")
      .then(function (r) { return r.json(); })
      .then(function (data) {
        documents = {};
        data.forEach(function (doc) {
          documents[doc.path] = doc;
        });

        index = lunr(function () {
          this.ref("path");
          this.field("title", { boost: 10 });
          this.field("description", { boost: 5 });
          this.field("headings", { boost: 3 });
          this.field("body");

          data.forEach(function (doc) {
            this.add({
              path: doc.path,
              title: doc.title,
              description: doc.description || "",
              headings: doc.headings ? doc.headings.join(" ") : "",
              body: doc.body || ""
            });
          }, this);
        });
      })
      .catch(function () {
        // Search index not available — silently degrade
      });
  }

  searchInput.addEventListener("input", function () {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(performSearch, 150);
  });

  searchInput.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
      searchInput.value = "";
      hideResults();
    }
  });

  // Close results when clicking outside
  document.addEventListener("click", function (e) {
    if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
      hideResults();
    }
  });

  function performSearch() {
    var query = searchInput.value.trim();
    if (!query || !index) {
      hideResults();
      return;
    }

    var results = index.search(query + "~1"); // fuzzy matching
    if (results.length === 0) {
      results = index.search(query + "*"); // prefix matching
    }

    // Clear previous results using safe DOM methods
    while (searchResults.firstChild) {
      searchResults.removeChild(searchResults.firstChild);
    }

    if (results.length === 0) {
      var noResults = document.createElement("div");
      noResults.className = "search-no-results";
      noResults.textContent = "No results found";
      searchResults.appendChild(noResults);
      searchResults.hidden = false;
      return;
    }

    results.slice(0, 10).forEach(function (result) {
      var doc = documents[result.ref];
      if (!doc) return;

      var link = document.createElement("a");
      link.className = "search-result";
      link.href = "/" + doc.path + ".html";

      var titleDiv = document.createElement("div");
      titleDiv.className = "search-result-title";
      titleDiv.textContent = doc.title;
      link.appendChild(titleDiv);

      var descDiv = document.createElement("div");
      descDiv.className = "search-result-desc";
      descDiv.textContent = doc.description || truncate(doc.body, 120);
      link.appendChild(descDiv);

      searchResults.appendChild(link);
    });

    searchResults.hidden = false;
  }

  function hideResults() {
    searchResults.hidden = true;
    while (searchResults.firstChild) {
      searchResults.removeChild(searchResults.firstChild);
    }
  }

  function truncate(str, max) {
    if (!str) return "";
    if (str.length <= max) return str;
    return str.substring(0, max) + "...";
  }
})();
