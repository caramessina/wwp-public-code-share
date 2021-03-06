xquery version "3.0";

(:~
 : A library of XQuery functions for manipulating the tab-delimited text output of 
 : the counting robot (counting-robot.xq), using naive set theory.
 :
 : The main functions are:
 :
 :   * ctab:get-union-of-reports( ($filenameA, $filenameB, $ETC) )
 :     - the union of reports A through N in a sequence (including adding up the counts)
 :   * ctab:get-union-of-rows( ($rowA1, $rowB1, $ETC) )
 :     - the union of all rows in a sequence (including adding up the counts)
 :
 :   * ctab:get-intersection-of-reports( ($filenameA, $filenameB, $ETC) )
 :     - the intersection of reports A through N, or, only the data values which 
 :        occur once per report (including adding up the counts)
 :
 :   * ctab:get-set-difference-of-reports($filenameA, $filenameB)
 :     - all data values in report(s) A where there isn't a corresponding value in 
 :        report(s) B
 :     - both A and B can be a sequence of filenames rather than a single string; 
 :        the union of those sequences will be applied automatically
 :   * ctab:get-set-difference-of-rows( ($rowA1, $rowA2, $ETC), ($rowB1, $rowB2, $ETC) )
 :     - all data values in the sequence of rows A where there isn't a corresponding 
 :        value in sequence of rows B
 :
 : @author Ashley M. Clark, Northeastern University Women Writers Project
 : @version 1.1
 :
 :  2017-07-25: v1.1. Made ctab:join-rows() permissive of an empty sequence of rows 
 :    (a blank report).
 :  2017-06-30: v1.0. Added ctab:get-intersection-of-reports(), 
 :    ctab:create-row-match-pattern(), and this header.
 :  2017-05-05: Created.
 :)

(: NAMESPACES :)
module namespace ctab="http://www.wwp.northeastern.edu/ns/count-sets/functions";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";


(: VARIABLES :)
declare variable $ctab:tabChar      := '&#9;';
declare variable $ctab:newlineChar  := '&#13;';


(: FUNCTIONS :)

(:~ Given a number of string values, create a regular expression pattern to match 
  rows which contain those cell values. :)
declare function ctab:create-row-match-pattern($values as xs:string+) as xs:string {
  let $match := string-join($values,'|')
  return concat('\t(',$match,')(\t.*)?$')
};

(:~ From a string representing a tab-delimited row of data, get the 'cell' data at a 
  given column number. :)
declare function ctab:get-cell($row as xs:string, $column as xs:integer) as item()? {
  let $cells := tokenize($row, $ctab:tabChar)
  return $cells[$column]
};

(:~ Retrieve a tab-delimited text file and return its rows of data, split along 
  newlines. :)
declare function ctab:get-report-by-rows($filepath as xs:string) as xs:string* {
  if ( unparsed-text-available($filepath) ) then
    for $line in unparsed-text-lines($filepath)
    return
      (: Only output lines that include a tab. :)
      if ( matches($line,'\t') ) then
        $line
      else ()
  else () (: error :)
};

(:~ Return only the rows of data for which values appear in both fileset A and 
  fileset B. The counts are added up for each of these values.  :)
declare function ctab:get-intersection-of-reports($filenames as xs:string+) as xs:string* {
  let $countReports := count($filenames)
  let $allRows :=
    for $filename in $filenames
    return ctab:get-report-by-rows($filename)
  let $allValues :=
    for $row in $allRows
    return ctab:get-cell($row,2)
  let $distinctValues := distinct-values($allValues)
  let $intersectValues :=
    for $value in $distinctValues
    return
      (: We're only interested in the cell values which occur once per report. :)
      if ( count(index-of($allValues, $value)) eq $countReports ) then
        $value
      else ()
  let $regex := ctab:create-row-match-pattern($intersectValues)
  let $intersectRows := $allRows[matches(., $regex)]
  return ctab:get-union-of-rows($intersectRows)
};

(:~ Return rows of data from fileset A only if their corresponding values don't 
  appear in fileset B. If more than one filename is provided for a set, the union of 
  the files in that set is applied first. :)
declare function ctab:get-set-difference-of-reports($filenames as xs:string+, $filenames-for-excluded-data as xs:string+) as xs:string* {
  let $rows := 
    if ( count($filenames) gt 1 ) then
      ctab:get-union-of-reports($filenames)
    else ctab:get-report-by-rows($filenames)
  let $rowsExcluded :=
    if ( count($filenames-for-excluded-data) gt 1 ) then
      ctab:get-union-of-reports($filenames-for-excluded-data)
    else ctab:get-report-by-rows($filenames-for-excluded-data)
  return
    ctab:get-set-difference-of-rows($rows,$rowsExcluded)
};

(:~ Given two sequences of tab-delimited strings, return rows from sequence A only 
  if their corresponding values don't appear in sequence B. The union of rows is 
  applied first, for each sequence. :)
declare function ctab:get-set-difference-of-rows($tabbed-rows as xs:string+, $rows-with-excluded-data as xs:string+) as xs:string* {
  let $rowsWithTabs := ctab:get-union-of-rows($tabbed-rows)
  let $valuesExcluded :=
    let $rowsExcluded := ctab:get-union-of-rows($rows-with-excluded-data)
    return
      for $row in $rowsExcluded
      return ctab:get-cell($row,2)
  let $regex := ctab:create-row-match-pattern($valuesExcluded)
  return
    $rowsWithTabs[not(matches(.,$regex))]
};

(:~ Combine the counts for all values in N tab-delimited reports. :)
declare function ctab:get-union-of-reports($filenames as xs:string+) as xs:string* {
  let $dataRows :=
    for $filename in $filenames
    return ctab:get-report-by-rows($filename)
  return ctab:get-union-of-rows($dataRows)
};

(:~ Given a sequence of tab-delimited strings, combine the counts for all values. :)
declare function ctab:get-union-of-rows($tabbed-rows as xs:string+) as xs:string* {
  let $rowsWithTabs := $tabbed-rows[matches(.,'\t')]
  let $allValues := 
    for $row in $rowsWithTabs
    return ctab:get-cell($row,2)
  let $allDistinct := distinct-values($allValues)
  return
    for $value in $allDistinct
    let $regex := concat($ctab:tabChar, $value, '$')
    let $counts := 
      let $matches := $rowsWithTabs[matches(.,$regex)]
      return 
        for $match in $matches
        let $count := ctab:get-cell($match,1)
        return 
          if ( $count castable as xs:integer ) then 
            xs:integer( $count )
          else () (: error :)
    let $sum := if ( count( $counts ) ge 2 ) then 
                  sum( $counts )
                else $counts
    order by $sum descending, $value
    return concat($sum, $ctab:tabChar, $value)
};

(:~ Turn a sequence of strings into a single string by inserting newlines. :)
declare function ctab:join-rows($rows as xs:string*) as xs:string {
  if ( count($rows) gt 0 ) then
    string-join($rows, $ctab:newlineChar)
  else ''
};
