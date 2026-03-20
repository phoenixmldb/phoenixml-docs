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
  <!-- Main template: process the doc element -->
  <!-- ============================================================ -->
  <xsl:template match="/doc">
    <xsl:variable name="asm" select="if ($assembly-name != '') then $assembly-name else assembly/name"/>
    <!-- Filter types: exclude namespaces matching the exclude list -->
    <xsl:variable name="all-types" select="members/member[starts-with(@name, 'T:')]"/>
    <xsl:variable name="types" select="$all-types[
      not(some $ex in $excluded satisfies
        starts-with(my:namespace-of(my:member-name(@name)), $ex)
      )
    ]"/>
    <xsl:variable name="all-members" select="members/member"/>

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
                    <link href="{$base-path}/{my:file-name($type-name)}.html">
                      <code><xsl:value-of select="$local"/></code>
                    </link>
                  </cell>
                  <cell>
                    <xsl:value-of select="normalize-space(summary)"/>
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

            <xsl:if test="normalize-space(summary)">
              <paragraph><xsl:value-of select="normalize-space(summary)"/></paragraph>
            </xsl:if>

            <xsl:if test="normalize-space(remarks)">
              <paragraph><xsl:value-of select="normalize-space(remarks)"/></paragraph>
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
                        <xsl:value-of select="normalize-space(summary)"/>
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
                        <xsl:value-of select="normalize-space(summary)"/>
                      </cell>
                    </row>
                  </xsl:for-each>
                </table-body>
              </table>
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

    <xsl:if test="normalize-space(summary)">
      <paragraph><xsl:value-of select="normalize-space(summary)"/></paragraph>
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
              <xsl:value-of select="normalize-space(.)"/>
            </paragraph>
          </item>
        </xsl:for-each>
      </list>
    </xsl:if>

    <!-- Returns -->
    <xsl:if test="returns">
      <paragraph>
        <strong>Returns:</strong>
        <xsl:text> </xsl:text>
        <xsl:value-of select="normalize-space(returns)"/>
      </paragraph>
    </xsl:if>

    <!-- Remarks -->
    <xsl:if test="remarks">
      <paragraph>
        <xsl:value-of select="normalize-space(remarks)"/>
      </paragraph>
    </xsl:if>

    <!-- Exceptions -->
    <xsl:if test="exception">
      <paragraph><strong>Exceptions:</strong></paragraph>
      <list type="unordered">
        <xsl:for-each select="exception">
          <item>
            <paragraph>
              <code><xsl:value-of select="my:local-name-of(substring-after(@cref, 'T:'))"/></code>
              <xsl:text> — </xsl:text>
              <xsl:value-of select="normalize-space(.)"/>
            </paragraph>
          </item>
        </xsl:for-each>
      </list>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
