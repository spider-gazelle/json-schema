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
    Hash(String, Int32 | Float32).json_schema.should eq({type: "object", additionalProperties: {anyOf: { {type: "number", format: "Float32"}, {type: "integer", format: "Int32"} }}})

    TestGenericInheritance.json_schema.should eq({type: "object", additionalProperties: {type: "integer", format: "Int32"}})

    Array(Int32).json_schema.should eq({type: "array", items: {type: "integer", format: "Int32"}})
    SuperArray.json_schema.should eq({type: "array", items: {type: "integer", format: "Int32"}})

    # empty named tuple
    NamedTuple.new.class.json_schema.should eq({type: "object", properties: {} of Symbol => Nil})

    Array(String | Int32).json_schema.should eq({
      type:  "array",
      items: {
        anyOf: { {type: "integer", format: "Int32"}, {type: "string"} },
      },
    })

    Set(String | Int32).json_schema.should eq({
      type:  "array",
      items: {
        anyOf: { {type: "integer", format: "Int32"}, {type: "string"} },
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
        optional: {anyOf: { {type: "integer", format: "Int64"}, {type: "null"} }},
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
            optional: {anyOf: { {type: "integer", format: "Int64"}, {type: "null"} }},
            hash:     {type: "object", additionalProperties: {type: "string"}},
          },
          required: ["options", "string", "symbol", "time", "integer", "bool", "hash"],
        },
        array:       {type: "array", items: {anyOf: { {type: "integer", format: "Int32"}, {type: "string"} }}},
        tuple:       {type: "array", prefixItems: { {type: "string"}, {type: "integer", format: "Int32"}, {type: "number", format: "Float64"} }, minItems: 3, maxItems: 3},
        named_tuple: {type: "object", properties: {test: {type: "string"}, other: {type: "integer", format: "Int64"}}, required: ["test", "other"]},
        union_type:  {anyOf: { {type: "boolean"}, {type: "integer", format: "Int64"}, {type: "string"} }, description: "a string an int or a bool"},
      },
      required: ["sub_object", "array", "tuple", "named_tuple", "union_type"],
    })
  end

  it "works with OpenAPI modifications" do
    ::JSON::Schema.introspect(Int32?, openapi: true).should eq({"type" => "integer", "format" => "Int32", "nullable" => true})
    # OpenAPI 3.0 only applies nullable alongside a type, so each member is nullable
    JSON.parse(::JSON::Schema.introspect((String | Int32?), openapi: true).to_json).should eq JSON.parse({
      "anyOf" => [
        {"type" => "integer", "format" => "Int32", "nullable" => true},
        {"type" => "string", "nullable" => true},
      ],
    }.to_json)
    ::JSON::Schema.introspect(Example1?, openapi: true).should eq({
      "type"       => "object",
      "properties" => {
        "options"  => {"type" => "string", "enum" => ["option1", "option2"]},
        "string"   => {"type" => "string"},
        "symbol"   => {"type" => "string", "format" => "custom"},
        "time"     => {"type" => "integer", "format" => "Int64"},
        "integer"  => {"type" => "integer", "format" => "Int32", "minimum" => 0, "maximum" => 100},
        "bool"     => {"type" => "boolean"},
        "null"     => {"type" => "null"},
        "optional" => {"type" => "integer", "format" => "Int64", "nullable" => true},
        "hash"     => {"type" => "object", "additionalProperties" => {"type" => "string"}},
      },
      "required" => ["options", "string", "symbol", "time", "integer", "bool", "hash"],
      "nullable" => true,
    })
  end

  it "includes description annotations on Hash and nested JSON::Serializable struct fields" do
    Example4.json_schema.should eq({
      type:       "object",
      properties: {
        sub: {
          type:        "object",
          description: "A nested configuration block",
          properties:  {
            options:  {type: "string", enum: ["option1", "option2"]},
            string:   {type: "string"},
            symbol:   {type: "string", format: "custom"},
            time:     {type: "integer", format: "Int64"},
            integer:  {type: "integer", format: "Int32", minimum: 0, maximum: 100},
            bool:     {type: "boolean"},
            null:     {type: "null"},
            optional: {anyOf: { {type: "integer", format: "Int64"}, {type: "null"} }},
            hash:     {type: "object", additionalProperties: {type: "string"}},
          },
          required: ["options", "string", "symbol", "time", "integer", "bool", "hash"],
        },
        categories: {
          type:                 "object",
          description:          "Mapping of category names to option lists",
          additionalProperties: {type: "array", items: {type: "string"}},
        },
      },
      required: ["sub", "categories"],
    })
  end

  it "generates JSON schema for complex example with some keys containing non-standard literals" do
    Example3.json_schema.should eq({
      type:       "object",
      properties: {
        "@odata.context":  {type: "string"},
        "@odata.count":    {type: "integer", format: "Int32"},
        "@odata.nextLink": {anyOf: { {type: "null"}, {type: "string"} }},
        hash:              {type: "object", additionalProperties: {type: "string"}},
      },
      required: ["@odata.context", "@odata.count", "hash"],
    })
  end

  describe JSON::Schema::Definitions do
    item_ref = {"$ref" => "#/components/schemas/RefItem"}
    item = {
      "type"       => "object",
      "properties" => {
        "content" => {"type" => "string"},
        "kind"    => {"$ref" => "#/components/schemas/TestEnum"},
      },
      "required" => ["content", "kind"],
    }

    it "references nested serializable types and enums" do
      refs = JSON::Schema::Definitions.new("#/components/schemas/")
      schema = JSON.parse(RefList.json_schema(true, refs).to_json)
      schema.should eq JSON.parse({
        "type"       => "object",
        "properties" => {
          "items"    => {"type" => "array", "items" => item_ref},
          "primary"  => {"allOf" => [item_ref], "type" => "object", "nullable" => true},
          "featured" => {"allOf" => [item_ref], "description" => "the featured item"},
          "other"    => {"$ref" => "#/components/schemas/OtherEnum"},
          "lookup"   => {"type" => "object", "additionalProperties" => item_ref},
        },
        "required" => ["items", "featured", "other", "lookup"],
      }.to_json)

      refs.resolve.should eq JSON.parse({
        "RefItem"   => item,
        "OtherEnum" => {"type" => "string", "enum" => ["option1", "option2"]},
        "TestEnum"  => {"type" => "string", "enum" => ["option1", "option2"]},
      }.to_json).as_h
      refs.type_name("RefItem").should eq "RefItem"
      refs.name_for("OtherEnum").should eq "OtherEnum"
    end

    it "uses anyOf for nilable references outside of OpenAPI" do
      refs = JSON::Schema::Definitions.new
      schema = JSON.parse(RefList.json_schema(refs: refs).to_json)
      schema["properties"]["primary"].should eq JSON.parse({"anyOf" => [{"$ref" => "#/$defs/RefItem"}, {"type" => "null"}]}.to_json)
    end

    it "references the type arguments of generics" do
      refs = JSON::Schema::Definitions.new("#/components/schemas/")
      schema = ::JSON::Schema.introspect(RefPage(RefList), openapi: true, refs: refs)
      refs.reference?(schema).should be_true
      schema.should eq JSON.parse({"$ref" => "#/components/schemas/RefPage-oRefList-c"}.to_json)

      definitions = refs.resolve
      definitions.keys.sort!.should eq ["OtherEnum", "RefItem", "RefList", "RefPage-oRefList-c", "TestEnum"]
      definitions["RefPage-oRefList-c"]["properties"]["page"].should eq JSON.parse({"type" => "array", "items" => {"$ref" => "#/components/schemas/RefList"}}.to_json)
      refs.type_name("RefPage-oRefList-c").should eq "RefPage(RefList)"
    end

    it "supports self referencing types" do
      refs = JSON::Schema::Definitions.new
      tree_ref = {"$ref" => "#/$defs/RefTree"}
      ::JSON::Schema.introspect(Array(RefTree), refs: refs).should eq({type: "array", items: JSON.parse(tree_ref.to_json)})
      refs.resolve.should eq({"RefTree" => JSON.parse({
        "type"       => "object",
        "properties" => {
          "name"     => {"type" => "string"},
          "children" => {"type" => "array", "items" => tree_ref},
          "parent"   => {"anyOf" => [{"type" => "null"}, tree_ref]},
        },
        "required" => ["name", "children"],
      }.to_json)})
    end

    it "builds a definition once per type" do
      refs = JSON::Schema::Definitions.new
      ::JSON::Schema.introspect(Tuple(RefItem, RefItem?, Array(RefItem)), refs: refs)
      refs.resolve.keys.sort!.should eq ["RefItem", "TestEnum"]
    end

    it "names definitions so that distinct types never share a name" do
      JSON::Schema::Definitions.normalise("McpWidgets::Widget").should eq "McpWidgets.Widget"
      JSON::Schema::Definitions.normalise("Page(List)").should eq "Page-oList-c"
      JSON::Schema::Definitions.normalise("Pair(A::B, C)").should eq "Pair-oA.B-nC-c"
      JSON::Schema::Definitions.normalise("Pair(A, B::C)").should eq "Pair-oA-nB.C-c"
      JSON::Schema::Definitions.normalise("(Bool | Nil)").should eq "-oBool-pNil-c"
      JSON::Schema::Definitions.normalise("NamedTuple(a: Int32)").should eq "NamedTuple-oa-u00003A-u000020Int32-c"
      JSON::Schema::Definitions.normalise("Snake_Case").should eq "Snake_Case"

      refs = JSON::Schema::Definitions.new
      schema = JSON.parse(RefAmbiguous.json_schema(refs: refs).to_json)
      schema["properties"]["one"].should eq JSON.parse({"$ref" => "#/$defs/RefTagged-oRefA.RefB-nRefC-c"}.to_json)
      schema["properties"]["two"].should eq JSON.parse({"$ref" => "#/$defs/RefTagged-oRefA-nRefB.RefC-c"}.to_json)
      refs.resolve.size.should eq 2
    end

    it "raises when a custom namer gives two types the same name" do
      refs = JSON::Schema::Definitions.new { "Same" }
      expect_raises(ArgumentError, "JSON schema definition name 'Same' is used by both RefItem and OtherEnum") do
        RefList.json_schema(refs: refs)
      end
    end

    it "builds the definitions of types with their own json_schema from it" do
      refs = JSON::Schema::Definitions.new
      RefHolder.json_schema(true, refs).should eq({
        type:       "object",
        properties: {
          custom:   JSON.parse({"$ref" => "#/$defs/RefCustom"}.to_json),
          child:    JSON.parse({"$ref" => "#/$defs/RefCustomChild"}.to_json),
          optional: JSON.parse({"allOf" => [{"$ref" => "#/$defs/RefCustom"}], "type" => "string", "nullable" => true}.to_json),
        },
        required: ["custom", "child"],
      })
      refs.resolve.should eq JSON.parse({
        "RefCustom"      => {"type" => "string", "description" => "a custom schema"},
        "RefCustomChild" => {"type" => "integer"},
      }.to_json).as_h
    end

    it "inlines when no definitions are provided" do
      RefPage(RefItem).json_schema.should eq({
        type:       "object",
        properties: {
          page:  {type: "array", items: {type: "object", properties: {content: {type: "string"}, kind: {type: "string", enum: ["option1", "option2"]}}, required: ["content", "kind"]}},
          total: {type: "integer", format: "Int32"},
        },
        required: ["page", "total"],
      })
    end
  end

  describe "OpenAPI validity" do
    it "leaves out required when every property is optional" do
      AllOptional.json_schema.should eq({type: "object", properties: {name: {anyOf: { {type: "null"}, {type: "string"} }}, count: {anyOf: { {type: "integer", format: "Int32"}, {type: "null"} }}}})
      ::JSON::Schema.introspect(NamedTuple(a: String?), openapi: true).should eq({type: "object", properties: {a: {"type" => "string", "nullable" => true}}})
    end

    it "describes tuples with a single items schema in OpenAPI" do
      JSON.parse(::JSON::Schema.introspect(Tuple(String, Int32, String), openapi: true).to_json).should eq JSON.parse({
        "type"     => "array",
        "items"    => {"anyOf" => [{"type" => "integer", "format" => "Int32"}, {"type" => "string"}]},
        "minItems" => 3,
        "maxItems" => 3,
      }.to_json)
      JSON.parse(::JSON::Schema.introspect(Tuple(Float64, Float64), openapi: true).to_json).should eq JSON.parse({
        "type"     => "array",
        "items"    => {"type" => "number", "format" => "Float64"},
        "minItems" => 2,
        "maxItems" => 2,
      }.to_json)
      # JSON Schema 2020-12 is positional
      Tuple(String, Int32).json_schema.should eq({type: "array", prefixItems: { {type: "string"}, {type: "integer", format: "Int32"} }, minItems: 2, maxItems: 2})
    end

    it "makes each member of a nilable union nullable in OpenAPI" do
      refs = JSON::Schema::Definitions.new("#/components/schemas/")
      JSON.parse(OptionalUnionHolder.json_schema(true, refs).to_json)["properties"]["value"].should eq JSON.parse({
        "anyOf" => [
          {"allOf" => [{"$ref" => "#/components/schemas/RefItem"}], "type" => "object", "nullable" => true},
          {"type" => "string", "nullable" => true},
        ],
        "description" => "a ref, a string or nothing",
      }.to_json)
    end
  end

  describe "JSON Schema 2020-12" do
    it "places a description beside a reference" do
      refs = JSON::Schema::Definitions.new
      JSON.parse(RefList.json_schema(refs: refs).to_json)["properties"]["featured"].should eq JSON.parse({
        "$ref"        => "#/$defs/RefItem",
        "description" => "the featured item",
      }.to_json)
    end

    it "uses numeric exclusive bounds, OpenAPI 3.0 uses booleans" do
      Bounded.json_schema.should eq({type: "object", properties: {value: {type: "integer", format: "Int32", exclusiveMinimum: 0, exclusiveMaximum: 10}}, required: ["value"]})
      Bounded.json_schema(true).should eq({type: "object", properties: {value: {type: "integer", format: "Int32", minimum: 0, exclusiveMinimum: true, maximum: 10, exclusiveMaximum: true}}, required: ["value"]})
    end
  end
end
