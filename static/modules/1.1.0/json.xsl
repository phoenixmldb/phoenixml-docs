<?xml version="1.0" encoding="UTF-8"?>
<!--
  JSON to readable XML, for XSLT 3.0.

  Import this stylesheet module and call its functions:
    <xsl:import href="https://phoenixml.dev/modules/1.1.0/json.xsl"/>
    <xsl:sequence select="jx:to-xml(unparsed-text('data.json'), 'data')"/>

  The readable form:
  - An object member gives an element named by its key. A key that is not a valid
    XML name gives <entry key="...">.
  - An array gives one <item> child for each member.
  - A string, number or boolean gives its text. null gives an empty element.
  - Member order is kept.

  Licensed under the Apache License, Version 2.0.
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:jx="https://phoenixml.dev/modules/xslt/json"
    exclude-result-prefixes="#all">

  <!-- JSON text as readable XML, with a root element named $root. -->
  <xsl:function name="jx:to-xml" as="element()">
    <xsl:param name="json" as="xs:string"/>
    <xsl:param name="root" as="xs:string"/>
    <xsl:sequence select="jx:from-w3c(json-to-xml($json)/*, $root)"/>
  </xsl:function>

  <!--
    The W3C XML representation of JSON (the result of fn:json-to-xml: fn:map,
    fn:array, fn:string, ...) as readable XML, with a root element named $root.
  -->
  <xsl:function name="jx:from-w3c" as="element()">
    <xsl:param name="w3c" as="element()"/>
    <xsl:param name="root" as="xs:string"/>
    <xsl:element name="{ $root }">
      <xsl:apply-templates select="$w3c" mode="jx:content"/>
    </xsl:element>
  </xsl:function>

  <xsl:template match="fn:map" mode="jx:content">
    <xsl:for-each select="*">
      <xsl:choose>
        <xsl:when test="@key castable as xs:NCName">
          <xsl:element name="{ @key }">
            <xsl:apply-templates select="." mode="jx:content"/>
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <entry key="{ @key }">
            <xsl:apply-templates select="." mode="jx:content"/>
          </entry>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="fn:array" mode="jx:content">
    <xsl:for-each select="*">
      <item>
        <xsl:apply-templates select="." mode="jx:content"/>
      </item>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="fn:string | fn:number | fn:boolean" mode="jx:content">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="fn:null" mode="jx:content"/>

</xsl:stylesheet>
