# frozen_string_literal: true

require 'date'
require 'time'

module Philiprehberger
  module TomlKit
    # Converts a Ruby Hash into a TOML v1.0 formatted string.
    #
    # Type mapping:
    #   - String -> TOML basic string (with escapes)
    #   - Integer -> TOML integer
    #   - Float -> TOML float (handles inf, nan)
    #   - true/false -> TOML boolean
    #   - Time -> TOML offset or local date-time
    #   - Date -> TOML local date
    #   - Hash with :hour/:minute/:second -> TOML local time
    #   - Array -> TOML array (or array of tables if all elements are Hashes)
    #   - Hash -> TOML table
    class Serializer
      # @param hash [Hash] Ruby hash to serialize
      # @return [String] TOML formatted string
      def serialize(hash)
        lines = []
        serialize_table(hash, [], lines)
        lines.join("\n") << "\n"
      end

      private

      def serialize_table(hash, path, lines)
        # First pass: emit simple key/value pairs and inline structures
        simple_keys = []
        table_keys = []
        array_table_keys = []

        hash.each do |key, value|
          if value.is_a?(Hash) && !local_time_hash?(value)
            table_keys << key
          elsif value.is_a?(Array) && value.all?(Hash)
            array_table_keys << key
          else
            simple_keys << key
          end
        end

        simple_keys.each do |key|
          lines << "#{format_key(key)} = #{format_value(hash[key])}"
        end

        table_keys.each do |key|
          full_path = path + [key]
          lines << '' unless lines.empty?
          lines << "[#{full_path.map { |k| format_key(k) }.join('.')}]"
          serialize_table(hash[key], full_path, lines)
        end

        array_table_keys.each do |key|
          full_path = path + [key]
          hash[key].each do |element|
            lines << '' unless lines.empty?
            lines << "[[#{full_path.map { |k| format_key(k) }.join('.')}]]"
            serialize_table(element, full_path, lines)
          end
        end
      end

      def format_key(key)
        key = key.to_s
        if key.match?(/\A[A-Za-z0-9_-]+\z/)
          key
        else
          format_basic_string(key)
        end
      end

      def format_value(value)
        case value
        when String then format_basic_string(value)
        when Integer then value.to_s
        when Float then format_float(value)
        when true then 'true'
        when false then 'false'
        when Time then value.strftime('%Y-%m-%dT%H:%M:%S%:z')
        when Date then value.strftime('%Y-%m-%d')
        when Array then format_array(value)
        when Hash
          if local_time_hash?(value)
            format_local_time(value)
          else
            format_inline_table(value)
          end
        else
          format_basic_string(value.to_s)
        end
      end

      def format_basic_string(str)
        escaped = str.gsub('\\', '\\\\\\\\')
                     .gsub('"', '\\"')
                     .gsub("\b", '\\b')
                     .gsub("\t", '\\t')
                     .gsub("\n", '\\n')
                     .gsub("\f", '\\f')
                     .gsub("\r", '\\r')
        "\"#{escaped}\""
      end

      def format_float(value)
        if value.infinite? == 1
          'inf'
        elsif value.infinite? == -1
          '-inf'
        elsif value.nan?
          'nan'
        else
          # Ensure float always has a decimal point
          str = value.to_s
          str.include?('.') || str.include?('e') ? str : "#{str}.0"
        end
      end

      def format_array(arr)
        elements = arr.map { |v| format_value(v) }
        "[#{elements.join(', ')}]"
      end

      def format_inline_table(hash)
        pairs = hash.map { |k, v| "#{format_key(k)} = #{format_value(v)}" }
        "{#{pairs.join(', ')}}"
      end

      def format_local_time(hash)
        hour = hash[:hour].to_s.rjust(2, '0')
        minute = hash[:minute].to_s.rjust(2, '0')
        second = hash[:second].to_s.rjust(2, '0')
        nano = hash[:nanosecond] || 0
        if nano.positive?
          frac = nano.to_s.rjust(9, '0').sub(/0+\z/, '')
          "#{hour}:#{minute}:#{second}.#{frac}"
        else
          "#{hour}:#{minute}:#{second}"
        end
      end

      def local_time_hash?(hash)
        hash.key?(:hour) && hash.key?(:minute) && hash.key?(:second)
      end
    end
  end
end
