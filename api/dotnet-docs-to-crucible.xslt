<?xml version="1.0" encoding="UTF-8"?>
<!--
  Transforms .NET XML documentation into Crucible's intermediate XML format.

  Usage:
    xslt dotnet-docs-to-crucible.xslt PhoenixmlDb.Core.xml \
      -p assembly-name=PhoenixmlDb.Core \
      -p base-path=api/core \
      -\-output-dir ./intermediate/api/core

  This XSLT demonstrates real-world XML transformation: taking one XML format
  (.NET documentation) and producing another (Crucible document schema) for
  rendering into HTML.

  Doc-comment content is MIXED content: prose interleaved with <see>, <c>,
  <para>, <code>, <list> and friends. It must therefore be processed with
  xsl:apply-templates, never xsl:value-of — taking the string-value of
  <remarks> silently discards every empty element inside it, which drops all
  <see cref="..."/> cross-references and collapses <para> structure. Two modes
  do the work:

    mode="doc-block"   block-level constructs (para, code, list, example)
    mode="doc-inline"  inline constructs (c, b, i, em, see, paramref)

  and the doc-blocks template splits mixed content into runs of each.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:my="http://phoenixml.net/crucible/api-docs"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="my xs"
                version="3.0">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <!-- Parameters set by the build script -->
  <xsl:param name="assembly-name" select="''"/>
  <xsl:param name="base-path" select="'api'"/>
  <!-- Comma-separated list of namespace prefixes to exclude (e.g., "PhoenixmlDb.Core.Storage,PhoenixmlDb.Xslt.Ast") -->
  <xsl:param name="exclude-namespaces" select="''"/>
  <xsl:variable name="excluded" select="tokenize($exclude-namespaces, ',')"/>

  <!--
    Strategy: Generate one output document per type (class, interface, struct, enum).
    Group all members (methods, properties, fields) under their parent type.
    Use xsl:result-document to write each type as a separate XML file.
  -->

  <!-- ============================================================ -->
  <!-- Global views over the member set                             -->
  <!-- Needed by cref resolution, which runs deep inside prose and  -->
  <!-- so cannot receive them as parameters.                        -->
  <!-- ============================================================ -->
  <xsl:variable name="all-members" select="/doc/members/member"/>
  <xsl:variable name="all-types" select="$all-members[starts-with(@name, 'T:')]"/>
  <xsl:variable name="types" select="$all-types[
    not(some $ex in $excluded satisfies
      starts-with(my:namespace-of(my:member-name(@name)), $ex)
    )
  ]"/>
  <!-- Fully-qualified names of the types that get their own page in THIS run.
       A cref is only turned into a link when its declaring type is in here. -->
  <xsl:variable name="type-name-set" as="xs:string*"
                select="for $t in $types return my:member-name($t/@name)"/>
  <!-- Member ids that render as an anchored <heading>, so a cref can deep-link. -->
  <xsl:variable name="anchored-members" as="xs:string*"
                select="$all-members[starts-with(@name, 'M:')]/string(@name)"/>

  <!-- Extract just the type name from a full qualified name -->
  <xsl:function name="my:local-name-of" as="xs:string"
>
    <xsl:param name="qualified" as="xs:string"/>
    <xsl:sequence select="tokenize($qualified, '\.')[last()]"/>
  </xsl:function>

  <!-- Extract namespace from a full qualified name -->
  <xsl:function name="my:namespace-of" as="xs:string"
>
    <xsl:param name="qualified" as="xs:string"/>
    <xsl:variable name="parts" select="tokenize($qualified, '\.')"/>
    <xsl:sequence select="string-join($parts[position() lt count($parts)], '.')"/>
  </xsl:function>

  <!-- Extract the type prefix (T:, M:, P:, F:, E:) -->
  <xsl:function name="my:member-prefix" as="xs:string"
>
    <xsl:param name="name" as="xs:string"/>
    <xsl:sequence select="substring($name, 1, 2)"/>
  </xsl:function>

  <!-- Extract the full name without prefix -->
  <xsl:function name="my:member-name" as="xs:string"
>
    <xsl:param name="name" as="xs:string"/>
    <xsl:sequence select="substring($name, 3)"/>
  </xsl:function>

  <!-- Get the parent type name from a member name (M:Ns.Type.Method => Ns.Type) -->
  <xsl:function name="my:parent-type" as="xs:string"
>
    <xsl:param name="name" as="xs:string"/>
    <xsl:variable name="full" select="my:member-name($name)"/>
    <!-- Remove method params first: everything after ( -->
    <xsl:variable name="without-params" select="
      if (contains($full, '(')) then substring-before($full, '(')
      else $full
    "/>
    <!-- Now get everything before the last dot -->
    <xsl:variable name="parts" select="tokenize($without-params, '\.')"/>
    <xsl:sequence select="string-join($parts[position() lt count($parts)], '.')"/>
  </xsl:function>

  <!-- Clean up a method/property name for display -->
  <xsl:function name="my:display-name" as="xs:string"
>
    <xsl:param name="name" as="xs:string"/>
    <xsl:variable name="full" select="my:member-name($name)"/>
    <xsl:variable name="parent" select="my:parent-type($name)"/>
    <xsl:variable name="after-type" select="substring-after($full, concat($parent, '.'))"/>
    <!-- Clean up generic params: replace {T} with &lt;T&gt; style -->
    <xsl:variable name="cleaned" select="replace(replace($after-type, '\{', '&lt;'), '\}', '&gt;')"/>
    <!-- Clean up system type names in params -->
    <xsl:variable name="simplified" select="replace($cleaned, 'System\.([A-Za-z]+)', '$1')"/>
    <xsl:sequence select="$simplified"/>
  </xsl:function>

  <!-- Slugify a name for use as an anchor ID -->
  <xsl:function name="my:slugify" as="xs:string"
>
    <xsl:param name="name" as="xs:string"/>
    <xsl:sequence select="lower-case(replace(replace($name, '[^a-zA-Z0-9]+', '-'), '^-|-$', ''))"/>
  </xsl:function>

  <!-- Generate a file-safe name from a type -->
  <xsl:function name="my:file-name" as="xs:string"
>
    <xsl:param name="type-name" as="xs:string"/>
    <xsl:sequence select="lower-case(replace(my:local-name-of($type-name), '[^a-zA-Z0-9]', '-'))"/>
  </xsl:function>

  <!-- ============================================================ -->
  <!-- cref helpers                                                 -->
  <!-- ============================================================ -->

  <!-- The type that declares a cref target: T: is the type itself,
       M:/P:/F:/E: are members of their parent type. -->
  <xsl:function name="my:cref-type" as="xs:string">
    <xsl:param name="cref" as="xs:string"/>
    <xsl:sequence select="
      if (starts-with($cref, 'T:')) then my:member-name($cref)
      else my:parent-type($cref)
    "/>
  </xsl:function>

  <!-- Member name without its parameter list (SetMetadataAsync, not
       SetMetadataAsync(String,String,Object,CancellationToken)). Inline prose
       reads far better with the short form. -->
  <xsl:function name="my:member-short" as="xs:string">
    <xsl:param name="cref" as="xs:string"/>
    <xsl:variable name="full" select="my:member-name($cref)"/>
    <xsl:variable name="without-params" select="
      if (contains($full, '(')) then substring-before($full, '(')
      else $full
    "/>
    <xsl:sequence select="my:local-name-of($without-params)"/>
  </xsl:function>

  <!-- Display text for a cref with no explicit content. -->
  <xsl:function name="my:cref-text" as="xs:string">
    <xsl:param name="cref" as="xs:string"/>
    <xsl:variable name="short" select="my:member-short($cref)"/>
    <xsl:variable name="owner" select="my:local-name-of(my:cref-type($cref))"/>
    <xsl:sequence select="
      if (starts-with($cref, 'T:')) then my:local-name-of(my:member-name($cref))
      else if ($short = '#ctor') then concat($owner, ' constructor')
      else concat($owner, '.', $short)
    "/>
  </xsl:function>

  <!-- Strip the uniform leading indentation the compiler carries over from the
       /// comment, and trim surrounding blank lines, so code samples render
       flush-left instead of indented 12 spaces. -->
  <xsl:function name="my:dedent" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:variable name="lines" select="tokenize(replace($s, '&#13;', ''), '&#10;')"/>
    <xsl:variable name="nonblank" select="$lines[normalize-space(.) != '']"/>
    <xsl:variable name="indent" as="xs:integer" select="
      if (empty($nonblank)) then 0
      else min(for $l in $nonblank return string-length(replace($l, '^(\s*).*$', '$1')))
    "/>
    <xsl:variable name="stripped" as="xs:string*" select="
      for $l in $lines return
        if (string-length($l) ge $indent) then substring($l, $indent + 1) else ''
    "/>
    <xsl:sequence select="replace(replace(string-join($stripped, '&#10;'), '^\n+', ''), '\s+$', '')"/>
  </xsl:function>

  <!-- ============================================================ -->
  <!-- Doc-comment content: mixed-content rendering                 -->
  <!-- ============================================================ -->

  <!-- Split mixed content into adjacent runs of block-level and inline nodes.
       Inline runs become a <paragraph>; block nodes render themselves. -->
  <xsl:template name="doc-blocks">
    <xsl:param name="content" as="node()*"/>
    <xsl:for-each-group select="$content"
        group-adjacent="if (self::para or self::code or self::list or self::example)
                        then 'block' else 'inline'">
      <xsl:choose>
        <xsl:when test="current-grouping-key() = 'block'">
          <xsl:apply-templates select="current-group()" mode="doc-block"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- An inline run of nothing but whitespace is just formatting between
               blocks. But a run holding only empty elements (a lone <see cref/>)
               has an empty string-value while still being real content, so test
               for those separately. -->
          <xsl:if test="normalize-space(string-join(current-group(), '')) != ''
                        or current-group()[self::see or self::c or self::paramref
                                           or self::typeparamref or self::b or self::i
                                           or self::em or self::seealso]">
            <paragraph>
              <xsl:apply-templates select="current-group()" mode="doc-inline"/>
            </paragraph>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each-group>
  </xsl:template>

  <!-- Convenience: render an element's children as blocks. -->
  <xsl:template name="doc-body">
    <xsl:call-template name="doc-blocks">
      <xsl:with-param name="content" select="node()"/>
    </xsl:call-template>
  </xsl:template>

  <!-- === block-level === -->

  <xsl:template match="para" mode="doc-block">
    <xsl:call-template name="doc-body"/>
  </xsl:template>

  <xsl:template match="example" mode="doc-block">
    <xsl:call-template name="doc-body"/>
  </xsl:template>

  <!-- <code> is the BLOCK form in .NET doc comments; <c> is the inline form. -->
  <xsl:template match="code" mode="doc-block">
    <xsl:variable name="text" select="my:dedent(string(.))"/>
    <code-block language="{
      if (@language) then @language
      else if (starts-with(normalize-space($text), '&lt;')) then 'xml'
      else 'csharp'
    }"><xsl:value-of select="$text"/></code-block>
  </xsl:template>

  <xsl:template match="list" mode="doc-block">
    <list type="{if (@type = 'number') then 'ordered' else 'unordered'}">
      <xsl:for-each select="item">
        <item>
          <paragraph>
            <xsl:choose>
              <!-- <item><term>X</term><description>Y</description></item> -->
              <xsl:when test="term">
                <strong><xsl:apply-templates select="term/node()" mode="doc-inline"/></strong>
                <xsl:text> — </xsl:text>
                <xsl:apply-templates select="description/node()" mode="doc-inline"/>
              </xsl:when>
              <xsl:when test="description">
                <xsl:apply-templates select="description/node()" mode="doc-inline"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:apply-templates select="node()" mode="doc-inline"/>
              </xsl:otherwise>
            </xsl:choose>
          </paragraph>
        </item>
      </xsl:for-each>
    </list>
  </xsl:template>

  <!-- Unrecognised block-ish element: fall back to treating its children as content. -->
  <xsl:template match="*" mode="doc-block">
    <xsl:call-template name="doc-body"/>
  </xsl:template>

  <xsl:template match="text()" mode="doc-block">
    <xsl:if test="normalize-space(.) != ''">
      <paragraph><xsl:value-of select="replace(., '\s+', ' ')"/></paragraph>
    </xsl:if>
  </xsl:template>

  <!-- === inline === -->

  <!-- Collapse whitespace runs but do NOT trim: the spaces on either side of an
       inline element are meaningful, and normalize-space() would eat them. -->
  <xsl:template match="text()" mode="doc-inline">
    <xsl:value-of select="replace(., '\s+', ' ')"/>
  </xsl:template>

  <xsl:template match="c" mode="doc-inline">
    <code><xsl:value-of select="normalize-space(.)"/></code>
  </xsl:template>

  <xsl:template match="b|strong" mode="doc-inline">
    <strong><xsl:apply-templates mode="doc-inline"/></strong>
  </xsl:template>

  <xsl:template match="i|em" mode="doc-inline">
    <emphasis><xsl:apply-templates mode="doc-inline"/></emphasis>
  </xsl:template>

  <xsl:template match="paramref|typeparamref" mode="doc-inline">
    <code><xsl:value-of select="@name"/></code>
  </xsl:template>

  <!-- <see langword="true"/> etc. -->
  <xsl:template match="see[@langword]" mode="doc-inline">
    <code><xsl:value-of select="@langword"/></code>
  </xsl:template>

  <xsl:template match="see[@href]|seealso[@href]" mode="doc-inline">
    <link href="{@href}">
      <xsl:value-of select="if (normalize-space(.) != '') then normalize-space(.) else @href"/>
    </link>
  </xsl:template>

  <xsl:template match="see[@cref]|seealso[@cref]" mode="doc-inline">
    <xsl:call-template name="render-cref"/>
  </xsl:template>

  <!-- <inheritdoc/> is not expanded by the compiler, so there is nothing to show. -->
  <xsl:template match="inheritdoc" mode="doc-inline"/>
  <xsl:template match="inheritdoc" mode="doc-block"/>

  <xsl:template match="comment()|processing-instruction()" mode="doc-inline"/>
  <xsl:template match="comment()|processing-instruction()" mode="doc-block"/>

  <!-- Unknown inline element: keep the text, drop the wrapper. -->
  <xsl:template match="*" mode="doc-inline">
    <xsl:apply-templates mode="doc-inline"/>
  </xsl:template>

  <!-- Turn a cref into a cross-link when it points at a type documented in this
       run; otherwise render it as inline code (System.*, excluded namespaces,
       and other assemblies all land here). -->
  <xsl:template name="render-cref">
    <!-- <exception cref="X">why it is thrown</exception> carries a DESCRIPTION as
         its content, not link text, so callers there pass use-content=false. -->
    <xsl:param name="use-content" as="xs:boolean" select="true()"/>
    <xsl:variable name="cref" select="string(@cref)"/>
    <xsl:variable name="owner" select="my:cref-type($cref)"/>
    <xsl:variable name="text" select="
      if ($use-content and normalize-space(.) != '') then normalize-space(.)
      else my:cref-text($cref)
    "/>
    <xsl:choose>
      <xsl:when test="$owner = $type-name-set">
        <xsl:variable name="anchor" select="
          if ($cref = $anchored-members)
          then concat('#', my:slugify(my:display-name($cref)))
          else ''
        "/>
        <link href="/{$base-path}/{my:file-name($owner)}{$anchor}">
          <code><xsl:value-of select="$text"/></code>
        </link>
      </xsl:when>
      <xsl:otherwise>
        <code><xsl:value-of select="$text"/></code>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Main template: process the doc element -->
  <!-- ============================================================ -->
  <xsl:template match="/doc">
    <xsl:variable name="asm" select="if ($assembly-name != '') then $assembly-name else assembly/name"/>

    <!-- Generate the namespace index page as the primary output -->
    <document path="{$base-path}/index" title="{$asm} API Reference"
              description="API documentation for the {$asm} library">
      <body>
        <heading level="1" id="api-reference"><xsl:value-of select="$asm"/> API Reference</heading>

        <paragraph>
          This reference is auto-generated from the .NET XML documentation
          for the <code><xsl:value-of select="$asm"/></code> assembly.
        </paragraph>

        <!-- Group types by namespace -->
        <xsl:for-each-group select="$types" group-by="my:namespace-of(my:member-name(@name))">
          <xsl:sort select="current-grouping-key()"/>

          <heading level="2" id="{my:slugify(current-grouping-key())}">
            <xsl:value-of select="current-grouping-key()"/>
          </heading>

          <table>
            <table-head>
              <row>
                <cell header="true">Type</cell>
                <cell header="true">Description</cell>
              </row>
            </table-head>
            <table-body>
              <xsl:for-each select="current-group()">
                <xsl:sort select="my:local-name-of(my:member-name(@name))"/>
                <xsl:variable name="type-name" select="my:member-name(@name)"/>
                <xsl:variable name="local" select="my:local-name-of($type-name)"/>
                <row>
                  <cell>
                    <!-- Root-relative and extensionless: a bare "api/core/x.html"
                         is RELATIVE, so from /api/core/ it resolves to
                         /api/core/api/core/x.html. -->
                    <link href="/{$base-path}/{my:file-name($type-name)}">
                      <code><xsl:value-of select="$local"/></code>
                    </link>
                  </cell>
                  <cell>
                    <xsl:apply-templates select="summary/node()" mode="doc-inline"/>
                  </cell>
                </row>
              </xsl:for-each>
            </table-body>
          </table>
        </xsl:for-each-group>
      </body>
    </document>

    <!-- Generate one document per type -->
    <xsl:for-each select="$types">
      <xsl:variable name="type-name" select="my:member-name(@name)"/>
      <xsl:variable name="local" select="my:local-name-of($type-name)"/>
      <xsl:variable name="file" select="my:file-name($type-name)"/>

      <!-- Find all members belonging to this type -->
      <xsl:variable name="type-members" select="$all-members[
        my:member-prefix(@name) != 'T:' and
        my:parent-type(@name) = $type-name
      ]"/>

      <xsl:variable name="properties" select="$type-members[starts-with(@name, 'P:')]"/>
      <xsl:variable name="methods" select="$type-members[starts-with(@name, 'M:')]"/>
      <xsl:variable name="fields" select="$type-members[starts-with(@name, 'F:')]"/>
      <xsl:variable name="constructors" select="$methods[contains(@name, '.#ctor')]"/>
      <xsl:variable name="regular-methods" select="$methods[not(contains(@name, '.#ctor'))]"/>

      <xsl:result-document href="{$file}.xml">
        <document path="{$base-path}/{$file}" title="{$local}"
                  description="{normalize-space(summary)}">
          <body>
            <heading level="1" id="{my:slugify($local)}">
              <xsl:value-of select="$local"/>
            </heading>

            <paragraph>
              <strong>Namespace:</strong><xsl:text> </xsl:text>
              <code><xsl:value-of select="my:namespace-of($type-name)"/></code>
            </paragraph>

            <xsl:apply-templates select="summary/node()" mode="doc-block"/>

            <xsl:if test="typeparam">
              <paragraph><strong>Type parameters:</strong></paragraph>
              <list type="unordered">
                <xsl:for-each select="typeparam">
                  <item>
                    <paragraph>
                      <code><xsl:value-of select="@name"/></code>
                      <xsl:text> — </xsl:text>
                      <xsl:apply-templates select="node()" mode="doc-inline"/>
                    </paragraph>
                  </item>
                </xsl:for-each>
              </list>
            </xsl:if>

            <xsl:if test="remarks">
              <xsl:apply-templates select="remarks/node()" mode="doc-block"/>
            </xsl:if>

            <xsl:if test="example">
              <heading level="2" id="example">Example</heading>
              <xsl:apply-templates select="example/node()" mode="doc-block"/>
            </xsl:if>

            <!-- Constructors -->
            <xsl:if test="$constructors">
              <heading level="2" id="constructors">Constructors</heading>
              <xsl:for-each select="$constructors">
                <xsl:call-template name="render-member"/>
              </xsl:for-each>
            </xsl:if>

            <!-- Properties -->
            <xsl:if test="$properties">
              <heading level="2" id="properties">Properties</heading>
              <table>
                <table-head>
                  <row>
                    <cell header="true">Name</cell>
                    <cell header="true">Description</cell>
                  </row>
                </table-head>
                <table-body>
                  <xsl:for-each select="$properties">
                    <xsl:sort select="my:display-name(@name)"/>
                    <row>
                      <cell>
                        <code><xsl:value-of select="my:display-name(@name)"/></code>
                      </cell>
                      <cell>
                        <xsl:apply-templates select="summary/node()" mode="doc-inline"/>
                        <xsl:if test="normalize-space(value) != ''">
                          <xsl:text> </xsl:text>
                          <xsl:apply-templates select="value/node()" mode="doc-inline"/>
                        </xsl:if>
                      </cell>
                    </row>
                  </xsl:for-each>
                </table-body>
              </table>
            </xsl:if>

            <!-- Methods -->
            <xsl:if test="$regular-methods">
              <heading level="2" id="methods">Methods</heading>
              <xsl:for-each select="$regular-methods">
                <xsl:sort select="my:display-name(@name)"/>
                <xsl:call-template name="render-member"/>
              </xsl:for-each>
            </xsl:if>

            <!-- Fields -->
            <xsl:if test="$fields">
              <heading level="2" id="fields">Fields</heading>
              <table>
                <table-head>
                  <row>
                    <cell header="true">Name</cell>
                    <cell header="true">Description</cell>
                  </row>
                </table-head>
                <table-body>
                  <xsl:for-each select="$fields">
                    <xsl:sort select="my:display-name(@name)"/>
                    <row>
                      <cell>
                        <code><xsl:value-of select="my:display-name(@name)"/></code>
                      </cell>
                      <cell>
                        <xsl:apply-templates select="summary/node()" mode="doc-inline"/>
                      </cell>
                    </row>
                  </xsl:for-each>
                </table-body>
              </table>
            </xsl:if>

            <!-- See also -->
            <xsl:if test="seealso">
              <heading level="2" id="see-also">See also</heading>
              <list type="unordered">
                <xsl:for-each select="seealso">
                  <item>
                    <paragraph><xsl:apply-templates select="." mode="doc-inline"/></paragraph>
                  </item>
                </xsl:for-each>
              </list>
            </xsl:if>
          </body>
        </document>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <!-- ============================================================ -->
  <!-- Render a method or constructor member -->
  <!-- ============================================================ -->
  <xsl:template name="render-member">
    <xsl:variable name="display" select="my:display-name(@name)"/>
    <xsl:variable name="slug" select="my:slugify($display)"/>

    <heading level="3" id="{$slug}">
      <xsl:value-of select="$display"/>
    </heading>

    <xsl:apply-templates select="summary/node()" mode="doc-block"/>

    <!-- Type parameters -->
    <xsl:if test="typeparam">
      <paragraph><strong>Type parameters:</strong></paragraph>
      <list type="unordered">
        <xsl:for-each select="typeparam">
          <item>
            <paragraph>
              <code><xsl:value-of select="@name"/></code>
              <xsl:text> — </xsl:text>
              <xsl:apply-templates select="node()" mode="doc-inline"/>
            </paragraph>
          </item>
        </xsl:for-each>
      </list>
    </xsl:if>

    <!-- Parameters -->
    <xsl:if test="param">
      <paragraph><strong>Parameters:</strong></paragraph>
      <list type="unordered">
        <xsl:for-each select="param">
          <item>
            <paragraph>
              <code><xsl:value-of select="@name"/></code>
              <xsl:text> — </xsl:text>
              <xsl:apply-templates select="node()" mode="doc-inline"/>
            </paragraph>
          </item>
        </xsl:for-each>
      </list>
    </xsl:if>

    <!-- Returns. Some members use the non-standard <return>; accept both so the
         text is not silently dropped. -->
    <xsl:if test="returns|return">
      <paragraph>
        <strong>Returns:</strong>
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="(returns|return)[1]/node()" mode="doc-inline"/>
      </paragraph>
    </xsl:if>

    <!-- Exceptions -->
    <xsl:if test="exception">
      <paragraph><strong>Exceptions:</strong></paragraph>
      <list type="unordered">
        <xsl:for-each select="exception">
          <item>
            <paragraph>
              <xsl:call-template name="render-cref">
                <xsl:with-param name="use-content" select="false()"/>
              </xsl:call-template>
              <xsl:text> — </xsl:text>
              <xsl:apply-templates select="node()" mode="doc-inline"/>
            </paragraph>
          </item>
        </xsl:for-each>
      </list>
    </xsl:if>

    <!-- Remarks -->
    <xsl:if test="remarks">
      <xsl:apply-templates select="remarks/node()" mode="doc-block"/>
    </xsl:if>

    <!-- Example -->
    <xsl:if test="example">
      <paragraph><strong>Example:</strong></paragraph>
      <xsl:apply-templates select="example/node()" mode="doc-block"/>
    </xsl:if>

    <!-- See also -->
    <xsl:if test="seealso">
      <paragraph>
        <strong>See also:</strong>
        <xsl:for-each select="seealso">
          <xsl:if test="position() gt 1"><xsl:text>, </xsl:text></xsl:if>
          <xsl:text> </xsl:text>
          <xsl:apply-templates select="." mode="doc-inline"/>
        </xsl:for-each>
      </paragraph>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
