(function () {
    function render() {
        if (typeof mermaid === 'undefined') return;
        var dark = document.documentElement.getAttribute('data-theme') === 'dark';
        mermaid.initialize({
            startOnLoad: false,
            theme: dark ? 'dark' : 'default'
        });
        var nodes = document.querySelectorAll('pre.mermaid');
        if (!nodes.length) return;
        if (typeof mermaid.run === 'function') {
            mermaid.run({ nodes: nodes });
        } else {
            mermaid.init(undefined, nodes);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', render);
    } else {
        render();
    }
})();