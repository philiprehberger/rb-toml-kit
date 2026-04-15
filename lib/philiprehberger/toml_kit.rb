# frozen_string_literal: true

require_relative 'toml_kit/version'

module Philiprehberger
  module TomlKit
    class Error < StandardError; end
    class ParseError < Error; end
  end
end

require_relative 'toml_kit/parser'
require_relative 'toml_kit/serializer'
require_relative 'toml_kit/comment_document'
require_relative 'toml_kit/schema'
require_relative 'toml_kit/merger'
require_relative 'toml_kit/query'
require_relative 'toml_kit/type_coercion'
require_relative 'toml_kit/diff'

module Philiprehberger
  module TomlKit
    # Parse a TOML string into a Ruby Hash.
    #
    # @param string [String] TOML document
    # @return [Hash] parsed result
    # @raise [ParseError] if the input is not valid TOML
    def self.parse(string)
      Parser.new.parse(string)
    end

    # Check whether a string parses as valid TOML without raising.
    #
    # @param string [String] TOML document
    # @return [Boolean] true if the string is valid TOML
    def self.valid?(string)
      parse(string)
      true
    rescue ParseError
      false
    end

    # Parse a TOML file into a Ruby Hash.
    #
    # @param path [String] path to a TOML file
    # @return [Hash] parsed result
    # @raise [ParseError] if the file contents are not valid TOML
    # @raise [Errno::ENOENT] if the file does not exist
    def self.load(path)
      parse(File.read(path, encoding: 'utf-8'))
    end

    # Serialize a Ruby Hash into a TOML string.
    #
    # @param hash [Hash] data to serialize
    # @return [String] TOML formatted string
    def self.dump(hash)
      Serializer.new.serialize(hash)
    end

    # Write a Ruby Hash to a TOML file.
    #
    # @param hash [Hash] data to serialize
    # @param path [String] output file path
    # @return [void]
    def self.save(hash, path)
      File.write(path, dump(hash), encoding: 'utf-8')
    end

    # Parse a TOML string preserving comments for round-trip editing.
    #
    # @param string [String] TOML document
    # @return [CommentDocument] document with data and comments
    def self.parse_with_comments(string)
      CommentDocument.parse(string)
    end

    # Query a nested value using a dot-path.
    #
    # @param data [Hash] parsed TOML hash
    # @param path [String] dot-separated path (e.g., "database.host")
    # @param default [Object] fallback value
    # @return [Object]
    def self.query(data, path, default: nil)
      Query.get(data, path, default: default)
    end

    # Deep merge two TOML hashes.
    #
    # @param left [Hash] base hash
    # @param right [Hash] hash to merge in
    # @param strategy [Symbol] :override, :keep_existing, or :error_on_conflict
    # @return [Hash]
    def self.merge(left, right, strategy: :override)
      Merger.merge(left, right, strategy: strategy)
    end

    # Compare two TOML hashes and return differences.
    #
    # @param left [Hash] first document
    # @param right [Hash] second document
    # @return [Array<Diff::Change>]
    def self.diff(left, right)
      Diff.diff(left, right)
    end
  end
end
