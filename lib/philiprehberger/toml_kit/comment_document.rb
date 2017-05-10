# frozen_string_literal: true

module Philiprehberger
  module TomlKit
    # Represents a TOML document that preserves comments during round-trip
    # parse/serialize operations.
    #
    # Comments are stored as metadata attached to keys or sections:
    #   - :header_comments -> comments at the top of the document
    #   - :comments -> hash mapping "path.to.key" to { before: [...], inline: "..." }
    #   - :table_comments -> hash mapping "[table]" to { before: [...], inline: "..." }
    class CommentDocument
      attr_reader :data, :comments, :table_comments, :header_comments

      def initialize(data = {}, comments: {}, table_comments: {}, header_comments: [])
        @data = data
        @comments = comments
        @table_comments = table_comments
        @header_comments = header_comments
      end

      # Parse a TOML string preserving comments.
      #
      # @param input [String] TOML document
      # @return [CommentDocument]
      def self.parse(input)
        CommentPreservingParser.new.parse(input)
      end

      # Serialize back to a TOML string with comments preserved.
      #
      # @return [String] TOML formatted string with comments
      def to_toml
        CommentPreservingSerializer.new.serialize(self)
      end

      # Access the underlying data hash.
      #
      # @param key [String] top-level key
      # @return [Object] value
      def [](key)
        @data[key]
      end

      # Set a value in the underlying data hash.
      #
      # @param key [String] top-level key
      # @param value [Object] value to set
      def []=(key, value)
        @data[key] = value
      end

      # Return the data hash for compatibility.
      #
      # @return [Hash]
      def to_h
        @data
      end
    end

    # Parser that tracks comments alongside parsed data.
    class CommentPreservingParser
      # @param input [String] TOML document
      # @return [CommentDocument]
      def parse(input)
        @lines = input.lines
        @data = {}
        @comments = {}
        @table_comments = {}
        @header_comments = []
        @current_path = []
        @pending_comments = []

        parse_lines
        CommentDocument.new(@data, comments: @comments, table_comments: @table_comments,
                                   header_comments: @header_comments)
      end

      private

      def parse_lines
        in_header = true

        @lines.each do |line|
          stripped = line.strip

          if stripped.empty?
            @pending_comments << '' unless @pending_comments.empty? || !in_header
            next
          end

          if stripped.start_with?('#')
            @pending_comments << stripped
            next
          end

          in_header = false

          if stripped.start_with?('[[')
            parse_array_table_line(stripped)
          elsif stripped.start_with?('[')
            parse_table_line(stripped)
          else
            parse_key_value_line(stripped)
          end
        end
      end

      def parse_table_line(line)
        # Extract inline comment
        inline_comment = nil
        table_part = line

        # Find the closing bracket, then check for comment
        bracket_end = line.index(']')
        if bracket_end
          rest = line[(bracket_end + 1)..]
          if rest && (comment_idx = rest.index('#'))
            inline_comment = rest[comment_idx..].strip
            table_part = line[0..bracket_end]
          end
        end

        # Extract table name
        table_name = table_part.strip.sub(/\A\[/, '').sub(/\]\s*\z/, '').strip
        @current_path = table_name.split('.')

        # Navigate/create nested structure
        navigate_to_table(@data, @current_path)

        table_key = "[#{table_name}]"
        store_table_comments(table_key, inline_comment)
      end

      def parse_array_table_line(line)
        inline_comment = nil
        table_part = line

        bracket_end = line.index(']]')
        if bracket_end
          rest = line[(bracket_end + 2)..]
          if rest && (comment_idx = rest.index('#'))
            inline_comment = rest[comment_idx..].strip
            table_part = line[0..(bracket_end + 1)]
          end
        end

        table_name = table_part.strip.sub(/\A\[\[/, '').sub(/\]\]\s*\z/, '').strip
        @current_path = table_name.split('.')

        # Navigate to parent
        parent = navigate_to_table(@data, @current_path[0...-1])
        last_key = @current_path.last
        parent[last_key] = [] unless parent.key?(last_key)
        parent[last_key] << {}

        table_key = "[[#{table_name}]]"
        store_table_comments(table_key, inline_comment)
      end

      def store_table_comments(table_key, inline_comment)
        entry = {}
        entry[:before] = @pending_comments.dup unless @pending_comments.empty?
        entry[:inline] = inline_comment if inline_comment
        @table_comments[table_key] = entry unless entry.empty?
        @pending_comments.clear
      end

      def parse_key_value_line(line)
        # Extract inline comment - be careful not to match # inside strings
        inline_comment = nil
        key_part = extract_key_value_without_comment(line)
        remaining = line[key_part.length..]
        if remaining && (comment_idx = remaining.index('#'))
          inline_comment = remaining[comment_idx..].strip
        end

        # Parse the key from the line
        eq_idx = find_equals_index(key_part)
        return unless eq_idx

        raw_key = key_part[0...eq_idx].strip

        # Build full path for comment storage
        full_path = (@current_path + [raw_key]).join('.')

        # Store comments
        entry = {}
        entry[:before] = @pending_comments.dup unless @pending_comments.empty?
        entry[:inline] = inline_comment if inline_comment
        @comments[full_path] = entry unless entry.empty?
        @pending_comments.clear

        # Actually parse the value using the real parser
        value_str = key_part[(eq_idx + 1)..].strip
        table = navigate_to_table(@data, @current_path)
        keys = raw_key.split('.')
        set_nested(table, keys, parse_value_simple(value_str))
      end

      def extract_key_value_without_comment(line)
        in_string = false
        string_char = nil
        i = 0

        # Skip past the = sign first
        past_equals = false

        while i < line.length
          ch = line[i]

          if in_string
            if ch == '\\' && string_char == '"'
              i += 2
              next
            end
            in_string = false if ch == string_char
          else
            if ch == '=' && !past_equals
              past_equals = true
              i += 1
              next
            end

            if past_equals
              if ['"', "'"].include?(ch)
                in_string = true
                string_char = ch
              elsif ch == '#'
                return line[0...i].rstrip
              end
            end
          end

          i += 1
        end

        line.rstrip
      end

      def find_equals_index(str)
        in_string = false
        string_char = nil

        str.each_char.with_index do |ch, i|
          if in_string
            if ch == '\\' && string_char == '"'
              next
            elsif ch == string_char
              in_string = false
            end
          elsif ['"', "'"].include?(ch)
            in_string = true
            string_char = ch
          elsif ch == '='
            return i
          end
        end
        nil
      end

      def parse_value_simple(str)
        # Delegate to the real parser for proper type handling
        Parser.new.parse("__key__ = #{str}")['__key__']
      end

      def navigate_to_table(root, keys)
        current = root
        keys.each do |key|
          if current.key?(key)
            val = current[key]
            if val.is_a?(Array)
              current = val.last
            elsif val.is_a?(Hash)
              current = val
            else
              return current
            end
          else
            new_table = {}
            current[key] = new_table
            current = new_table
          end
        end
        current
      end

      def set_nested(table, keys, value)
        current = table
        keys[0...-1].each do |key|
          current[key] = {} unless current.key?(key)
          current = current[key]
        end
        current[keys.last] = value
      end
    end

    # Serializer that outputs comments from a CommentDocument.
    class CommentPreservingSerializer
      # @param doc [CommentDocument]
      # @return [String] TOML with comments
      def serialize(doc)
        # Header comments
        lines = doc.header_comments.map { |c| c }
        lines << '' unless doc.header_comments.empty?

        serialize_table(doc.data, [], lines, doc)
        lines.join("\n") << "\n"
      end

      private

      def serialize_table(hash, path, lines, doc)
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

        serializer = Serializer.new

        simple_keys.each do |key|
          full_path = (path + [key]).join('.')
          comment_entry = doc.comments[full_path]

          if comment_entry
            comment_entry[:before]&.each { |c| lines << c }
          end

          line = "#{format_key(key)} = #{serializer.send(:format_value, hash[key])}"
          line = "#{line} #{comment_entry[:inline]}" if comment_entry&.dig(:inline)
          lines << line
        end

        table_keys.each do |key|
          full_path = path + [key]
          table_key = "[#{full_path.map { |k| format_key(k) }.join('.')}]"

          comment_entry = doc.table_comments[table_key]

          lines << '' unless lines.empty?
          if comment_entry
            comment_entry[:before]&.each { |c| lines << c }
          end

          table_line = table_key
          table_line = "#{table_line} #{comment_entry[:inline]}" if comment_entry&.dig(:inline)
          lines << table_line

          serialize_table(hash[key], full_path, lines, doc)
        end

        array_table_keys.each do |key|
          full_path = path + [key]
          table_key = "[[#{full_path.map { |k| format_key(k) }.join('.')}]]"

          hash[key].each_with_index do |element, idx|
            comment_entry = doc.table_comments[table_key] if idx.zero?

            lines << '' unless lines.empty?
            if comment_entry
              comment_entry[:before]&.each { |c| lines << c }
            end

            aot_line = table_key
            aot_line = "#{aot_line} #{comment_entry[:inline]}" if idx.zero? && comment_entry&.dig(:inline)
            lines << aot_line

            serialize_table(element, full_path, lines, doc)
          end
        end
      end

      def format_key(key)
        key = key.to_s
        if key.match?(/\A[A-Za-z0-9_-]+\z/)
          key
        else
          "\"#{key}\""
        end
      end

      def local_time_hash?(hash)
        hash.key?(:hour) && hash.key?(:minute) && hash.key?(:second)
      end
    end
  end
end
