# frozen_string_literal: true

module Philiprehberger
  module TomlKit
    # Compares two TOML documents (as hashes) and reports differences.
    #
    # Returns a structured diff with:
    #   - :added    -> keys present only in the right document
    #   - :removed  -> keys present only in the left document
    #   - :changed  -> keys present in both but with different values
    module Diff
      # A single change entry.
      Change = Struct.new(:path, :type, :left_value, :right_value, keyword_init: true)

      # Compare two parsed TOML hashes.
      #
      # @param left [Hash] first document
      # @param right [Hash] second document
      # @return [Array<Change>] list of differences
      def self.diff(left, right)
        changes = []
        compare(left, right, [], changes)
        changes
      end

      # Return only additions (keys in right but not left).
      #
      # @param left [Hash]
      # @param right [Hash]
      # @return [Array<Change>]
      def self.additions(left, right)
        diff(left, right).select { |c| c.type == :added }
      end

      # Return only removals (keys in left but not right).
      #
      # @param left [Hash]
      # @param right [Hash]
      # @return [Array<Change>]
      def self.removals(left, right)
        diff(left, right).select { |c| c.type == :removed }
      end

      # Return only changes (keys in both with different values).
      #
      # @param left [Hash]
      # @param right [Hash]
      # @return [Array<Change>]
      def self.changes(left, right)
        diff(left, right).select { |c| c.type == :changed }
      end

      # Check if two documents are identical.
      #
      # @param left [Hash]
      # @param right [Hash]
      # @return [Boolean]
      def self.identical?(left, right)
        diff(left, right).empty?
      end

      # @api private
      def self.compare(left, right, path, changes)
        all_keys = ((left.is_a?(Hash) ? left.keys : []) | (right.is_a?(Hash) ? right.keys : [])).uniq

        all_keys.each do |key|
          current_path = (path + [key]).join('.')
          left_has = left.is_a?(Hash) && left.key?(key)
          right_has = right.is_a?(Hash) && right.key?(key)

          if left_has && !right_has
            changes << Change.new(path: current_path, type: :removed, left_value: left[key], right_value: nil)
          elsif !left_has && right_has
            changes << Change.new(path: current_path, type: :added, left_value: nil, right_value: right[key])
          elsif left[key].is_a?(Hash) && right[key].is_a?(Hash)
            compare(left[key], right[key], path + [key], changes)
          elsif left[key] != right[key]
            # Handle NaN comparison (NaN != NaN is always true)
            next if left[key].is_a?(Float) && right[key].is_a?(Float) && left[key].nan? && right[key].nan?

            changes << Change.new(path: current_path, type: :changed, left_value: left[key],
                                  right_value: right[key])
          end
        end
      end

      private_class_method :compare
    end
  end
end
