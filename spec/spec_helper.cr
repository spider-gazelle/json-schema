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
  getter bool : Bool
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
