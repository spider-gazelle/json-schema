# JSON Schema

A crystal lang tool for converting JSON serialisable class definitions into the [JSON Schema](https://json-schema.org/) representation.

## Installation

```yaml
dependencies:
  json-schema:
    github: spider-gazelle/json-schema
```

## Usage

basic type support

```crystal

require "json-schema"

String.json_schema #=> {type: "string"}

Int32.json_schema #=> {type: "integer"}

Float32.json_schema #=> {type: "number"}

Array(String | Int32).json_schema #=> { type: "array", items: { anyOf: [{type: "integer"}, {type: "string"}] } }

# Works with enums
enum TestEnum
  Option1
  Option2
end

TestEnum.json_schema #=> {type: "string", enum: ["option1", "option2"]}

```

json serialisable support is included too, with deeply nested objects etc.

```crystal

require "json-schema"

class MyType
  include JSON::Serializable

  getter string : String
  getter symbol : Symbol?
  getter integer : Int32
  getter union_type : String | Int64 | Bool
end

MyType.json_schema

# outputs

{
  type: "object",
  properties: {
    string: {type: "string"},
    symbol: {type: "string"},
    integer: {type: "integer"},
    union_type: {anyOf: [{type: "boolean"}, {type: "integer"}, {type: "string"}]}
  },
  required: ["string", "integer", "union_type"]
}

```

for anything too confusing it falls back to a generic `{ type: "object" }` however this should only happen in some cases where you've inherited generic objects. e.g. `class Me < Hash(String, Int32)` (although this case is handled correctly)
