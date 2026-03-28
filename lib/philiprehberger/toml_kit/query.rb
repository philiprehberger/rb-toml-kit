# frozen_string_literal: true

module Philiprehberger
  module TomlKit
    # Dot-path query access for nested TOML hashes.
    #
    # Supports:
    #   - Simple dot paths: "database.host"
    #   - Array indexing: "servers[0].name"
    #   - Deep nesting: "a.b.c.d"
    module Query
      # Retrieve a value from a nested hash using a dot-path.
      #
      # @param data [Hash] parsed TOML hash
      # @param path [String] dot-separated path (e.g., "database.host")
      # @param default [Object] value to return if the path does not exist
      # @return [Object] the value at the path, or default
      def self.get(data, path, default: nil)
        segments = parse_path(path)
        current = data

        segments.each do |segment|
          case segment
          when Integer
            return default unless current.is_a?(Array) && segment < current.length

            current = current[segment]
          when String
            return default unless current.is_a?(Hash) && current.key?(segment)

            current = current[segment]
          end
        end

        current
      end

      # Set a value in a nested hash using a dot-path.
      # Creates intermediate hashes/arrays as needed.
      #
      # @param data [Hash] target hash
      # @param path [String] dot-separated path
      # @param value [Object] value to set
      # @return [Object] the value that was set
      def self.set(data, path, value)
        segments = parse_path(path)
        current = data

        segments[0...-1].each_with_index do |segment, idx|
          next_segment = segments[idx + 1]

          case segment
          when Integer
            current[segment] = next_segment.is_a?(Integer) ? [] : {} unless current[segment]
            current = current[segment]
          when String
            current[segment] = next_segment.is_a?(Integer) ? [] : {} unless current.key?(segment)
            current = current[segment]
          end
        end

        current[segments.last] = value
        value
      end

      # Check whether a path exists in the data.
      #
      # @param data [Hash] parsed TOML hash
      # @param path [String] dot-separated path
      # @return [Boolean]
      def self.exists?(data, path)
        sentinel = Object.new
        get(data, path, default: sentinel) != sentinel
      end

      # Delete a value at the given path.
      #
      # @param data [Hash] target hash
      # @param path [String] dot-separated path
      # @return [Object, nil] the removed value, or nil
      def self.delete(data, path)
        segments = parse_path(path)
        return nil if segments.empty?

        parent = segments.length > 1 ? get(data, build_path(segments[0...-1])) : data
        return nil unless parent

        last = segments.last
        case last
        when Integer
          parent.is_a?(Array) ? parent.delete_at(last) : nil
        when String
          parent.is_a?(Hash) ? parent.delete(last) : nil
        end
      end

      # Parse a dot-path into segments.
      # Handles array indexing like "servers[0]".
      #
      # @param path [String]
      # @return [Array<String, Integer>]
      def self.parse_path(path)
        segments = []
        path.split('.').each do |part|
          if part =~ /\A(.+?)\[(\d+)\]\z/
            segments << ::Regexp.last_match(1)
            segments << ::Regexp.last_match(2).to_i
          else
            segments << part
          end
        end
        segments
      end

      # Build a dot-path from segments.
      #
      # @param segments [Array<String, Integer>]
      # @return [String]
      def self.build_path(segments)
        result = +''
        segments.each_with_index do |seg, i|
          if seg.is_a?(Integer)
            result << "[#{seg}]"
          else
            result << '.' if i.positive?
            result << seg
          end
        end
        result
      end

      private_class_method :parse_path, :build_path
    end
  end
end
