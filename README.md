# JSON Schema [![CI](https://github.com/spider-gazelle/json-schema/actions/workflows/ci.yml/badge.svg)](https://github.com/spider-gazelle/json-schema/actions/workflows/ci.yml)

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

Int32.json_schema #=> {type: "integer", format: "Int32"}

Float32.json_schema #=> {type: "number", format: "Float32"}

Array(String | Int32).json_schema #=> { type: "array", items: { anyOf: [{type: "integer", format: "Int32"}, {type: "string"}] } }

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
  getter time : Time
  getter integer : Int32
  getter union_type : String | Int64 | Bool
end

MyType.json_schema

# outputs

{
  type: "object",
  properties: {
    string:     {type: "string"},
    symbol:     {type: "string"},
    time:       {type: "string", format: "date-time"},
    integer:    {type: "integer", format: "Int32"},
    union_type: {anyOf: [{type: "boolean"}, {type: "integer", format: "Int64"}, {type: "string"}]}
  },
  required: ["string", "time", "integer", "union_type"]
}

```

You can also customize schema output using the `@[JSON::Field]` annotation

```crystal

require "json-schema"

class MyType
  include JSON::Serializable

  # The `EpochConverter` here means the JSON value will actually be an integer
  # so to avoid the output being `type: "string", format: "date-time"` you can
  # supply a type override and custom format string.
  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  getter time : Time

  # or if you just want to provide a custom format
  @[JSON::Field(format: "email")]
  getter email : String
end

```

for anything too confusing it falls back to a generic `{ type: "object" }` however this should only happen in some cases where you've inherited generic objects. e.g. `class Me < Hash(String, Int32)` (although this case is handled correctly)
