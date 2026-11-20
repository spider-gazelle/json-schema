require "spec"
require "uri/json"
require "../src/json-schema"

{% if Fiber.has_constant?(:ExecutionContext) %}
  if ENV.has_key?("CRYSTAL_WORKERS")
    Fiber::ExecutionContext.default.resize(Fiber::ExecutionContext.default_workers_count)
  end
{% end %}

enum TestEnum
  Option1
  Option2
end

class Example1
  include JSON::Serializable

  getter options : TestEnum
  getter string : String
  @[JSON::Field(format: "custom")]
  getter symbol : Symbol
  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  getter time : Time
  @[JSON::Field(minimum: 0, maximum: 100)]
  getter integer : Int32
  getter? bool : Bool
  getter null : Nil
  getter optional : Int64?
  getter hash : Hash(Symbol, String)
end

class Example2
  include JSON::Serializable

  getter sub_object : Example1
  getter array : Array(String | Int32)
  getter tuple : Tuple(String, Int32, Float64)
  getter named_tuple : NamedTuple(test: String, other: Int64)

  @[JSON::Field(description: "a string an int or a bool")]
  getter union_type : String | Int64 | Bool
end

class TestGenericInheritance < Hash(String, Int32)
end

class SuperArray < Array(Int32)
end

class Example3
  include JSON::Serializable
  @[JSON::Field(key: "@odata.context")]
  getter context : String

  @[JSON::Field(key: "@odata.count")]
  getter count : Int32

  @[JSON::Field(key: "@odata.nextLink")]
  getter next_link : String?

  getter hash : Hash(Symbol, String)
end

class Example4
  include JSON::Serializable

  @[JSON::Field(description: "A nested configuration block")]
  getter sub : Example1

  @[JSON::Field(description: "Mapping of category names to option lists")]
  getter categories : Hash(String, Array(String))
end

enum OtherEnum
  Option1
  Option2
end

struct RefItem
  include JSON::Serializable
  getter content : String
  getter kind : TestEnum
end

module Elsewhere
  module JSON
  end

  struct Thing
    include ::JSON::Serializable

    getter name : String
    getter item : RefItem?
  end
end

struct RefList
  include JSON::Serializable
  getter items : Array(RefItem)
  getter primary : RefItem?
  @[JSON::Field(description: "the featured item")]
  getter featured : RefItem
  getter other : OtherEnum
  getter lookup : Hash(String, RefItem)
end

struct RefPage(T)
  include JSON::Serializable
  getter page : Array(T)
  getter total : Int32
end

class RefTree
  include JSON::Serializable
  getter name : String
  getter children : Array(RefTree)
  getter parent : RefTree?
end

struct RefCustom
  include JSON::Serializable
  getter value : String

  def self.json_schema(openapi : Bool? = nil)
    {type: "string", description: "a custom schema"}
  end
end

abstract struct RefCustomBase
  include JSON::Serializable

  def self.json_schema(openapi : Bool? = nil)
    {type: "integer"}
  end
end

struct RefCustomChild < RefCustomBase
end

struct RefHolder
  include JSON::Serializable
  getter custom : RefCustom
  getter child : RefCustomChild
  getter optional : RefCustom?
end

# only the type names matter, `RefTagged(RefA::RefB, RefC)` vs `RefTagged(RefA, RefB::RefC)`
module RefA
  module RefB
  end
end

module RefB
  module RefC
  end
end

module RefC
end

struct RefTagged(T, U)
  include JSON::Serializable
  getter value : Int32
end

struct RefAmbiguous
  include JSON::Serializable
  getter one : RefTagged(RefA::RefB, RefC)
  getter two : RefTagged(RefA, RefB::RefC)
end

struct AllOptional
  include JSON::Serializable
  getter name : String?
  getter count : Int32?
end

struct OptionalUnionHolder
  include JSON::Serializable
  @[JSON::Field(description: "a ref, a string or nothing")]
  getter value : RefItem | String | Nil
end

struct Bounded
  include JSON::Serializable
  @[JSON::Field(exclusive_minimum: 0, exclusive_maximum: 10)]
  getter value : Int32
end

struct OptionalTimes
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64", description: "Unix seconds")]
  getter epoch : Time?
  @[JSON::Field(description: "An RFC 3339 timestamp")]
  getter timestamp : Time?
end

struct DirectionalFields
  include JSON::Serializable

  getter input : String

  @[JSON::Field(key: "total", ignore_deserialize: true)]
  getter count : Int32 = 7

  @[JSON::Field(ignore_deserialize: true)]
  getter related : RefItem = RefItem.from_json(%({"content":"item","kind":"option1"}))

  @[JSON::Field(ignore_deserialize: true, ignore_serialize: true)]
  getter internal : String = "internal"

  @[JSON::Field(ignore: true)]
  getter ignored : String = "ignored"

  @[JSON::Field(key: "items", ignore_serialize: true)]
  getter input_items : Array(String)?

  @[JSON::Field(key: "items", ignore_deserialize: true)]
  getter output_items : Array(Int32)? = [1, 2, 3]
end

struct SerializedValues
  include JSON::Serializable

  getter value : JSON::Any
  getter payload : JSON::Any?
  @[JSON::Field(type: "string", format: "uri-reference")]
  getter location : JSON::Any?
  getter timezone : Time::Location?
  getter uri : URI
end

enum SerializedEnum
  Default =  0
  Custom  = 99
end

module BuilderEnumConverter
  def self.from_json(json : JSON::PullParser) : SerializedEnum
    SerializedEnum.parse(json.read_string.sub(/^wire_/, ""))
  end

  def self.to_json(value : SerializedEnum, json : JSON::Builder)
    json.string("wire_#{value.to_s.underscore}")
  end
end

struct ConvertedEnums
  include JSON::Serializable

  @[JSON::Field(converter: Enum::ValueConverter(SerializedEnum))]
  getter integer : SerializedEnum

  @[JSON::Field(converter: Enum::ValueConverter(SerializedEnum))]
  getter! optional_integer : SerializedEnum

  @[JSON::Field(converter: BuilderEnumConverter)]
  getter custom : SerializedEnum?

  getter standard : SerializedEnum
end
