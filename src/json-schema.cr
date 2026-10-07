require "json"
require "uuid"
require "./json-schema/definitions"

module JSON
  module Schema
    # pass a `JSON::Schema::Definitions` as `refs` to have nested JSON::Serializable
    # types and enums emitted as `$ref`s, with their definitions collected in `refs`
    def json_schema(openapi : Bool? = nil, refs : R = nil) forall R
      {% begin %}
        {% refs = R == Nil ? nil : "refs".id %}
        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::JSON::Field) %}
          {% unless ann && (ann[:ignore] || ann[:ignore_deserialize]) %}
            {% properties[((ann && ann[:key]) || ivar).id] = {ivar.type.resolve, (ann && ann[:converter]), (ann && ann.named_args)} %}
          {% end %}
        {% end %}

        # OpenAPI requires at least one entry, so `required` is left out when it's empty
        {% required = [] of String %}
        {% for key, details in properties %}
          {% unless details[0].nilable? %}
            {% required << key.stringify %}
          {% end %}
        {% end %}

        {% if properties.empty? %}
          { type: "object" }
        {% else %}
          {type: "object",  properties: {
            {% for key, details in properties %}
              {% ivar = details[0] %}
              {% converter = details[1] %}
              {% args = details[2] %}
              {% key_str = key.stringify %}
              {% key = key_str.includes?('@') || key_str.includes?('-') || key_str.includes?(' ') || key_str.starts_with?('$') ? key_str : key %}
              {% if ivar < Enum && converter %}
                # we don't specify the type of the enum as we don't know what will be output
                # all we know is that it can be parsed as JSON
                {{key}}: { enum: [
                  {% for const in ivar.constants %}
                    JSON.parse({{converter.resolve}}.to_json({{ivar.name}}::{{const}}).as(String)),
                  {% end %}
                ]},
              {% else %}
                {{key}}: openapi ? ::JSON::Schema.introspect({{ivar.name}}, {{args}}, true, {{refs}}) : ::JSON::Schema.introspect({{ivar.name}}, {{args}}, nil, {{refs}}),
              {% end %}
            {% end %}
          }{% unless required.empty? %}, required: [
              {% for key in required %}
                {{key}},
              {% end %}
            ] of String{% end %}
          }
        {% end %}
      {% end %}
    end

    # `refs`, when provided, is an expression that evaluates to a `JSON::Schema::Definitions`
    macro introspect(klass, args = nil, openapi = nil, refs = nil)
      {% format_hint = (args && args[:format]) %}
      {% type_override = (args && args[:type]) %}
      {% pattern = (args && args[:pattern]) %}
      {% description = (args && args[:description]) %}

      {% arg_name = klass.stringify %}
      {% if !arg_name.starts_with?("Union") && arg_name.includes?("|") %}
        ::JSON::Schema.introspect(Union({{klass}}), {{args}}, {{openapi}}, {{refs}})
      {% else %}
        {% klass = klass.resolve %}
        {% klass_name = klass.name(generic_args: false) %}
        {% nillable = klass.nilable? %}
        {% referenced = refs && (klass < Enum || klass.ancestors.includes?(JSON::Serializable)) %}

        {% if klass <= Array || klass <= Set %}
          {% if klass.type_vars.size == 1 %}
            %has_items = ::JSON::Schema.introspect({{klass.type_vars[0]}}, nil, {{openapi}}, {{refs}})
            {type: "array"{% if description %}, description: {{description}}{% end %}, items: %has_items}
          {% else %}
            # handle inheritance (no access to type_var / unknown value)
            %klass = {{klass.ancestors[0]}}
            %klass.responds_to?(:json_schema) ? %klass.json_schema({{openapi}}) : { type: "array"{% if description %}, description: {{description}}{% end %} }
          {% end %}
        {% elsif klass.union? && !openapi.nil? && nillable && klass.union_types.size == 2 %}
          {% for type in klass.union_types %}
            {% if type.stringify != "Nil" %}
              {% if refs && (type < Enum || type.ancestors.includes?(JSON::Serializable)) %}
                {{refs}}.reference({{type}}, {{openapi}}, nullable: true, description: {{description}})
              {% else %}
                JSON.parse(::JSON::Schema.introspect({{type}}, {{args}}, {{openapi}}, {{refs}}).to_json[0..-2] + %(,"nullable":true}))
              {% end %}
            {% end %}
          {% end %}
        {% elsif klass.union? %}
          # OpenAPI 3.0 only applies nullable alongside a type, so each member is made nullable
          { anyOf: {
            {% for type in klass.union_types %}
              {% if openapi.nil? %}
                ::JSON::Schema.introspect({{type}}, nil, {{openapi}}, {{refs}}),
              {% elsif type.stringify != "Nil" %}
                ::JSON::Schema.introspect({{ nillable ? "Union(#{type}, Nil)".id : type }}, nil, {{openapi}}, {{refs}}),
              {% end %}
            {% end %}
          }{% if description %}, description: {{description}}{% end %} }
        {% elsif klass_name.starts_with? "Tuple(" %}
          {% if openapi.nil? %}
            %has_items = {
              {% for generic in klass.type_vars %}
                ::JSON::Schema.introspect({{generic}}, nil, {{openapi}}, {{refs}}),
              {% end %}
            }
            {type: "array"{% if description %}, description: {{description}}{% end %}, items: %has_items}
          {% else %}
            # OpenAPI 3.0 doesn't support positional items, any of the member types is allowed
            %has_items = ::JSON::Schema.introspect(Union({{klass.type_vars.splat}}), nil, {{openapi}}, {{refs}})
            {type: "array"{% if description %}, description: {{description}}{% end %}, items: %has_items, minItems: {{klass.type_vars.size}}, maxItems: {{klass.type_vars.size}}}
          {% end %}
        {% elsif klass_name.starts_with? "NamedTuple(" %}
          {% if klass.keys.empty? %}
            {type: "object"{% if description %}, description: {{description}}{% end %},  properties: {} of Symbol => Nil}
          {% else %}
            {% required = klass.keys.reject { |key| klass[key].resolve.nilable? }.map(&.id.stringify) %}
            {type: "object"{% if description %}, description: {{description}}{% end %},  properties: {
              {% for key in klass.keys %}
                {{key.id}}: ::JSON::Schema.introspect({{klass[key].resolve.name}}, nil, {{openapi}}, {{refs}}),
              {% end %}
            }{% unless required.empty? %}, required: [
                {% for key in required %}
                  {{key}},
                {% end %}
              ] of String{% end %}
            }
          {% end %}
        {% elsif referenced %}
          {{refs}}.reference({{klass}}, {{openapi}}, description: {{description}})
        {% elsif klass < Enum %}
          {type: "string",  enum: {{klass.constants.map(&.stringify.underscore)}}{% if description %}, description: {{description}}{% end %} }
        {% elsif klass <= String || klass <= Symbol %}
          {% min_length = (args && args[:min_length]) %}
          {% max_length = (args && args[:max_length]) %}
          { type: {{type_override || "string"}}{% if format_hint %}, format: {{format_hint}}{% end %}{% if pattern %}, pattern: {{pattern}}{% end %}{% if min_length %}, minLength: {{min_length}}{% end %}{% if max_length %}, maxLength: {{max_length}}{% end %}{% if description %}, description: {{description}}{% end %} }
        {% elsif klass <= Bool %}
          { type: {{type_override || "boolean"}}{% if format_hint %}, format: {{format_hint}}{% end %}{% if description %}, description: {{description}}{% end %} }
        {% elsif klass <= Int || klass <= Float %}
          {% multiple_of = (args && args[:multiple_of]) %}
          {% minimum = (args && args[:minimum]) %}
          {% exclusive_minimum = (args && args[:exclusive_minimum]) %}
          {% maximum = (args && args[:maximum]) %}
          {% exclusive_maximum = (args && args[:exclusive_maximum]) %}
          {% if klass <= Int %}
            { type: {{type_override || "integer"}}, format: {{format_hint || klass.stringify}}{% if multiple_of %}, multipleOf: {{multiple_of}}{% end %}{% if minimum %}, minimum: {{minimum}}{% end %}{% if exclusive_minimum %}, exclusiveMinimum: {{exclusive_minimum}}{% end %}{% if maximum %}, maximum: {{maximum}}{% end %}{% if exclusive_maximum %}, exclusiveMaximum: {{exclusive_maximum}}{% end %}{% if description %}, description: {{description}}{% end %} }
          {% elsif klass <= Float %}
            { type: {{type_override || "number"}}, format: {{format_hint || klass.stringify}}{% if multiple_of %}, multipleOf: {{multiple_of}}{% end %}{% if minimum %}, minimum: {{minimum}}{% end %}{% if exclusive_minimum %}, exclusiveMinimum: {{exclusive_minimum}}{% end %}{% if maximum %}, maximum: {{maximum}}{% end %}{% if exclusive_maximum %}, exclusiveMaximum: {{exclusive_maximum}}{% end %}{% if description %}, description: {{description}}{% end %} }
          {% end %}
        {% elsif klass <= Nil %}
          { type: {{type_override || "null"}}{% if description %}, description: {{description}}{% end %} }
        {% elsif klass <= Time %}
          { type: {{type_override || "string"}}, format: {{format_hint || "date-time"}}{% if pattern %}, pattern: {{pattern}}{% end %}{% if description %}, description: {{description}}{% end %} }
        {% elsif klass <= UUID %}
          { type: {{type_override || "string"}}, format: {{format_hint || "uuid"}}{% if pattern %}, pattern: {{pattern}}{% end %}{% if description %}, description: {{description}}{% end %} }
        {% elsif klass <= Hash %}
          {% if klass.type_vars.size == 2 %}
            { type: "object"{% if description %}, description: {{description}}{% end %}, additionalProperties: ::JSON::Schema.introspect({{klass.type_vars[1]}}, nil, {{openapi}}, {{refs}}) }
          {% else %}
            # As inheritance might include the type_vars it's hard to work them out
            %klass = {{klass.ancestors[0]}}
            %klass.responds_to?(:json_schema) ? %klass.json_schema({{openapi}}) : { type: "object"{% if description %}, description: {{description}}{% end %} }
          {% end %}
        {% elsif klass.ancestors.includes? JSON::Serializable %}
          %sch = {{klass}}.json_schema({{openapi}})
          {% if description %}
            { type: %sch[:type], description: {{description}}, properties: %sch[:properties], required: %sch[:required] }
          {% else %}
            %sch
          {% end %}
        {% else %}
          %klass = {{klass}}
          if %klass.responds_to?(:json_schema)
            %klass.json_schema({{openapi}})
          else
            # anything will validate (JSON::Any)
            { type: "object"{% if description %}, description: {{description}}{% end %} }
          end
        {% end %}
      {% end %}
    end
  end

  module Serializable
    macro included
      extend JSON::Schema
    end
  end
end

# Inject helper into other common klasses
{% begin %}
  {% structs = {Nil, Bool, Int, Float, Symbol, Set, Tuple, NamedTuple, Enum, Time, UUID} %}
  {% for klass in structs %}
    struct ::{{klass}}
      def self.json_schema(openapi : Bool? = nil, refs : R = nil) forall R
        \{% begin %}
          \{% refs = R == Nil || @type < ::Enum ? nil : "refs".id %}
          openapi ? ::JSON::Schema.introspect(\{{@type}}, nil, true, \{{refs}}) : ::JSON::Schema.introspect(\{{@type}}, nil, nil, \{{refs}})
        \{% end %}
      end
    end
  {% end %}

  {% klasses = {Array, String, Hash} %}
  {% for klass in klasses %}
    class ::{{klass}}
      def self.json_schema(openapi : Bool? = nil, refs : R = nil) forall R
        \{% begin %}
        \{% refs = R == Nil ? nil : "refs".id %}
        openapi ? ::JSON::Schema.introspect(\{{@type}}, nil, true, \{{refs}}) : ::JSON::Schema.introspect(\{{@type}}, nil, nil, \{{refs}})
        \{% end %}
      end
    end
  {% end %}
{% end %}
