xquery version "3.1";

(:~
 : Helper functions for CSV in XQuery 3.1.
 :
 : The parser follows RFC 4180: a field in double quotes can hold the separator,
 : a line break, and a quote written as two quotes (""). Line breaks can be
 : CRLF, LF or CR. Blank lines are skipped. A leading byte order mark is removed.
 : All values are strings; cast them where you need numbers or dates.
 :
 : Relative paths: a relative path in a library module resolves against the
 : module's own location, not against your query. Give pc:load your base URI:
 :   pc:load("orders.csv", static-base-uri())
 :
 : Licensed under the Apache License, Version 2.0.
 :)
module namespace pc = "https://phoenixml.dev/modules/csv";

declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
declare namespace array = "http://www.w3.org/2005/xpath-functions/array";

(:~
 : The rows of CSV text, as one array of strings for each row. The separator is ",".
 : @error pc:malformed for a quote that does not close, or a quote inside an unquoted field.
 :)
declare function pc:rows($text as xs:string) as array(xs:string)* {
  pc:rows($text, ',')
};

(:~
 : The rows of CSV text with the given one-character separator, for example ";" or "&#9;".
 :)
declare function pc:rows($text as xs:string, $separator as xs:string) as array(xs:string)* {
  if (string-length($separator) ne 1 or matches($separator, '["\r\n]'))
  then error(xs:QName('pc:separator'),
    'pc:rows: the separator must be one character that is not a quote or a line break.')
  else
    let $sep := replace($separator, '([\\|.\-^$?*+(){}\[\]])', '\\$1')
    let $re := '"([^"]|"")*"|[^' || $sep || '"\r\n]+|' || $sep || '|\r\n|\n|\r'
    let $parts := analyze-string(replace($text, '^&#xFEFF;', ''), $re)
    return
      if (exists($parts/*:non-match))
      then error(xs:QName('pc:malformed'),
        'pc:rows: the text is not valid CSV near "' ||
        substring(($parts/*:non-match)[1], 1, 20) || '".')
      else
        for tumbling window $line in $parts/*:match/string()
          start when true()
          end $e when $e = ('&#13;&#10;', '&#10;', '&#13;')
        let $cells := $line[not(. = ('&#13;&#10;', '&#10;', '&#13;'))]
        where exists($cells)
        return array {
          for tumbling window $field in ($separator, $cells)
            start $s when $s eq $separator
          return pc:unquote(($field[2], '')[1])
        }
};

(:~
 : The records of CSV text with a header row: one map for each row, from each
 : header name to the value. A missing value is "". The separator is ",".
 : @error pc:extra-fields for a row with a non-empty value after the last header.
 :)
declare function pc:parse($text as xs:string) as map(xs:string, xs:string)* {
  pc:parse($text, ',')
};

(:~ The records of CSV text with a header row, with the given separator. :)
declare function pc:parse($text as xs:string, $separator as xs:string)
    as map(xs:string, xs:string)* {
  let $rows := pc:rows($text, $separator)
  let $header := head($rows)
  for $row at $n in tail($rows)
  return
    if (some $i in (array:size($header) + 1) to array:size($row) satisfies $row($i) ne '')
    then error(xs:QName('pc:extra-fields'),
      'pc:parse: row ' || $n + 1 || ' has more fields than the header.')
    else map:merge(
      for $i in 1 to array:size($header)
      return map:entry($header($i), if ($i le array:size($row)) then $row($i) else ''),
      map { 'duplicates': 'use-first' })
};

(:~ The header names of CSV text, in column order. Use them as $fields for pc:to-xml. :)
declare function pc:header($text as xs:string) as xs:string* {
  head(pc:rows($text))?*
};

(:~
 : Reads and parses each CSV file with a header row. Each URI must be absolute.
 : @error pc:relative-uri for a relative URI.
 :)
declare function pc:load($uris as xs:string*) as map(xs:string, xs:string)* {
  for $u in $uris
  return
    if (matches($u, '^[A-Za-z][A-Za-z0-9+.\-]*:'))
    then pc:parse(unparsed-text($u))
    else error(xs:QName('pc:relative-uri'),
      'pc:load: "' || $u || '" is relative. Use pc:load($paths, static-base-uri()).')
};

(:~ Reads and parses each CSV file with a header row. Paths resolve against $base. :)
declare function pc:load($paths as xs:string*, $base as xs:string?)
    as map(xs:string, xs:string)* {
  for $p in $paths
  return pc:parse(unparsed-text(resolve-uri($p, $base)))
};

(:~
 : Records as XML: a <csv> element with one <row> for each record, and one child
 : for each field in $fields, in that order. A field name that is not a valid XML
 : name gives <field name="...">.
 :)
declare function pc:to-xml($records as map(*)*, $fields as xs:string*) as element(csv) {
  <csv>{
    for $r in $records
    return <row>{
      for $f in $fields
      let $v := string-join($r($f) ! string(.), ' ')
      return
        if ($f castable as xs:NCName)
        then element { $f } { $v }
        else <field name="{ $f }">{ $v }</field>
    }</row>
  }</csv>
};

declare %private function pc:unquote($s as xs:string) as xs:string {
  if (starts-with($s, '"'))
  then replace(substring($s, 2, string-length($s) - 2), '""', '"')
  else $s
};
