require "json"

module JSON
  module Schema
    def json_schema
      {% begin %}
        {% properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::JSON::Field) %}
          {% unless ann && (ann[:ignore] || ann[:ignore_deserialize]) %}
            {% properties[((ann && ann[:key]) || ivar).id] = {ivar.type.resolve, (ann && ann[:converter])} %}
          {% end %}
        {% end %}

        {% if properties.empty? %}
          { type: "object" }
        {% else %}
          {type: "object",  properties: {
            {% for key, details in properties %}
              {% ivar = details[0] %}
              {% converter = details[1] %}
              {% if ivar < Enum && converter %}
                # we don't specify the type of the enum as we don't know what will be output
                # all we know is that it can be parsed as JSON
                {{key}}: { enum: [
                  {% for const in ivar.constants %}
                    JSON.parse({{converter.resolve}}.to_json({{ivar.name}}::{{const}})),
                  {% end %}
                ]},
              {% else %}
                {{key}}: ::JSON::Schema.introspect({{ivar.name}}),
              {% end %}
            {% end %}
          },
            {% required = [] of String %}
            {% for key, details in properties %}
              {% ivar = details[0] %}
              {% unless ivar.nilable? %}
                {% required << key.stringify %}
              {% end %}
            {% end %}
            {% unless required.empty? %}
              required: [
              {% for key in required %}
                {{key}},
              {% end %}
              ]
            {% end %}
          }
        {% end %}
      {% end %}
    end

    macro introspect(klass)
      {% arg_name = klass.stringify %}
      {% if !arg_name.starts_with?("Union") && arg_name.includes?("|") %}
        ::JSON::Schema.introspect(Union({{klass}}))
      {% else %}
        {% klass = klass.resolve %}
        {% klass_name = klass.name(generic_args: false) %}

        {% if klass <= Array || klass <= Set %}
          {% if klass.type_vars.size == 1 %}
            %has_items = ::JSON::Schema.introspect({{klass.type_vars[0]}})
            {type: "array", items: %has_items}
          {% else %}
            # handle inheritance (no access to type_var / unknown value)
            %klass = {{klass.ancestors[0]}}
            %klass.responds_to?(:json_schema) ? %klass.json_schema : {type: "array"}
          {% end %}
        {% elsif klass.union? %}
          { anyOf: [
            {% for type in klass.union_types %}
              ::JSON::Schema.introspect({{type}}),
            {% end %}
          ]}
        {% elsif klass_name.starts_with? "Tuple(" %}
          %has_items = [
            {% for generic in klass.type_vars %}
              ::JSON::Schema.introspect({{generic}}),
            {% end %}
          ]
          {type: "array", items: %has_items}
        {% elsif klass_name.starts_with? "NamedTuple(" %}
          {% if klass.keys.empty? %}
            {type: "object",  properties: {} of Symbol => Nil}
          {% else %}
            {type: "object",  properties: {
              {% for key in klass.keys %}
                {{key.id}}: ::JSON::Schema.introspect({{klass[key].resolve.name}}),
              {% end %}
            },
              {% required = [] of String %}
              {% for key in klass.keys %}
                {% if !klass[key].resolve.nilable? %}
                  {% required << key.id.stringify %}
                {% end %}
              {% end %}
              {% if !required.empty? %}
                required: [
                {% for key in required %}
                  {{key}},
                {% end %}
                ]
              {% end %}
            }
          {% end %}
        {% elsif klass < Enum %}
          {type: "string",  enum: {{klass.constants.map(&.stringify.underscore)}} }
        {% elsif klass <= String || klass <= Symbol %}
          { type: "string" }
        {% elsif klass <= Bool %}
          { type: "boolean" }
        {% elsif klass <= Int %}
          { type: "integer" }
        {% elsif klass <= Float %}
          { type: "number" }
        {% elsif klass <= Nil %}
          { type: "null" }
        {% elsif klass <= Hash %}
          {% if klass.type_vars.size == 2 %}
            { type: "object", additionalProperties: ::JSON::Schema.introspect({{klass.type_vars[1]}}) }
          {% else %}
            # As inheritance might include the type_vars it's hard to work them out
            %klass = {{klass.ancestors[0]}}
            %klass.responds_to?(:json_schema) ? %klass.json_schema : { type: "object" }
          {% end %}
        {% elsif klass.ancestors.includes? JSON::Serializable %}
          {{klass}}.json_schema
        {% else %}
          %klass = {{klass}}
          if %klass.responds_to?(:json_schema)
            %klass.json_schema
          else
            # anything will validate (JSON::Any)
            { type: "object" }
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
  {% structs = {Nil, Bool, Int, Float, Symbol, Set, Tuple, NamedTuple, Enum} %}
  {% for klass in structs %}
    struct ::{{klass}}
      def self.json_schema
        \{% begin %}
          ::JSON::Schema.introspect(\{{@type}})
        \{% end %}
      end
    end
  {% end %}

  {% klasses = {Array, String, Hash} %}
  {% for klass in klasses %}
    class ::{{klass}}
      def self.json_schema
        \{% begin %}
          ::JSON::Schema.introspect(\{{@type}})
        \{% end %}
      end
    end
  {% end %}
{% end %}
