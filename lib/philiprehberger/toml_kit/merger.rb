# frozen_string_literal: true

module Philiprehberger
  module TomlKit
    class MergeConflictError < Error; end

    # Deep merge two TOML hashes with configurable conflict resolution.
    #
    # Strategies:
    #   - :override       -> right-side wins (default)
    #   - :keep_existing  -> left-side wins
    #   - :error_on_conflict -> raise MergeConflictError
    class Merger
      STRATEGIES = %i[override keep_existing error_on_conflict].freeze

      # Merge two hashes.
      #
      # @param left [Hash] base hash
      # @param right [Hash] hash to merge in
      # @param strategy [Symbol] conflict resolution strategy
      # @return [Hash] merged result
      # @raise [MergeConflictError] when strategy is :error_on_conflict and a conflict exists
      def self.merge(left, right, strategy: :override)
        new(strategy).merge(left, right)
      end

      # @param strategy [Symbol]
      def initialize(strategy = :override)
        unless STRATEGIES.include?(strategy)
          raise ArgumentError, "Unknown merge strategy: #{strategy}. Use one of: #{STRATEGIES.join(', ')}"
        end

        @strategy = strategy
      end

      # @param left [Hash]
      # @param right [Hash]
      # @param path [Array<String>] internal tracking for error messages
      # @return [Hash]
      def merge(left, right, path = [])
        result = left.dup

        right.each do |key, right_value|
          current_path = path + [key]

          if result.key?(key)
            left_value = result[key]

            result[key] = if left_value.is_a?(Hash) && right_value.is_a?(Hash)
                            merge(left_value, right_value, current_path)
                          else
                            resolve_conflict(left_value, right_value, current_path)
                          end
          else
            result[key] = deep_copy(right_value)
          end
        end

        result
      end

      private

      def resolve_conflict(left_value, right_value, path)
        case @strategy
        when :override
          deep_copy(right_value)
        when :keep_existing
          left_value
        when :error_on_conflict
          path_str = path.join('.')
          raise MergeConflictError, "Conflict at key: #{path_str}"
        end
      end

      def deep_copy(value)
        case value
        when Hash
          value.transform_values { |v| deep_copy(v) }
        when Array
          value.map { |v| deep_copy(v) }
        else
          value
        end
      end
    end
  end
end
