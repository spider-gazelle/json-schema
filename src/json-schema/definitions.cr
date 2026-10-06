require "json"

module JSON::Schema
  # Collects the definitions of the types referenced while introspecting.
  #
  # Passing an instance as `refs` to `json_schema` or `JSON::Schema.introspect` emits
  # nested `JSON::Serializable` types and enums as `$ref`s, instead of inlining them,
  # and builds each referenced type's definition once:
  #
  # ```
  # refs = JSON::Schema::Definitions.new
  # MyType.json_schema(refs: refs) # nested types are {"$ref": "#/$defs/Nested"}
  # refs.resolve                   # => {"Nested" => {type: "object", ...}}
  # ```
  #
  # Types are named by type, never by shape, so two enums with the same members remain
  # distinct definitions.
  class Definitions
    # the `$ref` prefix, i.e. `#/components/schemas/` for an OpenAPI document
    getter prefix : String

    # definition name => definition
    getter schemas = {} of String => JSON::Any

    @namer : String -> String
    @names = {} of String => String
    @type_names = {} of String => String
    @pending = Deque(Tuple(String, Proc(JSON::Any))).new

    def initialize(@prefix : String = "#/$defs/", &namer : String -> String)
      @namer = namer
    end

    def self.new(prefix : String = "#/$defs/")
      new(prefix, &.gsub(/[^0-9a-zA-Z_]/, '_'))
    end

    # registers the type, returning a reference to its definition
    #
    # `nullable` and `description` are siblings of the `$ref`, which OpenAPI 3.0 ignores,
    # so the reference is wrapped in an `allOf` when they are provided
    def reference(klass : T.class, openapi : Bool? = nil, nullable : Bool = false, description : String? = nil) : JSON::Any forall T
      type_name = T.to_s
      unless name = @names[type_name]?
        name = @namer.call(type_name)
        if existing = @type_names[name]?
          raise ArgumentError.new("JSON schema definition name '#{name}' is used by both #{existing} and #{type_name}")
        end
        @names[type_name] = name
        @type_names[name] = type_name
        # built lazily so self referencing types don't recurse
        @pending << {name, -> { JSON.parse(definition(T, openapi).to_json) }}
      end

      ref = JSON::Any.new({"$ref" => JSON::Any.new("#{prefix}#{name}")})
      return ref unless nullable || description

      wrapped = {"allOf" => JSON::Any.new([ref])}
      wrapped["nullable"] = JSON::Any.new(true) if nullable
      wrapped["description"] = JSON::Any.new(description) if description
      JSON::Any.new(wrapped)
    end

    private def definition(klass : T.class, openapi : Bool?) forall T
      {% if ([T] + T.ancestors).any?(&.class.methods.any? { |method| method.name.stringify == "json_schema" && method.args.size == 1 }) %}
        # a type that describes itself, `self.json_schema(openapi)`
        T.json_schema(openapi)
      {% else %}
        T.json_schema(openapi, self)
      {% end %}
    end

    # builds the definitions of all the referenced types, returning `schemas`
    def resolve : Hash(String, JSON::Any)
      while entry = @pending.shift?
        name, build = entry
        @schemas[name] = build.call
      end
      @schemas
    end

    # the definition name of a referenced type
    def name_for(type_name : String) : String?
      @names[type_name]?
    end

    # the type name of a definition
    def type_name(name : String) : String?
      @type_names[name]?
    end

    # is the schema a bare `$ref` to one of these definitions
    def reference?(schema) : Bool
      return false unless schema.is_a?(JSON::Any)
      hash = schema.as_h?
      !!hash && hash.size == 1 && !!hash["$ref"]?.try(&.as_s?).try(&.starts_with?(prefix))
    end
  end
end
