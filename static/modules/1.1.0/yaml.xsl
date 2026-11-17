<?xml version="1.0" encoding="UTF-8"?>
<!--
  YAML to XML and JSON, for XSLT 3.0.

  Import this stylesheet module and call its functions:
    <xsl:import href="https://phoenixml.dev/modules/1.1.0/yaml.xsl"/>
    <xsl:sequence select="yx:to-xml(unparsed-text('config.yaml'), 'config')"/>

  Functions:
    yx:to-xml($yaml, $root)  readable XML, the same form as jx:to-xml (json.xsl)
    yx:to-w3c($yaml)         the W3C XML representation of JSON (fn:map, fn:array, ...)
    yx:to-json($yaml)        JSON text
    yx:parse($yaml)          maps and arrays, as parse-json() gives them

  Supported YAML (one document): block mappings and sequences, including a mapping
  inside a sequence item ("- name: x"); plain, single-quoted and double-quoted
  scalars on one line; flow collections on one line ([a, b], {a: 1}); literal (|)
  and folded (>) block scalars with the chomping indicators - and +; comments;
  a leading "- - -" document marker. Plain scalars resolve as in the YAML 1.2 core
  schema: null, true/false, integers (also 0x and 0o), floats; everything else is
  a string. .inf and .nan give the strings ".inf" and ".nan", because JSON has no
  such numbers.

  Not supported, with the error yx:unsupported: anchors (&), aliases (*), tags (!),
  complex keys (?), several documents, and scalars or flow collections that span
  more than one line. Wrong indentation gives the error yx:syntax.

  Licensed under the Apache License, Version 2.0.
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:jx="https://phoenixml.dev/modules/xslt/json"
    xmlns:yx="https://phoenixml.dev/modules/xslt/yaml"
    exclude-result-prefixes="#all">

  <xsl:import href="json.xsl"/>

  <!-- A mapping key, then ":" and the rest of the line. Groups: 2 double-quoted,
       4 single-quoted, 6 plain key; 8 the value text. -->
  <xsl:variable name="yx:key-re" as="xs:string" select="'^(&quot;(([^&quot;\\]|\\.)*)&quot;|''(([^'']|'''')*)''|([^\s#''&quot;\[\]{},?:\-&amp;*!|&gt;%@`][^#]*?|-[^\s#][^#]*?))\s*:(\s+(.*))?$'"/>

  <!-- ===== Public functions ===== -->

  <xsl:function name="yx:to-w3c" as="element()">
    <xsl:param name="yaml" as="xs:string"/>
    <xsl:variable name="lines" select="yx:lines($yaml)" as="map(*)*"/>
    <xsl:variable name="first" select="yx:skip($lines, 1)"/>
    <xsl:choose>
      <xsl:when test="$first gt count($lines)">
        <fn:null/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="r" select="yx:block($lines, $first)"/>
        <xsl:variable name="rest" select="yx:skip($lines, $r?i)"/>
        <xsl:if test="$rest le count($lines)">
          <xsl:sequence select="yx:fail('syntax', $lines[$rest], 'unexpected content or indentation')"/>
        </xsl:if>
        <xsl:sequence select="$r?v"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="yx:to-xml" as="element()">
    <xsl:param name="yaml" as="xs:string"/>
    <xsl:param name="root" as="xs:string"/>
    <xsl:sequence select="jx:from-w3c(yx:to-w3c($yaml), $root)"/>
  </xsl:function>

  <xsl:function name="yx:to-json" as="xs:string">
    <xsl:param name="yaml" as="xs:string"/>
    <xsl:sequence select="xml-to-json(yx:to-w3c($yaml))"/>
  </xsl:function>

  <xsl:function name="yx:parse" as="item()?">
    <xsl:param name="yaml" as="xs:string"/>
    <xsl:sequence select="parse-json(yx:to-json($yaml))"/>
  </xsl:function>

  <!-- ===== Lines ===== -->

  <!-- One map for each line: n (line number), raw, ind (indent), txt (without
       indent and comment). Document markers and directives become blank lines. -->
  <xsl:function name="yx:lines" as="map(*)*">
    <xsl:param name="yaml" as="xs:string"/>
    <xsl:variable name="raw" select="tokenize(replace($yaml, '^&#xFEFF;', ''), '\r\n|\r|\n')"/>
    <xsl:variable name="markers" select="index-of($raw ! replace(., '\s+(#.*)?$', ''), '---')"/>
    <xsl:variable name="content-before-marker"
        select="exists($markers) and
                (some $l in subsequence($raw, 1, $markers[1] - 1)
                 satisfies not(matches($l, '^\s*(#.*|%.*)?$')))"/>
    <xsl:if test="count($markers) gt 1 or $content-before-marker">
      <xsl:sequence select="error(QName('https://phoenixml.dev/modules/xslt/yaml', 'yx:unsupported'),
                                  'YAML: several documents are not supported.')"/>
    </xsl:if>
    <xsl:for-each select="$raw">
      <xsl:variable name="n" select="position()"/>
      <xsl:variable name="ind" select="string-length(.) - string-length(replace(., '^ +', ''))"/>
      <xsl:variable name="body" select="substring(., $ind + 1)"/>
      <xsl:variable name="is-marker"
          select="$n = $markers or ($n lt ($markers[1], 0)[1] and starts-with($body, '%'))
                  or replace($body, '\s+(#.*)?$', '') eq '...'"/>
      <xsl:if test="starts-with($body, '&#9;') and not($is-marker)">
        <xsl:sequence select="error(QName('https://phoenixml.dev/modules/xslt/yaml', 'yx:syntax'),
                                    'YAML line ' || $n || ': a tab in the indentation.')"/>
      </xsl:if>
      <xsl:sequence select="map {
          'n': $n, 'raw': string(.), 'ind': $ind,
          'txt': if ($is-marker) then '' else yx:strip-comment($body) }"/>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="yx:strip-comment" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <!-- Quoted text is kept whole, so a "#" inside quotes does not start a comment. -->
    <xsl:variable name="parts" as="xs:string*">
      <xsl:analyze-string select="$s" regex="&quot;([^&quot;\\]|\\.)*&quot;|'([^']|'')*'|(^|\s)#.*$">
        <xsl:matching-substring>
          <xsl:sequence select="if (matches(., '^\s*#')) then '&#xE000;' else string(.)"/>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:sequence select="string(.)"/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:variable name="cut" select="(index-of($parts, '&#xE000;')[1] - 1, count($parts))[1]"/>
    <xsl:sequence select="replace(string-join(subsequence($parts, 1, $cut), ''), '\s+$', '')"/>
  </xsl:function>

  <!-- The index of the first line at or after $i with content. -->
  <xsl:function name="yx:skip" as="xs:integer">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="i" as="xs:integer"/>
    <xsl:sequence select="(for $j in $i to count($lines) return $j[$lines[$j]?txt ne ''], count($lines) + 1)[1]"/>
  </xsl:function>

  <xsl:function name="yx:is-item" as="xs:boolean">
    <xsl:param name="txt" as="xs:string"/>
    <xsl:sequence select="matches($txt, '^-(\s|$)')"/>
  </xsl:function>

  <xsl:function name="yx:is-entry" as="xs:boolean">
    <xsl:param name="txt" as="xs:string"/>
    <xsl:sequence select="matches($txt, $yx:key-re)"/>
  </xsl:function>

  <!-- ===== Block structure ===== -->

  <!-- The node that starts at line $i, at that line's indent. Result: map { v, i }. -->
  <xsl:function name="yx:block" as="map(*)">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="i" as="xs:integer"/>
    <xsl:variable name="l" select="$lines[$i]"/>
    <xsl:sequence select="
        if (yx:is-item($l?txt)) then yx:seq($lines, $i, $l?ind)
        else if (yx:is-entry($l?txt)) then yx:map($lines, $i, $l?ind)
        else if (matches($l?txt, '^[|&gt;]')) then yx:fail('syntax', $l, 'a block scalar must follow a key or a dash')
        else map { 'v': yx:scalar($l?txt, $l), 'i': $i + 1 }"/>
  </xsl:function>

  <xsl:function name="yx:map" as="map(*)">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="i" as="xs:integer"/>
    <xsl:param name="col" as="xs:integer"/>
    <xsl:variable name="r" select="yx:entries($lines, $i, $col, ())"/>
    <xsl:variable name="keys" select="$r?e/@key/string()"/>
    <xsl:variable name="dup" select="$keys[index-of($keys, .)[2]][1]"/>
    <xsl:if test="exists($dup)">
      <xsl:sequence select="yx:fail('syntax', $lines[$i], 'the key &quot;' || $dup || '&quot; occurs twice')"/>
    </xsl:if>
    <xsl:sequence select="map { 'v': yx:wrap(QName('http://www.w3.org/2005/xpath-functions', 'map'), $r?e), 'i': $r?i }"/>
  </xsl:function>

  <xsl:function name="yx:entries" as="map(*)">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="i" as="xs:integer"/>
    <xsl:param name="col" as="xs:integer"/>
    <xsl:param name="done" as="element()*"/>
    <xsl:variable name="j" select="yx:skip($lines, $i)"/>
    <xsl:variable name="l" select="$lines[$j]"/>
    <xsl:choose>
      <xsl:when test="$j gt count($lines) or $l?ind lt $col">
        <xsl:sequence select="map { 'e': $done, 'i': $j }"/>
      </xsl:when>
      <xsl:when test="$l?ind gt $col">
        <xsl:sequence select="yx:fail('syntax', $l, 'unexpected indentation')"/>
      </xsl:when>
      <xsl:when test="not(yx:is-entry($l?txt))">
        <xsl:sequence select="map { 'e': $done, 'i': $j }"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="key" select="yx:key($l?txt, $l)"/>
        <xsl:variable name="rest" select="replace($l?txt, $yx:key-re, '$8')"/>
        <xsl:variable name="r" select="yx:value($lines, $j, $col, $rest, true())"/>
        <xsl:sequence select="yx:entries($lines, $r?i, $col, ($done, yx:keyed($r?v, $key)))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="yx:seq" as="map(*)">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="i" as="xs:integer"/>
    <xsl:param name="col" as="xs:integer"/>
    <xsl:variable name="r" select="yx:items($lines, $i, $col, ())"/>
    <xsl:sequence select="map { 'v': yx:wrap(QName('http://www.w3.org/2005/xpath-functions', 'array'), $r?e), 'i': $r?i }"/>
  </xsl:function>

  <xsl:function name="yx:items" as="map(*)">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="i" as="xs:integer"/>
    <xsl:param name="col" as="xs:integer"/>
    <xsl:param name="done" as="element()*"/>
    <xsl:variable name="j" select="yx:skip($lines, $i)"/>
    <xsl:variable name="l" select="$lines[$j]"/>
    <xsl:choose>
      <xsl:when test="$j gt count($lines) or $l?ind lt $col or not(yx:is-item($l?txt))">
        <xsl:sequence select="map { 'e': $done, 'i': $j }"/>
      </xsl:when>
      <xsl:when test="$l?ind gt $col">
        <xsl:sequence select="yx:fail('syntax', $l, 'unexpected indentation')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="content" select="replace($l?txt, '^-\s*', '')"/>
        <xsl:variable name="ccol" select="$col + string-length($l?txt) - string-length($content)"/>
        <xsl:variable name="r" as="map(*)">
          <xsl:choose>
            <xsl:when test="$content ne '' and (yx:is-item($content) or yx:is-entry($content))">
              <!-- "- - a" or "- key: value": the content starts a node at its own column. -->
              <xsl:variable name="moved" select="(subsequence($lines, 1, $j - 1),
                  map:merge((map { 'ind': $ccol, 'txt': $content }, $l)),
                  subsequence($lines, $j + 1))"/>
              <xsl:sequence select="yx:block($moved, $j)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:sequence select="yx:value($lines, $j, $col, $content, false())"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:sequence select="yx:items($lines, $r?i, $col, ($done, $r?v))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- The value after "key:" or "-" on line $j. $col is the key's or dash's column.
       In a mapping, a sequence may start at the key's own column. -->
  <xsl:function name="yx:value" as="map(*)">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="j" as="xs:integer"/>
    <xsl:param name="col" as="xs:integer"/>
    <xsl:param name="rest" as="xs:string"/>
    <xsl:param name="in-map" as="xs:boolean"/>
    <xsl:variable name="k" select="yx:skip($lines, $j + 1)"/>
    <xsl:variable name="next" select="$lines[$k]"/>
    <xsl:sequence select="
        if ($rest eq '') then
          if ($k le count($lines) and
              ($next?ind gt $col or ($in-map and $next?ind eq $col and yx:is-item($next?txt))))
          then yx:block($lines, $k)
          else map { 'v': yx:null(), 'i': $j + 1 }
        else if (matches($rest, '^[|&gt;]')) then yx:block-scalar($lines, $j, $col, $rest)
        else map { 'v': yx:scalar($rest, $lines[$j]), 'i': $j + 1 }"/>
  </xsl:function>

  <xsl:function name="yx:block-scalar" as="map(*)">
    <xsl:param name="lines" as="map(*)*"/>
    <xsl:param name="j" as="xs:integer"/>
    <xsl:param name="col" as="xs:integer"/>
    <xsl:param name="header" as="xs:string"/>
    <xsl:if test="not(matches($header, '^[|&gt;][+\-]?$'))">
      <xsl:sequence select="yx:fail('unsupported', $lines[$j], 'block scalar header &quot;' || $header || '&quot;')"/>
    </xsl:if>
    <!-- The block is every following line that is blank or indented more than $col. -->
    <xsl:variable name="end" select="(for $x in $j + 1 to count($lines)
        return $x[normalize-space($lines[$x]?raw) ne '' and $lines[$x]?ind le $col], count($lines) + 1)[1]"/>
    <xsl:variable name="block" select="subsequence($lines, $j + 1, $end - $j - 1)"/>
    <xsl:variable name="n" select="($block[normalize-space(?raw) ne '']?ind)[1]"/>
    <xsl:variable name="texts" select="$block ! (if (normalize-space(?raw) eq '') then '' else substring(?raw, $n + 1))"/>
    <!-- Trailing empty lines belong to the chomping, not to the content. -->
    <xsl:variable name="last" select="(for $x in reverse(1 to count($texts)) return $x[$texts[$x] ne ''])[1]"/>
    <xsl:variable name="body" select="subsequence($texts, 1, ($last, 0)[1])"/>
    <xsl:variable name="trailing" select="count($texts) - ($last, 0)[1]"/>
    <xsl:variable name="joined" as="xs:string">
      <xsl:choose>
        <xsl:when test="starts-with($header, '|')">
          <xsl:sequence select="string-join($body, '&#10;')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="yx:fold($body)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="chomped" select="
        if (empty($body)) then ''
        else if (ends-with($header, '-')) then $joined
        else if (ends-with($header, '+')) then $joined || string-join((0 to $trailing) ! '&#10;', '')
        else $joined || '&#10;'"/>
    <xsl:sequence select="map { 'v': yx:string($chomped), 'i': $end }"/>
  </xsl:function>

  <!-- Folding: lines join with a space; an empty line gives a line break; a
       more-indented line keeps its line breaks. -->
  <xsl:function name="yx:fold" as="xs:string">
    <xsl:param name="texts" as="xs:string*"/>
    <xsl:sequence select="string-join(
        for $x in 1 to count($texts)
        let $t := $texts[$x]
        let $prev := $texts[$x - 1]
        return (
          if ($x eq 1) then ()
          else if ($t eq '' or $prev eq '' or starts-with($t, ' ') or starts-with($prev, ' ')) then
            (if ($t eq '' and $prev ne '' and not(starts-with($prev, ' '))) then () else '&#10;')
          else ' ',
          $t),
        '')"/>
  </xsl:function>

  <!-- ===== Scalars ===== -->

  <xsl:function name="yx:key" as="xs:string">
    <xsl:param name="txt" as="xs:string"/>
    <xsl:param name="l" as="map(*)"/>
    <xsl:sequence select="
        if (starts-with($txt, '&quot;')) then yx:unescape(replace($txt, $yx:key-re, '$2'), $l)
        else if (starts-with($txt, '''')) then replace(replace($txt, $yx:key-re, '$4'), '''''', '''')
        else replace(replace($txt, $yx:key-re, '$6'), '\s+$', '')"/>
  </xsl:function>

  <xsl:function name="yx:scalar" as="element()">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="l" as="map(*)"/>
    <xsl:variable name="t" select="normalize-space($s)"/>
    <xsl:choose>
      <xsl:when test="starts-with($s, '&quot;')">
        <xsl:if test="not(matches($s, '^&quot;([^&quot;\\]|\\.)*&quot;$'))">
          <xsl:sequence select="yx:fail('unsupported', $l, 'a quoted scalar must end on the same line')"/>
        </xsl:if>
        <xsl:sequence select="yx:string(yx:unescape(substring($s, 2, string-length($s) - 2), $l))"/>
      </xsl:when>
      <xsl:when test="starts-with($s, '''')">
        <xsl:if test="not(matches($s, '^''([^'']|'''')*''$'))">
          <xsl:sequence select="yx:fail('unsupported', $l, 'a quoted scalar must end on the same line')"/>
        </xsl:if>
        <xsl:sequence select="yx:string(replace(substring($s, 2, string-length($s) - 2), '''''', ''''))"/>
      </xsl:when>
      <xsl:when test="starts-with($s, '[') or starts-with($s, '{')">
        <xsl:variable name="r" select="yx:flow($s, 1, $l)"/>
        <xsl:if test="normalize-space(substring($s, $r?p)) ne ''">
          <xsl:sequence select="yx:fail('syntax', $l, 'text after the end of a flow collection')"/>
        </xsl:if>
        <xsl:sequence select="$r?v"/>
      </xsl:when>
      <xsl:when test="matches($s, '^([&amp;*!]|\?(\s|$))')">
        <xsl:sequence select="yx:fail('unsupported', $l, 'anchors, aliases, tags and complex keys')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="yx:plain($t)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- A plain scalar, resolved by the YAML 1.2 core schema. -->
  <xsl:function name="yx:plain" as="element()">
    <xsl:param name="t" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$t = ('', '~', 'null', 'Null', 'NULL')">
        <xsl:sequence select="yx:null()"/>
      </xsl:when>
      <xsl:when test="$t = ('true', 'True', 'TRUE', 'false', 'False', 'FALSE')">
        <fn:boolean><xsl:value-of select="lower-case($t)"/></fn:boolean>
      </xsl:when>
      <xsl:when test="matches($t, '^[-+]?[0-9]+$')">
        <fn:number><xsl:value-of select="xs:integer($t)"/></fn:number>
      </xsl:when>
      <xsl:when test="matches($t, '^0x[0-9a-fA-F]+$')">
        <fn:number><xsl:value-of select="yx:radix(substring($t, 3), 16)"/></fn:number>
      </xsl:when>
      <xsl:when test="matches($t, '^0o[0-7]+$')">
        <fn:number><xsl:value-of select="yx:radix(substring($t, 3), 8)"/></fn:number>
      </xsl:when>
      <xsl:when test="matches($t, '^[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$')">
        <fn:number><xsl:value-of select="xs:double($t)"/></fn:number>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="yx:string($t)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="yx:radix" as="xs:integer">
    <xsl:param name="digits" as="xs:string"/>
    <xsl:param name="base" as="xs:integer"/>
    <xsl:sequence select="fold-left(string-to-codepoints(lower-case($digits)), 0,
        function($a, $c) { $a * $base + (if ($c ge 97) then $c - 87 else $c - 48) })"/>
  </xsl:function>

  <xsl:function name="yx:unescape" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="l" as="map(*)"/>
    <xsl:variable name="parts" as="xs:string*">
      <xsl:analyze-string select="$s" regex="\\(u[0-9A-Fa-f]{{4}}|x[0-9A-Fa-f]{{2}}|.)">
        <xsl:matching-substring>
          <xsl:variable name="e" select="regex-group(1)"/>
          <xsl:sequence select="
              if (string-length($e) gt 1) then codepoints-to-string(yx:radix(substring($e, 2), 16))
              else if ($e eq 'n') then '&#10;'
              else if ($e eq 't') then '&#9;'
              else if ($e eq 'r') then '&#13;'
              else if ($e = ('&quot;', '\', '/', ' ')) then $e
              else yx:fail('unsupported', $l, 'the escape \' || $e)"/>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:sequence select="string(.)"/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:sequence select="string-join($parts, '')"/>
  </xsl:function>

  <!-- ===== Flow collections ([a, b] and {a: 1}) on one line ===== -->

  <xsl:function name="yx:flow" as="map(*)">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="p" as="xs:integer"/>
    <xsl:param name="l" as="map(*)"/>
    <xsl:variable name="q" select="yx:ws($s, $p)"/>
    <xsl:variable name="c" select="substring($s, $q, 1)"/>
    <xsl:choose>
      <xsl:when test="$c eq '['">
        <xsl:variable name="r" select="yx:flow-members($s, $q + 1, $l, false(), ())"/>
        <xsl:sequence select="map { 'v': yx:wrap(QName('http://www.w3.org/2005/xpath-functions', 'array'), $r?e), 'p': $r?p }"/>
      </xsl:when>
      <xsl:when test="$c eq '{'">
        <xsl:variable name="r" select="yx:flow-members($s, $q + 1, $l, true(), ())"/>
        <xsl:sequence select="map { 'v': yx:wrap(QName('http://www.w3.org/2005/xpath-functions', 'map'), $r?e), 'p': $r?p }"/>
      </xsl:when>
      <xsl:when test="$c = ('&quot;', '''')">
        <xsl:variable name="tok" select="yx:quoted-token($s, $q)"/>
        <xsl:sequence select="map { 'v': yx:scalar($tok, $l), 'p': $q + string-length($tok) }"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="tok" select="yx:prefix(substring($s, $q), '[^,\[\]{}]+')"/>
        <xsl:sequence select="map { 'v': yx:scalar(normalize-space($tok), $l), 'p': $q + string-length($tok) }"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="yx:flow-members" as="map(*)">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="p" as="xs:integer"/>
    <xsl:param name="l" as="map(*)"/>
    <xsl:param name="is-map" as="xs:boolean"/>
    <xsl:param name="done" as="element()*"/>
    <xsl:variable name="q" select="yx:ws($s, $p)"/>
    <xsl:variable name="close" select="if ($is-map) then '}' else ']'"/>
    <xsl:choose>
      <xsl:when test="substring($s, $q, 1) eq $close">
        <xsl:sequence select="map { 'e': $done, 'p': $q + 1 }"/>
      </xsl:when>
      <xsl:when test="$q gt string-length($s)">
        <xsl:sequence select="yx:fail('unsupported', $l, 'a flow collection must end on the same line')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="member" as="map(*)">
          <xsl:choose>
            <xsl:when test="$is-map">
              <xsl:variable name="key-tok" select="
                  if (substring($s, $q, 1) = ('&quot;', '''')) then yx:quoted-token($s, $q)
                  else yx:prefix(substring($s, $q), '[^,\[\]{}:]+')"/>
              <xsl:variable name="key" select="string(yx:scalar(normalize-space($key-tok), $l))"/>
              <xsl:variable name="after" select="yx:ws($s, $q + string-length($key-tok))"/>
              <xsl:choose>
                <xsl:when test="substring($s, $after, 1) ne ':'">
                  <xsl:sequence select="map { 'v': yx:keyed(yx:null(), $key), 'p': $after }"/>
                </xsl:when>
                <xsl:when test="substring($s, yx:ws($s, $after + 1), 1) = (',', '}')">
                  <xsl:sequence select="map { 'v': yx:keyed(yx:null(), $key), 'p': yx:ws($s, $after + 1) }"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:variable name="r" select="yx:flow($s, $after + 1, $l)"/>
                  <xsl:sequence select="map { 'v': yx:keyed($r?v, $key), 'p': $r?p }"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
              <xsl:sequence select="yx:flow($s, $q, $l)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="next" select="yx:ws($s, $member?p)"/>
        <xsl:variable name="c" select="substring($s, $next, 1)"/>
        <xsl:choose>
          <xsl:when test="$next gt string-length($s)">
            <xsl:sequence select="yx:fail('unsupported', $l, 'a flow collection must end on the same line')"/>
          </xsl:when>
          <xsl:when test="$c eq ','">
            <xsl:sequence select="yx:flow-members($s, $next + 1, $l, $is-map, ($done, $member?v))"/>
          </xsl:when>
          <xsl:when test="$c eq $close">
            <xsl:sequence select="map { 'e': ($done, $member?v), 'p': $next + 1 }"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="yx:fail('syntax', $l, 'expected &quot;,&quot; or &quot;' || $close || '&quot; in a flow collection')"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="yx:quoted-token" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="p" as="xs:integer"/>
    <xsl:sequence select="replace(substring($s, $p),
        '^(&quot;([^&quot;\\]|\\.)*&quot;|''([^'']|'''')*'').*$', '$1')"/>
  </xsl:function>

  <!-- The longest prefix of $s that matches $re, or "". -->
  <xsl:function name="yx:prefix" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="re" as="xs:string"/>
    <xsl:sequence select="if (matches($s, '^' || $re)) then replace($s, '^(' || $re || ').*$', '$1', 's') else ''"/>
  </xsl:function>

  <xsl:function name="yx:ws" as="xs:integer">
    <xsl:param name="s" as="xs:string"/>
    <xsl:param name="p" as="xs:integer"/>
    <xsl:variable name="tail" select="substring($s, $p)"/>
    <xsl:sequence select="$p + string-length($tail) - string-length(replace($tail, '^\s+', ''))"/>
  </xsl:function>

  <!-- ===== Construction and errors ===== -->

  <xsl:function name="yx:wrap" as="element()">
    <xsl:param name="name" as="xs:QName"/>
    <xsl:param name="content" as="element()*"/>
    <xsl:element name="{ local-name-from-QName($name) }" namespace="http://www.w3.org/2005/xpath-functions">
      <xsl:sequence select="$content"/>
    </xsl:element>
  </xsl:function>

  <xsl:function name="yx:keyed" as="element()">
    <xsl:param name="v" as="element()"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:element name="{ local-name($v) }" namespace="http://www.w3.org/2005/xpath-functions">
      <xsl:attribute name="key" select="$key"/>
      <xsl:sequence select="$v/node()"/>
    </xsl:element>
  </xsl:function>

  <xsl:function name="yx:string" as="element()">
    <xsl:param name="s" as="xs:string"/>
    <fn:string><xsl:value-of select="$s"/></fn:string>
  </xsl:function>

  <xsl:function name="yx:null" as="element()">
    <fn:null/>
  </xsl:function>

  <xsl:function name="yx:fail" as="item()*">
    <xsl:param name="kind" as="xs:string"/>
    <xsl:param name="l" as="map(*)?"/>
    <xsl:param name="message" as="xs:string"/>
    <xsl:sequence select="error(QName('https://phoenixml.dev/modules/xslt/yaml', 'yx:' || $kind),
        'YAML line ' || $l?n || ': ' || $message || '.')"/>
  </xsl:function>

</xsl:stylesheet>
