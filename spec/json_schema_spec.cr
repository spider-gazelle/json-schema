require "./spec_helper"

describe JSON::Schema do
  it "generates JSON schema for basic types" do
    String.json_schema.should eq({type: "string"})
    Int32.json_schema.should eq({type: "integer", format: "Int32"})
    Symbol.json_schema.should eq({type: "string"})
    Nil.json_schema.should eq({type: "null"})
    Float32.json_schema.should eq({type: "number", format: "Float32"})

    Time.json_schema.should eq({type: "string", format: "date-time"})
    UUID.json_schema.should eq({type: "string", format: "uuid"})

    TestEnum.json_schema.should eq({type: "string", enum: ["option1", "option2"]})
    Hash(String, Int32 | Float32).json_schema.should eq({type: "object", additionalProperties: {anyOf: [{type: "number", format: "Float32"}, {type: "integer", format: "Int32"}]}})

    TestGenericInheritance.json_schema.should eq({type: "object", additionalProperties: {type: "integer", format: "Int32"}})

    Array(Int32).json_schema.should eq({type: "array", items: {type: "integer", format: "Int32"}})
    SuperArray.json_schema.should eq({type: "array", items: {type: "integer", format: "Int32"}})

    # empty named tuple
    NamedTuple.new.class.json_schema.should eq({type: "object", properties: {} of Symbol => Nil})

    Array(String | Int32).json_schema.should eq({
      type:  "array",
      items: {
        anyOf: [{type: "integer", format: "Int32"}, {type: "string"}],
      },
    })

    Set(String | Int32).json_schema.should eq({
      type:  "array",
      items: {
        anyOf: [{type: "integer", format: "Int32"}, {type: "string"}],
      },
    })
  end

  it "generates JSON schema for a simple example" do
    Example1.json_schema.should eq({
      type:       "object",
      properties: {
        options:  {type: "string", enum: ["option1", "option2"]},
        string:   {type: "string"},
        symbol:   {type: "string", format: "custom"},
        time:     {type: "integer", format: "Int64"},
        integer:  {type: "integer", format: "Int32", minimum: 0, maximum: 100},
        bool:     {type: "boolean"},
        null:     {type: "null"},
        optional: {anyOf: [{type: "integer", format: "Int64"}, {type: "null"}]},
        hash:     {type: "object", additionalProperties: {type: "string"}},
      },
      required: ["options", "string", "symbol", "time", "integer", "bool", "hash"],
    })
  end

  it "generates JSON schema for a complex example" do
    Example2.json_schema.should eq({
      type:       "object",
      properties: {
        sub_object: {
          type:       "object",
          properties: {
            options:  {type: "string", enum: ["option1", "option2"]},
            string:   {type: "string"},
            symbol:   {type: "string", format: "custom"},
            time:     {type: "integer", format: "Int64"},
            integer:  {type: "integer", format: "Int32", minimum: 0, maximum: 100},
            bool:     {type: "boolean"},
            null:     {type: "null"},
            optional: {anyOf: [{type: "integer", format: "Int64"}, {type: "null"}]},
            hash:     {type: "object", additionalProperties: {type: "string"}},
          },
          required: ["options", "string", "symbol", "time", "integer", "bool", "hash"],
        },
        array:       {type: "array", items: {anyOf: [{type: "integer", format: "Int32"}, {type: "string"}]}},
        tuple:       {type: "array", items: [{type: "string"}, {type: "integer", format: "Int32"}, {type: "number", format: "Float64"}]},
        named_tuple: {type: "object", properties: {test: {type: "string"}, other: {type: "integer", format: "Int64"}}, required: ["test", "other"]},
        union_type:  {anyOf: [{type: "boolean"}, {type: "integer", format: "Int64"}, {type: "string"}]},
      },
      required: ["sub_object", "array", "tuple", "named_tuple", "union_type"],
    })
  end
end
