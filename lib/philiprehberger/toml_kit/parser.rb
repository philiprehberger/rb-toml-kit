# frozen_string_literal: true

require 'date'
require 'time'
require 'strscan'

module Philiprehberger
  module TomlKit
    # TOML v1.0 parser.
    #
    # Parses a TOML string into a Ruby Hash with proper type mapping:
    #   - Strings -> String
    #   - Integers -> Integer
    #   - Floats -> Float
    #   - Booleans -> true/false
    #   - Offset Date-Time -> Time
    #   - Local Date-Time -> Time (local)
    #   - Local Date -> Date
    #   - Local Time -> Hash with :hour, :minute, :second keys
    #   - Arrays -> Array
    #   - Inline Tables -> Hash
    #   - Tables -> Hash (nested)
    #   - Array of Tables -> Array of Hashes
    class Parser
      # @param input [String] TOML document
      # @return [Hash] parsed result
      def parse(input)
        @scanner = StringScanner.new(input)
        @result = {}
        @current_table = @result
        @current_path = []
        @implicit_tables = {}
        @defined_tables = {}
        @defined_array_tables = {}

        parse_document
        @result
      end

      private

      def parse_document
        skip_whitespace_and_newlines
        until @scanner.eos?
          skip_whitespace
          case @scanner.peek(1)
          when '#'
            skip_comment
          when '['
            parse_table_header
          when "\n", "\r"
            skip_newline
          when ''
            break
          else
            key, value = parse_key_value
            set_value(@current_table, key, value)
          end
          skip_whitespace_and_newlines
        end
      end

      def skip_whitespace
        @scanner.scan(/[ \t]*/)
      end

      def skip_newline
        @scanner.scan(/\r?\n/)
      end

      def skip_whitespace_and_newlines
        @scanner.scan(/\s*/)
      end

      def skip_comment
        @scanner.scan(/#[^\n]*/)
      end

      def skip_whitespace_and_comments
        loop do
          skip_whitespace
          break unless @scanner.peek(1) == '#'

          skip_comment
        end
      end

      def parse_table_header
        if @scanner.peek(2) == '[['
          parse_array_table
        else
          parse_standard_table
        end
      end

      def parse_standard_table
        @scanner.scan('[')
        skip_whitespace
        keys = parse_key
        skip_whitespace
        expect(']')

        skip_whitespace_and_comments
        consume_newline_or_eof

        path_str = keys.join('.')
        raise ParseError, "Table [#{path_str}] already defined" if @defined_tables[path_str]

        @defined_tables[path_str] = true
        @current_path = keys
        @current_table = navigate_to_table(@result, keys, define: true)
      end

      def parse_array_table
        @scanner.scan('[[')
        skip_whitespace
        keys = parse_key
        skip_whitespace
        expect(']]')

        skip_whitespace_and_comments
        consume_newline_or_eof

        path_str = keys.join('.')
        @defined_array_tables[path_str] = true
        @current_path = keys

        parent = navigate_to_table(@result, keys[0...-1], define: false)
        last_key = keys.last

        parent[last_key] = [] unless parent.key?(last_key)
        arr = parent[last_key]
        raise ParseError, "Key #{last_key} is not an array of tables" unless arr.is_a?(Array)

        new_table = {}
        arr << new_table
        @current_table = new_table
      end

      def navigate_to_table(root, keys, define:)
        current = root
        keys.each_with_index do |key, idx|
          partial_path = keys[0..idx].join('.')
          if current.key?(key)
            val = current[key]
            if val.is_a?(Array)
              current = val.last
            elsif val.is_a?(Hash)
              current = val
            else
              raise ParseError, "Key #{key} already exists as a non-table value"
            end
          else
            new_table = {}
            current[key] = new_table
            @implicit_tables[partial_path] = true if !define || idx < keys.length - 1
            current = new_table
          end
        end
        current
      end

      def parse_key_value
        keys = parse_key
        skip_whitespace
        expect('=')
        skip_whitespace
        value = parse_value
        skip_whitespace_and_comments
        consume_newline_or_eof
        [keys, value]
      end

      def set_value(table, keys, value)
        current = table
        keys[0...-1].each do |key|
          if current.key?(key)
            existing = current[key]
            if existing.is_a?(Array)
              current = existing.last
            elsif existing.is_a?(Hash)
              current = existing
            else
              raise ParseError, "Key #{key} already exists as a non-table value"
            end
          else
            new_table = {}
            current[key] = new_table
            current = new_table
          end
        end
        last_key = keys.last
        raise ParseError, "Duplicate key: #{last_key}" if current.key?(last_key)

        current[last_key] = value
        current
      end

      def parse_key
        keys = [parse_simple_key]
        keys << parse_simple_key while @scanner.scan(/[ \t]*\.[ \t]*/)
        keys
      end

      def parse_simple_key
        if @scanner.peek(1) == '"'
          parse_basic_string
        elsif @scanner.peek(1) == "'"
          parse_literal_string
        else
          parse_bare_key
        end
      end

      def parse_bare_key
        key = @scanner.scan(/[A-Za-z0-9_-]+/)
        raise ParseError, "Expected bare key at position #{@scanner.pos}" unless key

        key
      end

      def parse_value
        case @scanner.peek(1)
        when '"'
          if @scanner.peek(3) == '"""'
            parse_multiline_basic_string
          else
            parse_basic_string
          end
        when "'"
          if @scanner.peek(3) == "'''"
            parse_multiline_literal_string
          else
            parse_literal_string
          end
        when 't'
          parse_true
        when 'f'
          parse_false
        when '['
          parse_array
        when '{'
          parse_inline_table
        when 'i', 'n'
          parse_special_float
        when '+', '-'
          if @scanner.rest.match?(/\A[+-](inf|nan)/)
            parse_special_float
          else
            parse_number_or_date
          end
        else
          parse_number_or_date
        end
      end

      def parse_basic_string
        expect('"')
        result = +''
        until @scanner.eos?
          ch = @scanner.scan(/[^"\\]+/)
          result << ch if ch
          if @scanner.peek(1) == '\\'
            result << parse_escape_sequence
          elsif @scanner.peek(1) == '"'
            @scanner.scan('"')
            return result
          else
            raise ParseError, 'Unterminated basic string'
          end
        end
        raise ParseError, 'Unterminated basic string'
      end

      def parse_escape_sequence
        @scanner.scan('\\')
        ch = @scanner.getch
        case ch
        when 'b' then "\b"
        when 't' then "\t"
        when 'n' then "\n"
        when 'f' then "\f"
        when 'r' then "\r"
        when '"' then '"'
        when '\\' then '\\'
        when 'u'
          hex = @scanner.scan(/[0-9A-Fa-f]{4}/)
          raise ParseError, 'Invalid unicode escape' unless hex

          hex.to_i(16).chr(Encoding::UTF_8)
        when 'U'
          hex = @scanner.scan(/[0-9A-Fa-f]{8}/)
          raise ParseError, 'Invalid unicode escape' unless hex

          hex.to_i(16).chr(Encoding::UTF_8)
        else
          raise ParseError, "Invalid escape sequence: \\#{ch}"
        end
      end

      def parse_multiline_basic_string
        @scanner.scan('"""')
        # skip first newline if immediately after opening
        @scanner.scan(/\r?\n/)
        result = +''
        until @scanner.eos?
          if @scanner.peek(3) == '"""'
            @scanner.scan('"""')
            return result
          elsif @scanner.peek(1) == '\\'
            if @scanner.rest.match?(/\\\s*\n/)
              # line-ending backslash: trim whitespace
              @scanner.scan(/\\[ \t]*\r?\n\s*/)
            else
              result << parse_escape_sequence
            end
          else
            ch = @scanner.getch
            raise ParseError, 'Unterminated multiline basic string' unless ch

            result << ch
          end
        end
        raise ParseError, 'Unterminated multiline basic string'
      end

      def parse_literal_string
        expect("'")
        content = @scanner.scan(/[^']*/)
        expect("'")
        content || ''
      end

      def parse_multiline_literal_string
        @scanner.scan('\'\'\'')
        @scanner.scan(/\r?\n/)
        result = +''
        until @scanner.eos?
          if @scanner.peek(3) == "'''"
            @scanner.scan('\'\'\'')
            return result
          else
            ch = @scanner.getch
            raise ParseError, 'Unterminated multiline literal string' unless ch

            result << ch
          end
        end
        raise ParseError, 'Unterminated multiline literal string'
      end

      def parse_true
        @scanner.scan('true') or raise ParseError, "Expected 'true'"
        true
      end

      def parse_false
        @scanner.scan('false') or raise ParseError, "Expected 'false'"
        false
      end

      def parse_special_float
        str = @scanner.scan(/[+-]?(inf|nan)/)
        raise ParseError, 'Expected inf or nan' unless str

        case str
        when 'inf', '+inf' then Float::INFINITY
        when '-inf' then -Float::INFINITY
        when 'nan', '+nan', '-nan' then Float::NAN
        end
      end

      def parse_number_or_date
        # Peek ahead to determine type
        rest = @scanner.rest

        # Offset date-time: 1979-05-27T07:32:00Z or 1979-05-27T07:32:00+00:00
        case rest
        when /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})/
          parse_offset_datetime
        # Local date-time: 1979-05-27T07:32:00
        when /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}/
          parse_local_datetime
        # Local date: 1979-05-27
        when /\A\d{4}-\d{2}-\d{2}(?![T \d])/
          parse_local_date
        # Local time: 07:32:00
        when /\A\d{2}:\d{2}:\d{2}/
          parse_local_time
        # Hex integer: 0x...
        when /\A[+-]?0x/
          parse_hex_integer
        # Octal integer: 0o...
        when /\A[+-]?0o/
          parse_octal_integer
        # Binary integer: 0b...
        when /\A[+-]?0b/
          parse_binary_integer
        # Float (has dot or exponent)
        when /\A[+-]?\d[\d_]*(\.\d[\d_]*)?[eE]/, /\A[+-]?\d[\d_]*\.\d/
          parse_float
        else
          parse_integer
        end
      end

      def parse_offset_datetime
        str = @scanner.scan(/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})/)
        raise ParseError, 'Invalid offset datetime' unless str

        Time.parse(str)
      end

      def parse_local_datetime
        str = @scanner.scan(/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?/)
        raise ParseError, 'Invalid local datetime' unless str

        Time.parse(str)
      end

      def parse_local_date
        str = @scanner.scan(/\d{4}-\d{2}-\d{2}/)
        raise ParseError, 'Invalid local date' unless str

        Date.parse(str)
      end

      def parse_local_time
        str = @scanner.scan(/\d{2}:\d{2}:\d{2}(\.\d+)?/)
        raise ParseError, 'Invalid local time' unless str

        parts = str.split(':')
        hour = parts[0].to_i
        minute = parts[1].to_i
        sec_parts = parts[2].split('.')
        second = sec_parts[0].to_i
        nanosecond = sec_parts[1] ? sec_parts[1].ljust(9, '0')[0, 9].to_i : 0

        { hour: hour, minute: minute, second: second, nanosecond: nanosecond }
      end

      def parse_integer
        str = @scanner.scan(/[+-]?\d[\d_]*/)
        raise ParseError, "Invalid integer at position #{@scanner.pos}" unless str

        str.delete('_').to_i
      end

      def parse_hex_integer
        str = @scanner.scan(/[+-]?0x[0-9A-Fa-f_]+/)
        raise ParseError, 'Invalid hex integer' unless str

        str.delete('_').to_i(16)
      end

      def parse_octal_integer
        str = @scanner.scan(/[+-]?0o[0-7_]+/)
        raise ParseError, 'Invalid octal integer' unless str

        str.delete('_').to_i(8)
      end

      def parse_binary_integer
        str = @scanner.scan(/[+-]?0b[01_]+/)
        raise ParseError, 'Invalid binary integer' unless str

        str.delete('_').to_i(2)
      end

      def parse_float
        str = @scanner.scan(/[+-]?\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d[\d_]*)?/)
        raise ParseError, 'Invalid float' unless str

        str.delete('_').to_f
      end

      def parse_array
        @scanner.scan('[')
        arr = []
        skip_whitespace_and_newlines
        skip_comments_in_collection

        until @scanner.peek(1) == ']'
          arr << parse_value
          skip_whitespace_and_newlines
          skip_comments_in_collection
          @scanner.scan(',')
          skip_whitespace_and_newlines
          skip_comments_in_collection
        end
        expect(']')
        arr
      end

      def parse_inline_table
        @scanner.scan('{')
        table = {}
        skip_whitespace
        unless @scanner.peek(1) == '}'
          loop do
            keys = parse_key
            skip_whitespace
            expect('=')
            skip_whitespace
            value = parse_value
            set_value(table, keys, value)
            skip_whitespace
            break unless @scanner.scan(',')

            skip_whitespace
          end
        end
        expect('}')
        table
      end

      def skip_comments_in_collection
        loop do
          skip_whitespace_and_newlines
          break unless @scanner.peek(1) == '#'

          skip_comment
        end
      end

      def expect(str)
        return if @scanner.scan(Regexp.new(Regexp.escape(str)))

        raise ParseError, "Expected '#{str}' at position #{@scanner.pos}"
      end

      def consume_newline_or_eof
        return if @scanner.eos?

        skip_whitespace
        return if @scanner.eos?
        return if @scanner.scan(/\r?\n/)
        return if @scanner.peek(1) == '#'

        raise ParseError, "Expected newline or EOF at position #{@scanner.pos}, got '#{@scanner.peek(10)}'"
      end
    end
  end
end
