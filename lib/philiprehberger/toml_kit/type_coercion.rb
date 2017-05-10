# frozen_string_literal: true

module Philiprehberger
  module TomlKit
    # Registry for custom type serialization and deserialization hooks.
    #
    # Allows registering custom handlers for Ruby types that are not natively
    # supported by TOML. Coercions are applied during dump (serialize) and
    # can be applied after parse (deserialize).
    class TypeCoercion
      # A single coercion rule.
      Rule = Struct.new(:type, :serializer, :deserializer, :tag, keyword_init: true)

      def initialize
        @rules = []
      end

      # Register a custom type coercion.
      #
      # @param type [Class] the Ruby class to handle
      # @param tag [String, nil] optional tag prefix for round-trip identification
      # @param serializer [Proc] converts an instance to a TOML-native value
      # @param deserializer [Proc, nil] converts a TOML-native value back to the Ruby type
      # @return [self]
      def register(type, serializer:, tag: nil, deserializer: nil)
        @rules << Rule.new(type: type, serializer: serializer, deserializer: deserializer, tag: tag)
        self
      end

      # Apply serialization coercions to a value (for dump).
      # Walks hashes and arrays recursively.
      #
      # @param value [Object]
      # @return [Object] coerced value
      def coerce_for_serialize(value)
        rule = find_rule(value)
        if rule
          result = rule.serializer.call(value)
          if rule.tag
            "__coerced:#{rule.tag}:#{result}"
          else
            result
          end
        elsif value.is_a?(Hash)
          value.transform_values { |v| coerce_for_serialize(v) }
        elsif value.is_a?(Array)
          value.map { |v| coerce_for_serialize(v) }
        else
          value
        end
      end

      # Apply deserialization coercions to a value (after parse).
      # Walks hashes and arrays recursively looking for tagged strings.
      #
      # @param value [Object]
      # @return [Object] coerced value
      def coerce_for_deserialize(value)
        case value
        when String
          if value.start_with?('__coerced:')
            parts = value.split(':', 3)
            tag = parts[1]
            raw = parts[2]
            rule = @rules.find { |r| r.tag == tag }
            if rule&.deserializer
              rule.deserializer.call(raw)
            else
              value
            end
          else
            value
          end
        when Hash
          value.transform_values { |v| coerce_for_deserialize(v) }
        when Array
          value.map { |v| coerce_for_deserialize(v) }
        else
          value
        end
      end

      # Check if there is a registered rule for the given value.
      #
      # @param value [Object]
      # @return [Boolean]
      def handles?(value)
        !find_rule(value).nil?
      end

      # Return all registered rules.
      #
      # @return [Array<Rule>]
      def rules
        @rules.dup
      end

      private

      def find_rule(value)
        @rules.find { |r| value.is_a?(r.type) }
      end
    end
  end
end
