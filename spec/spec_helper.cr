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
  getter symbol : Symbol
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
  getter union_type : String | Int64 | Bool
end

class TestGenericInheritance < Hash(String, Int32)
end
