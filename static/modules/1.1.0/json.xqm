xquery version "3.1";

(:~
 : Helper functions for JSON in XQuery 3.1.
 :
 : A JSON object is a map and a JSON array is an array. The functions take the
 : parsed values, as json-doc() and parse-json() give them.
 :
 : Relative paths: a relative path in a library module resolves against the
 : module's own location, not against your query. Give pj:load your base URI:
 :   pj:load(("data/a.json", "data/b.json"), static-base-uri())
 :
 : Licensed under the Apache License, Version 2.0.
 :)
module namespace pj = "https://phoenixml.dev/modules/json";

declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
declare namespace array = "http://www.w3.org/2005/xpath-functions/array";

(:~
 : Parses each JSON file. Each URI must be absolute.
 : @error pj:relative-uri for a relative URI.
 :)
declare function pj:load($uris as xs:string*) as item()* {
  for $u in $uris
  return
    if (matches($u, '^[A-Za-z][A-Za-z0-9+.\-]*:'))
    then json-doc($u)
    else error(xs:QName('pj:relative-uri'),
      'pj:load: "' || $u || '" is relative. Use pj:load($paths, static-base-uri()).')
};

(:~
 : Parses each JSON file. Each path is resolved against $base, normally
 : static-base-uri() of the calling query.
 :)
declare function pj:load($paths as xs:string*, $base as xs:string?) as item()* {
  for $p in $paths
  return json-doc(resolve-uri($p, $base))
};

(:~
 : Selects values with a dotted path. A step is a map key, "*" (all members of
 : an array or all values of a map), or a number (an array position, from 1).
 : Example: pj:select($order, "items.*.name")
 :)
declare function pj:select($json as item()*, $path as xs:string) as item()* {
  fold-left(tokenize($path, '\.')[. ne ''], $json, function($items, $step) {
    for $i in $items
    return
      if ($step eq '*') then
        typeswitch ($i)
          case array(*) return $i?*
          case map(*) return $i?*
          default return ()
      else if ($i instance of array(*)) then
        if ($step castable as xs:integer
            and xs:integer($step) ge 1
            and xs:integer($step) le array:size($i))
        then $i(xs:integer($step))
        else ()
      else if ($i instance of map(*)) then $i($step)
      else ()
  })
};

(:~
 : All members of the arrays in $json, with nested arrays flattened.
 : A value that is not an array is returned as it is.
 :)
declare function pj:records($json as item()*) as item()* {
  for $i in $json
  return
    if ($i instance of array(*)) then pj:records($i?*) else $i
};

(:~
 : Groups records by the string value of one field. The result maps each key to
 : an array of the records with that key. A missing field gives the key "".
 :)
declare function pj:group-by($records as map(*)*, $key as xs:string) as map(*) {
  map:merge(
    for $r in $records
    let $k := string(($r($key))[1])
    group by $k
    return map:entry($k, array { $r })
  )
};

(:~
 : CSV text: a header row with $fields, then one row for each record.
 : A value with a comma, a quote or a line break is quoted. A map or an array
 : value is written as JSON.
 :)
declare function pj:to-csv($records as map(*)*, $fields as xs:string*) as xs:string {
  string-join((
    string-join($fields ! pj:csv-field(.), ','),
    for $r in $records
    return string-join(
      for $f in $fields return pj:csv-field(pj:csv-value($r($f))), ',')
  ), '&#10;')
};

(:~ The JSON value as the W3C XML representation (fn:json-to-xml). :)
declare function pj:to-xml($json as item()?) as document-node() {
  json-to-xml(serialize($json, map { 'method': 'json' }))
};

(:~
 : All values of the field $key at any depth: in maps, in arrays, and in maps
 : inside arrays. Example: pj:find($order, "price")
 :)
declare function pj:find($json as item()*, $key as xs:string) as item()* {
  for $i in $json
  return
    typeswitch ($i)
      case map(*) return (
        $i($key),
        for $k in map:keys($i) return pj:find($i($k), $key))
      case array(*) return pj:find($i?*, $key)
      default return ()
};

(:~
 : A map from each dotted path to its value, for every value that is not a map
 : or an array. An array position is a step from 1.
 : Example: map { "items.1.name": "pen", "items.1.price": 2.5, ... }
 :)
declare function pj:flatten($json as item()?) as map(xs:string, item()*) {
  map:merge(pj:flatten-entries($json, ()))
};

(:~ Each record with only the fields in $fields. A missing field stays missing. :)
declare function pj:pick($records as map(*)*, $fields as xs:string*) as map(*)* {
  for $r in $records
  return map:merge(for $f in $fields where map:contains($r, $f) return map:entry($f, $r($f)))
};

(:~
 : The records in order of the value of field $field, smallest first. Records
 : without the field come last. The values must be of one kind (all numbers, or
 : all strings).
 :)
declare function pj:sort-by($records as map(*)*, $field as xs:string) as map(*)* {
  pj:sort-by($records, $field, false())
};

(:~ The records in order of field $field; $descending true() gives largest first. :)
declare function pj:sort-by($records as map(*)*, $field as xs:string,
                            $descending as xs:boolean) as map(*)* {
  if ($descending)
  then for $r in $records order by data($r($field))[1] descending empty least return $r
  else for $r in $records order by data($r($field))[1] ascending empty greatest return $r
};

declare %private function pj:flatten-entries($v as item()*, $path as xs:string?) as map(*)* {
  typeswitch ($v)
    case map(*) return
      for $k in map:keys($v)
      return pj:flatten-entries($v($k), string-join(($path, $k), '.'))
    case array(*) return
      for $i in 1 to array:size($v)
      return pj:flatten-entries(array:get($v, $i), string-join(($path, string($i)), '.'))
    default return
      if (exists($path)) then map:entry($path, $v) else ()
};

declare %private function pj:csv-value($v as item()*) as xs:string {
  if (empty($v)) then ''
  else if ($v instance of map(*) or $v instance of array(*))
  then serialize($v, map { 'method': 'json' })
  else string-join($v ! string(.), ' ')
};

declare %private function pj:csv-field($s as xs:string) as xs:string {
  if (matches($s, '[,"&#10;&#13;]'))
  then '"' || replace($s, '"', '""') || '"'
  else $s
};
