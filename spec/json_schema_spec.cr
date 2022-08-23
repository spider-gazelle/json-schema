require "./spec_helper"

describe JSON::Schema do
  it "generates JSON schema for basic types" do
    String.json_schema.should eq({type: "string"})
    Int32.json_schema.should eq({type: "integer"})
    Symbol.json_schema.should eq({type: "string"})
    Nil.json_schema.should eq({type: "null"})
    Float32.json_schema.should eq({type: "number"})

    TestEnum.json_schema.should eq({type: "string", enum: ["option1", "option2"]})
    Hash(String, Int32 | Float32).json_schema.should eq({type: "object", additionalProperties: {anyOf: [{type: "number"}, {type: "integer"}]}})

    TestGenericInheritance.json_schema.should eq({type: "object", additionalProperties: {type: "integer"}})

    Array(String | Int32).json_schema.should eq({
      type:  "array",
      items: {
        anyOf: [{type: "integer"}, {type: "string"}],
      },
    })

    Set(String | Int32).json_schema.should eq({
      type:  "array",
      items: {
        anyOf: [{type: "integer"}, {type: "string"}],
      },
    })
  end

  it "generates JSON schema for a simple example" do
    Example1.json_schema.should eq({
      type:       "object",
      properties: {
        options:  {type: "string", enum: ["option1", "option2"]},
        string:   {type: "string"},
        symbol:   {type: "string"},
        integer:  {type: "integer"},
        bool:     {type: "boolean"},
        null:     {type: "null"},
        optional: {anyOf: [{type: "integer"}, {type: "null"}]},
        hash:     {type: "object", additionalProperties: {type: "string"}},
      },
      required: ["options", "string", "symbol", "integer", "bool", "hash"],
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
            symbol:   {type: "string"},
            integer:  {type: "integer"},
            bool:     {type: "boolean"},
            null:     {type: "null"},
            optional: {anyOf: [{type: "integer"}, {type: "null"}]},
            hash:     {type: "object", additionalProperties: {type: "string"}},
          },
          required: ["options", "string", "symbol", "integer", "bool", "hash"],
        },
        array:       {type: "array", items: {anyOf: [{type: "integer"}, {type: "string"}]}},
        tuple:       {type: "array", items: [{type: "string"}, {type: "integer"}, {type: "number"}]},
        named_tuple: {type: "object", properties: {test: {type: "string"}, other: {type: "integer"}}, required: ["test", "other"]},
        union_type:  {anyOf: [{type: "boolean"}, {type: "integer"}, {type: "string"}]},
      },
      required: ["sub_object", "array", "tuple", "named_tuple", "union_type"],
    })
  end
end
