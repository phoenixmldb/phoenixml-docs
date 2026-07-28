<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
  <xsl:output method="html" html-version="5" indent="yes" encoding="UTF-8"/>

  <xsl:param name="site-manifest-uri" select="''"/>
  <xsl:param name="base-url" select="'/'"/>
  <xsl:param name="site-title" select="'Documentation'"/>
  <xsl:param name="current-path" select="''"/>

  <xsl:variable name="manifest" select="if ($site-manifest-uri != '') then doc($site-manifest-uri) else ()"/>

  <xsl:template match="document">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title><xsl:value-of select="@title"/> — <xsl:value-of select="$site-title"/></title>
        <xsl:if test="@description">
          <meta name="description" content="{@description}"/>
        </xsl:if>
        <link rel="canonical" href="{$base-url}{@path}.html"/>
        <meta property="og:title" content="{@title}"/>
        <meta property="og:type" content="article"/>
        <meta property="og:url" content="{$base-url}{@path}.html"/>
        <xsl:if test="@description">
          <meta property="og:description" content="{@description}"/>
        </xsl:if>
        <link rel="stylesheet" href="{$base-url}css/style.css"/>
        <link rel="stylesheet" href="{$base-url}css/prism.css"/>
        <script>
          (function(){var t=localStorage.getItem("crucible-theme");if(t)document.documentElement.setAttribute("data-theme",t)})();
        </script>
        <!-- TODO: replace with config-driven analytics block (see follow-up issue) -->
        <script async="async" src="https://www.googletagmanager.com/gtag/js?id=G-FSCPKZ7RES"/>
        <script>
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', 'G-FSCPKZ7RES');
        </script>
      </head>
      <body>
        <header class="site-header">
          <a href="{$base-url}index.html" class="site-logo"><xsl:value-of select="$site-title"/></a>
          <div class="header-actions">
            <button class="search-trigger" id="search-trigger" aria-label="Search documentation">
              <span class="search-icon">🔍</span>
              <span class="search-label">Search…</span>
              <kbd class="search-kbd">⌘ K</kbd>
            </button>
            <button class="theme-toggle" id="theme-toggle" aria-label="Toggle dark mode" title="Toggle dark mode">☾</button>
            <button class="nav-toggle" aria-label="Toggle navigation">☰</button>
          </div>
        </header>

        <div class="layout">
          <nav class="sidebar" aria-label="Documentation">
            <xsl:if test="$manifest">
              <xsl:apply-templates select="$manifest/site" mode="nav"/>
            </xsl:if>
          </nav>

          <main>
            <article>
              <xsl:variable name="parent-section"
                select="if ($manifest) then ($manifest//page[@path = current()/@path]/parent::section/@title) else ()"/>
              <xsl:if test="$parent-section">
                <p class="eyebrow"><xsl:value-of select="$parent-section"/></p>
              </xsl:if>
              <h1 class="page-title"><xsl:value-of select="@title"/></h1>
              <xsl:if test="@description">
                <p class="page-subtitle"><xsl:value-of select="@description"/></p>
              </xsl:if>
              <xsl:apply-templates select="body/*"/>
            </article>
          </main>

          <xsl:if test="not(@toc = 'false')">
            <aside class="toc" aria-label="On this page">
              <p class="toc-label">On this page</p>
              <ul>
                <xsl:for-each select="body//heading[@level = ('2','3')]">
                  <li class="toc-h{@level}">
                    <a href="#{@id}"><xsl:value-of select="."/></a>
                  </li>
                </xsl:for-each>
              </ul>
            </aside>
          </xsl:if>
        </div>

        <div class="search-overlay" id="search-overlay" hidden="hidden">
          <div class="search-backdrop"></div>
          <div class="search-panel" role="dialog" aria-label="Search">
            <input type="search" id="search-input" placeholder="Search documentation…" aria-label="Search documentation" autocomplete="off"/>
            <div class="search-results" id="search-results"></div>
          </div>
        </div>

        <footer class="site-footer">
          <p>Built with <a href="https://github.com/phoenixmldb/crucible" target="_blank" rel="noopener noreferrer">Crucible</a> by <a href="https://endpointsystems.com" target="_blank" rel="noopener noreferrer">Endpoint Systems</a></p>
        </footer>

        <script src="https://unpkg.com/lunr/lunr.js"></script>
        <script src="{$base-url}js/prism.js"></script>
        <script src="{$base-url}js/search.js"></script>
        <script src="{$base-url}js/theme.js"></script>
        <script src="{$base-url}js/toc.js"></script>
        <script src="{$base-url}js/copy.js"></script>
      </body>
    </html>
  </xsl:template>

  <!-- Navigation templates -->
  <xsl:template match="site" mode="nav">
    <ul class="nav-tree">
      <xsl:apply-templates select="page|section" mode="nav"/>
    </ul>
  </xsl:template>

  <xsl:template match="section" mode="nav">
    <xsl:variable name="has-active" select="exists(.//page[@path = $current-path])"/>
    <li class="nav-section{if ($has-active) then ' open' else ''}">
      <p class="nav-section-title"><xsl:value-of select="@title"/></p>
      <ul class="nav-section-children">
        <xsl:apply-templates select="page|section" mode="nav"/>
      </ul>
    </li>
  </xsl:template>

  <xsl:template match="page" mode="nav">
    <li>
      <xsl:if test="@path = $current-path">
        <xsl:attribute name="class">active</xsl:attribute>
      </xsl:if>
      <a href="{$base-url}{@path}.html"><xsl:value-of select="@title"/></a>
    </li>
  </xsl:template>

  <!-- Body element templates -->
  <xsl:template match="heading">
    <xsl:element name="h{@level}">
      <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
      <a class="anchor" href="#{@id}">#</a>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="paragraph">
    <p><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="code-block">
    <figure class="code">
      <xsl:if test="@filename or @language">
        <figcaption>
          <xsl:if test="@filename">
            <span class="filename"><xsl:value-of select="@filename"/></span>
          </xsl:if>
          <xsl:if test="@language">
            <span class="lang"><xsl:value-of select="@language"/></span>
          </xsl:if>
        </figcaption>
      </xsl:if>
      <pre><code>
        <xsl:if test="@language">
          <xsl:attribute name="class">language-<xsl:value-of select="@language"/></xsl:attribute>
        </xsl:if>
        <xsl:value-of select="."/>
      </code></pre>
      <button class="copy" type="button" aria-label="Copy code">Copy</button>
    </figure>
  </xsl:template>

  <xsl:template match="code">
    <code><xsl:value-of select="."/></code>
  </xsl:template>

  <xsl:template match="list[@type='unordered']">
    <ul><xsl:apply-templates select="item"/></ul>
  </xsl:template>

  <xsl:template match="list[@type='ordered']">
    <ol><xsl:apply-templates select="item"/></ol>
  </xsl:template>

  <xsl:template match="item">
    <li><xsl:apply-templates/></li>
  </xsl:template>

  <xsl:template match="link">
    <a href="{@href}">
      <xsl:if test="@title"><xsl:attribute name="title"><xsl:value-of select="@title"/></xsl:attribute></xsl:if>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <xsl:template match="image">
    <img src="{@src}" alt="{@alt}">
      <xsl:if test="@title"><xsl:attribute name="title"><xsl:value-of select="@title"/></xsl:attribute></xsl:if>
    </img>
  </xsl:template>

  <xsl:template match="emphasis">
    <em><xsl:apply-templates/></em>
  </xsl:template>

  <xsl:template match="strong">
    <strong><xsl:apply-templates/></strong>
  </xsl:template>

  <xsl:template match="blockquote">
    <blockquote><xsl:apply-templates/></blockquote>
  </xsl:template>

  <xsl:template match="table">
    <div class="table-wrap"><table><xsl:apply-templates/></table></div>
  </xsl:template>

  <xsl:template match="table-head">
    <thead><xsl:apply-templates/></thead>
  </xsl:template>

  <xsl:template match="table-body">
    <tbody><xsl:apply-templates/></tbody>
  </xsl:template>

  <xsl:template match="row">
    <tr><xsl:apply-templates/></tr>
  </xsl:template>

  <xsl:template match="cell[@header='true']">
    <th><xsl:apply-templates/></th>
  </xsl:template>

  <xsl:template match="cell">
    <td><xsl:apply-templates/></td>
  </xsl:template>

  <xsl:template match="thematic-break">
    <hr/>
  </xsl:template>

  <xsl:template match="admonition">
    <div class="admonition admonition-{@type}">
      <p class="admonition-title">
        <xsl:value-of select="upper-case(substring(@type, 1, 1))"/>
        <xsl:value-of select="substring(@type, 2)"/>
      </p>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="mermaid">
    <div class="mermaid-wrapper">
      <pre class="mermaid"><xsl:value-of select="."/></pre>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
  </xsl:template>

</xsl:stylesheet>
