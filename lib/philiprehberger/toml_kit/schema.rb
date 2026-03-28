# frozen_string_literal: true

module Philiprehberger
  module TomlKit
    class SchemaError < Error; end

    # Validates a parsed TOML hash against a schema definition.
    #
    # Schema format:
    #   {
    #     "key" => { type: String, required: true },
    #     "port" => { type: Integer, required: false, default: 8080 },
    #     "database" => {
    #       type: Hash,
    #       properties: {
    #         "host" => { type: String, required: true },
    #         "port" => { type: Integer }
    #       }
    #     },
    #     "tags" => { type: Array, items: { type: String } }
    #   }
    class Schema
      attr_reader :properties

      # Build a new schema.
      #
      # @param properties [Hash] schema definition
      def initialize(properties)
        @properties = properties
      end

      # Validate a hash against this schema.
      #
      # @param data [Hash] parsed TOML data
      # @return [Array<String>] list of validation errors (empty if valid)
      def validate(data)
        errors = []
        validate_properties(data, @properties, [], errors)
        errors
      end

      # Validate and raise if invalid.
      #
      # @param data [Hash] parsed TOML data
      # @raise [SchemaError] if validation fails
      # @return [true]
      def validate!(data)
        errors = validate(data)
        raise SchemaError, "Schema validation failed: #{errors.join('; ')}" unless errors.empty?

        true
      end

      private

      def validate_properties(data, properties, path, errors)
        properties.each do |key, rules|
          full_path = (path + [key]).join('.')
          value = data.is_a?(Hash) ? data[key] : nil
          has_key = data.is_a?(Hash) && data.key?(key)

          if rules[:required] && !has_key
            errors << "Missing required key: #{full_path}"
            next
          end

          next unless has_key

          validate_value(value, rules, full_path, errors)
        end
      end

      def validate_value(value, rules, path, errors)
        expected_type = rules[:type]
        if expected_type && !type_matches?(value, expected_type)
          errors << "Type mismatch at #{path}: expected #{expected_type}, got #{value.class}"
          return
        end

        # Validate nested properties for Hash types
        if value.is_a?(Hash) && rules[:properties]
          validate_properties(value, rules[:properties], path.split('.'), errors)
        end

        # Validate array items
        return unless value.is_a?(Array) && rules[:items]

        value.each_with_index do |item, idx|
          item_path = "#{path}[#{idx}]"
          validate_value(item, rules[:items], item_path, errors)
        end
      end

      def type_matches?(value, expected)
        case expected
        when :boolean
          value.is_a?(TrueClass) || value.is_a?(FalseClass)
        else
          value.is_a?(expected)
        end
      end
    end
  end
end
