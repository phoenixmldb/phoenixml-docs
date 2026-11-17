<?xml version="1.0" encoding="UTF-8"?>
<!--
  Converts one YAML file to readable XML.
    xslt -it main yaml-to-xml.xsl -p href="$PWD/config.yaml" -p root=config
  A relative href resolves against this stylesheet's location, so pass an absolute path.
  Licensed under the Apache License, Version 2.0.
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:yx="https://phoenixml.dev/modules/xslt/yaml"
    exclude-result-prefixes="#all">
  <xsl:import href="yaml.xsl"/>
  <xsl:param name="href" as="xs:string" required="yes"/>
  <xsl:param name="root" as="xs:string" select="'yaml'"/>
  <xsl:output method="xml" indent="yes"/>
  <xsl:template name="main">
    <xsl:sequence select="yx:to-xml(unparsed-text(resolve-uri($href)), $root)"/>
  </xsl:template>
</xsl:stylesheet>
