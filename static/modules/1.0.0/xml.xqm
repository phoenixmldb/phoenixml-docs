xquery version "3.1";

(:~
 : Helper functions for XML in XQuery 3.1.
 :
 : Relative paths: a relative path in a library module resolves against the
 : module's own location, not against your query. Give px:load your base URI:
 :   px:load(("a.xml", "b.xml"), static-base-uri())
 :
 : Licensed under the Apache License, Version 2.0.
 :)
module namespace px = "https://phoenixml.dev/modules/xml";

declare namespace map = "http://www.w3.org/2005/xpath-functions/map";

(:~
 : Loads each XML document. Each URI must be absolute.
 : @error px:relative-uri for a relative URI.
 :)
declare function px:load($uris as xs:string*) as document-node()* {
  for $u in $uris
  return
    if (matches($u, '^[A-Za-z][A-Za-z0-9+.\-]*:'))
    then doc($u)
    else error(xs:QName('px:relative-uri'),
      'px:load: "' || $u || '" is relative. Use px:load($paths, static-base-uri()).')
};

(:~
 : Loads each XML document. Each path is resolved against $base, normally
 : static-base-uri() of the calling query.
 :)
declare function px:load($paths as xs:string*, $base as xs:string?) as document-node()* {
  for $p in $paths
  return doc(resolve-uri($p, $base))
};

(:~
 : An element as a JSON-ready value.
 : - An element with no attributes and no child elements gives its string value.
 : - Otherwise a map: "@name" for each attribute, the local name for each child
 :   element (an array when the name occurs more than once), and "#text" for
 :   text that is not only whitespace.
 : Namespaces are not kept. Serialize with method "json".
 :)
declare function px:to-json($e as element()) as item() {
  if (empty($e/@*) and empty($e/*)) then string($e)
  else map:merge((
    for $a in $e/@*
    return map:entry('@' || local-name($a), string($a)),
    for $name in distinct-values($e/* ! local-name(.))
    let $children := $e/*[local-name(.) eq $name]
    return map:entry($name,
      if (count($children) gt 1)
      then array { $children ! px:to-json(.) }
      else px:to-json($children)),
    let $text := string-join($e/text(), '')
    where normalize-space($text) ne ''
    return map:entry('#text', $text)
  ))
};

(:~
 : CSV text: a header row with $fields, then one row for each element.
 : A field is a child element's local name, or "@name" for an attribute.
 : A value with a comma, a quote or a line break is quoted.
 :)
declare function px:to-csv($elements as element()*, $fields as xs:string*) as xs:string {
  string-join((
    string-join($fields ! px:csv-field(.), ','),
    for $e in $elements
    return string-join(
      for $f in $fields
      let $v :=
        if (starts-with($f, '@'))
        then $e/@*[local-name(.) eq substring($f, 2)]
        else $e/*[local-name(.) eq $f]
      return px:csv-field(string-join($v ! string(.), ' ')), ',')
  ), '&#10;')
};

(:~
 : A copy of the node with no namespaces: every element and attribute gets its
 : local name. Namespace declarations are not copied.
 :)
declare function px:strip-namespaces($n as node()) as node() {
  typeswitch ($n)
    case document-node() return document { $n/node() ! px:strip-namespaces(.) }
    case element() return
      element { local-name($n) } {
        for $a in $n/@* return attribute { local-name($a) } { string($a) },
        $n/node() ! px:strip-namespaces(.)
      }
    default return $n
};

(:~
 : A readable path to the node, for messages and debugging.
 : Example: /catalog/product[2]/@id
 :)
declare function px:path($n as node()) as xs:string {
  let $steps :=
    for $a in $n/ancestor-or-self::node()
    return typeswitch ($a)
      case document-node() return ()
      case element() return
        '/' || name($a) || '[' || (count($a/preceding-sibling::*[node-name(.) eq node-name($a)]) + 1) || ']'
      case attribute() return '/@' || name($a)
      case text() return '/text()[' || (count($a/preceding-sibling::text()) + 1) || ']'
      case comment() return '/comment()[' || (count($a/preceding-sibling::comment()) + 1) || ']'
      case processing-instruction() return
        '/processing-instruction(' || name($a) || ')[' ||
        (count($a/preceding-sibling::processing-instruction()[name(.) eq name($a)]) + 1) || ']'
      default return ()
  return if (empty($steps)) then '/' else string-join($steps, '')
};

(:~
 : Counts the items for each key. $key gives one key for an item; an item whose
 : key is empty is not counted. Example:
 :   px:count-by(//product, function($p) { string($p/@category) })
 :)
declare function px:count-by($items as item()*,
                             $key as function(item()) as xs:anyAtomicType?) as map(*) {
  map:merge(
    for $i in $items
    let $k := $key($i)
    where exists($k)
    group by $k
    return map:entry($k, count($i))
  )
};

declare %private function px:csv-field($s as xs:string) as xs:string {
  if (matches($s, '[,"&#10;&#13;]'))
  then '"' || replace($s, '"', '""') || '"'
  else $s
};
