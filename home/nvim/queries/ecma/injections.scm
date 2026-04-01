; Slonik style sql queries
; sql.unsafe`<sql>`, sql.fragment`<sql>`
(call_expression
  function: (member_expression
    object: (identifier) @injection.language 
    property: (property_identifier) @injection.method)
  arguments: [
    (arguments
      (template_string) @injection.content)
    (template_string) @injection.content
  ]
  (#eq? @injection.language "sql")
  (#any-of? @injection.method "unsafe" "fragment")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children))

; sql.typeAlias('void')`<sql>`
(call_expression
  function: (call_expression
    function: (member_expression
      object: (identifier) @injection.language
      property: (property_identifier) @_name)
      (#any-of? @_name "typeAlias" "type"))
  arguments: ((template_string) @injection.content
    (#offset! @injection.content 0 1 0 -1)
    (#set! injection.include-children)
    (#set! injection.language "sql")))
