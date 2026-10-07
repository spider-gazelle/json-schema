require "spec"
require "../src/json-schema"

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
