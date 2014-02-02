# frozen_string_literal: true

require_relative 'toml_kit/version'
require_relative 'toml_kit/parser'
require_relative 'toml_kit/serializer'

module Philiprehberger
  module TomlKit
    class Error < StandardError; end
    class ParseError < Error; end

    # Parse a TOML string into a Ruby Hash.
    #
    # @param string [String] TOML document
    # @return [Hash] parsed result
    # @raise [ParseError] if the input is not valid TOML
    def self.parse(string)
      Parser.new.parse(string)
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
  end
end
