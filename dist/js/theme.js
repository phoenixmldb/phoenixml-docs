(function () {
  "use strict";

  // --- Theme Toggle ---
  var themeToggle = document.getElementById("theme-toggle");
  var root = document.documentElement;

  // Apply saved preference on load (before paint to prevent flash)
  var saved = localStorage.getItem("crucible-theme");
  if (saved) {
    root.setAttribute("data-theme", saved);
  }
  updateToggleIcon();

  if (themeToggle) {
    themeToggle.addEventListener("click", function () {
      var current = root.getAttribute("data-theme");
      var isDark;

      if (current === "dark") {
        root.setAttribute("data-theme", "light");
        isDark = false;
      } else if (current === "light") {
        root.setAttribute("data-theme", "dark");
        isDark = true;
      } else {
        // No explicit theme — check system preference and toggle opposite
        isDark = !window.matchMedia("(prefers-color-scheme: dark)").matches;
        root.setAttribute("data-theme", isDark ? "dark" : "light");
      }

      localStorage.setItem("crucible-theme", isDark ? "dark" : "light");
      updateToggleIcon();
    });
  }

  function updateToggleIcon() {
    if (!themeToggle) return;
    var theme = root.getAttribute("data-theme");
    var isDark;
    if (theme === "dark") {
      isDark = true;
    } else if (theme === "light") {
      isDark = false;
    } else {
      isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    }
    // Moon for light mode (click to go dark), Sun for dark mode (click to go light)
    themeToggle.textContent = isDark ? "\u2600" : "\u263E";
    themeToggle.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode");
  }

  // --- Collapsible Nav Sections ---
  document.querySelectorAll(".nav-section-toggle").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var section = btn.parentElement;
      var isOpen = section.classList.toggle("open");
      btn.setAttribute("aria-expanded", String(isOpen));
    });
  });

  // --- Mobile Nav Toggle ---
  var navToggle = document.querySelector(".nav-toggle");
  var sidebar = document.querySelector(".sidebar");
  if (navToggle && sidebar) {
    navToggle.addEventListener("click", function () {
      sidebar.classList.toggle("open");
      var expanded = sidebar.classList.contains("open");
      navToggle.setAttribute("aria-expanded", String(expanded));
    });
  }
})();
