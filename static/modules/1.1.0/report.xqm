xquery version "3.1";

(:~
 : Small report helpers for query results: number statistics and a text table
 : for terminal output. They work with values from JSON and from XML.
 :
 : Licensed under the Apache License, Version 2.0.
 :)
module namespace pr = "https://phoenixml.dev/modules/report";

declare namespace map = "http://www.w3.org/2005/xpath-functions/map";

(:~
 : Statistics of the values that are numbers or can be cast to a number:
 : map { "count", "sum", "min", "max", "avg" }. Other values are not counted.
 : With no numbers, count is 0 and the other entries are empty.
 :)
declare function pr:stats($values as item()*) as map(xs:string, xs:anyAtomicType?) {
  let $n := for $v in data($values)
            return if ($v instance of xs:numeric) then $v
                   else if ($v castable as xs:double) then xs:double($v)
                   else ()
  return map {
    'count': count($n),
    'sum': if (exists($n)) then sum($n) else (),
    'min': min($n),
    'max': max($n),
    'avg': avg($n)
  }
};

(:~
 : A text table: a header row with $fields, a rule, then one row for each record.
 : Columns are padded to the widest value. A record is a map (from JSON or
 : px:to-json) or an element (a field is a child name or "@name").
 :)
declare function pr:table($records as item()*, $fields as xs:string*) as xs:string {
  let $rows := (
    array { $fields },
    for $r in $records
    return array {
      for $f in $fields
      return string-join(pr:value($r, $f) ! string(.), ' ')
    })
  let $widths := for $i in 1 to count($fields)
                 return max($rows ! string-length(.($i)))
  let $line := function($row as array(*)) as xs:string {
    replace(string-join(
      for $i in 1 to count($fields)
      return $row($i) || string-join((1 to $widths[$i] - string-length($row($i))) ! ' ', ''),
      '  '), '\s+$', '')
  }
  return string-join((
    $line(head($rows)),
    string-join($widths ! string-join((1 to .) ! '-', ''), '  '),
    tail($rows) ! $line(.)
  ), '&#10;')
};

declare %private function pr:value($r as item(), $f as xs:string) as item()* {
  typeswitch ($r)
    case map(*) return $r($f)
    case element() return
      if (starts-with($f, '@')) then $r/@*[local-name(.) eq substring($f, 2)]
      else $r/*[local-name(.) eq $f]
    default return ()
};
