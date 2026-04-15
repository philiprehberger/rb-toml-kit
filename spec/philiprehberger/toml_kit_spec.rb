# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Philiprehberger::TomlKit do
  it 'has a version number' do
    expect(Philiprehberger::TomlKit::VERSION).not_to be_nil
  end

  describe '.parse' do
    context 'with simple key-value pairs' do
      it 'parses string values' do
        result = described_class.parse('title = "TOML Example"')
        expect(result['title']).to eq('TOML Example')
      end

      it 'parses integer values' do
        result = described_class.parse('count = 42')
        expect(result['count']).to eq(42)
      end

      it 'parses negative integers' do
        result = described_class.parse('temp = -17')
        expect(result['temp']).to eq(-17)
      end

      it 'parses float values' do
        result = described_class.parse('pi = 3.14159')
        expect(result['pi']).to be_within(0.00001).of(3.14159)
      end

      it 'parses boolean true' do
        result = described_class.parse('enabled = true')
        expect(result['enabled']).to be true
      end

      it 'parses boolean false' do
        result = described_class.parse('enabled = false')
        expect(result['enabled']).to be false
      end

      it 'parses multiple key-value pairs' do
        toml = <<~TOML
          name = "test"
          version = 1
          active = true
        TOML
        result = described_class.parse(toml)
        expect(result).to eq('name' => 'test', 'version' => 1, 'active' => true)
      end
    end

    context 'with string types' do
      it 'parses basic strings with escapes' do
        result = described_class.parse('msg = "hello\\nworld"')
        expect(result['msg']).to eq("hello\nworld")
      end

      it 'parses literal strings' do
        result = described_class.parse("path = 'C:\\Users\\file'")
        expect(result['path']).to eq('C:\Users\file')
      end

      it 'parses multiline basic strings' do
        toml = 'msg = """line1\nline2"""'
        result = described_class.parse(toml)
        expect(result['msg']).to eq("line1\nline2")
      end

      it 'parses multiline literal strings' do
        toml = "msg = '''first\nsecond'''"
        result = described_class.parse(toml)
        expect(result['msg']).to eq("first\nsecond")
      end

      it 'parses unicode escapes' do
        result = described_class.parse('char = "\\u0041"')
        expect(result['char']).to eq('A')
      end
    end

    context 'with integer formats' do
      it 'parses hexadecimal integers' do
        result = described_class.parse('color = 0xDEADBEEF')
        expect(result['color']).to eq(0xDEADBEEF)
      end

      it 'parses octal integers' do
        result = described_class.parse('perm = 0o755')
        expect(result['perm']).to eq(0o755)
      end

      it 'parses binary integers' do
        result = described_class.parse('bits = 0b11010110')
        expect(result['bits']).to eq(0b11010110)
      end

      it 'parses integers with underscores' do
        result = described_class.parse('large = 1_000_000')
        expect(result['large']).to eq(1_000_000)
      end
    end

    context 'with float special values' do
      it 'parses positive infinity' do
        result = described_class.parse('val = inf')
        expect(result['val']).to eq(Float::INFINITY)
      end

      it 'parses negative infinity' do
        result = described_class.parse('val = -inf')
        expect(result['val']).to eq(-Float::INFINITY)
      end

      it 'parses nan' do
        result = described_class.parse('val = nan')
        expect(result['val']).to be_nan
      end

      it 'parses scientific notation' do
        result = described_class.parse('val = 5e+22')
        expect(result['val']).to eq(5e+22)
      end
    end

    context 'with datetime types' do
      it 'parses offset datetime' do
        result = described_class.parse('dt = 1979-05-27T07:32:00Z')
        expect(result['dt']).to be_a(Time)
        expect(result['dt'].year).to eq(1979)
        expect(result['dt'].month).to eq(5)
        expect(result['dt'].day).to eq(27)
      end

      it 'parses offset datetime with timezone' do
        result = described_class.parse('dt = 1979-05-27T07:32:00+09:00')
        expect(result['dt']).to be_a(Time)
        expect(result['dt'].utc_offset).to eq(9 * 3600)
      end

      it 'parses local datetime' do
        result = described_class.parse('dt = 1979-05-27T07:32:00')
        expect(result['dt']).to be_a(Time)
        expect(result['dt'].hour).to eq(7)
      end

      it 'parses local date' do
        result = described_class.parse('d = 1979-05-27')
        expect(result['d']).to be_a(Date)
        expect(result['d']).to eq(Date.new(1979, 5, 27))
      end

      it 'parses local time' do
        result = described_class.parse('t = 07:32:00')
        expect(result['t']).to eq({ hour: 7, minute: 32, second: 0, nanosecond: 0 })
      end
    end

    context 'with arrays' do
      it 'parses simple arrays' do
        result = described_class.parse('nums = [1, 2, 3]')
        expect(result['nums']).to eq([1, 2, 3])
      end

      it 'parses string arrays' do
        result = described_class.parse('tags = ["a", "b", "c"]')
        expect(result['tags']).to eq(%w[a b c])
      end

      it 'parses nested arrays' do
        result = described_class.parse('nested = [[1, 2], [3, 4]]')
        expect(result['nested']).to eq([[1, 2], [3, 4]])
      end

      it 'parses multiline arrays' do
        toml = <<~TOML
          nums = [
            1,
            2,
            3,
          ]
        TOML
        result = described_class.parse(toml)
        expect(result['nums']).to eq([1, 2, 3])
      end
    end

    context 'with tables' do
      it 'parses standard tables' do
        toml = <<~TOML
          [server]
          host = "localhost"
          port = 8080
        TOML
        result = described_class.parse(toml)
        expect(result['server']['host']).to eq('localhost')
        expect(result['server']['port']).to eq(8080)
      end

      it 'parses nested tables' do
        toml = <<~TOML
          [database]
          host = "localhost"

          [database.connection]
          timeout = 30
        TOML
        result = described_class.parse(toml)
        expect(result['database']['host']).to eq('localhost')
        expect(result['database']['connection']['timeout']).to eq(30)
      end

      it 'parses inline tables' do
        result = described_class.parse('point = {x = 1, y = 2}')
        expect(result['point']).to eq('x' => 1, 'y' => 2)
      end
    end

    context 'with array of tables' do
      it 'parses array of tables' do
        toml = <<~TOML
          [[products]]
          name = "Hammer"
          sku = 738594937

          [[products]]
          name = "Nail"
          sku = 284758393
        TOML
        result = described_class.parse(toml)
        expect(result['products']).to be_an(Array)
        expect(result['products'].length).to eq(2)
        expect(result['products'][0]['name']).to eq('Hammer')
        expect(result['products'][1]['name']).to eq('Nail')
      end
    end

    context 'with dotted keys' do
      it 'parses dotted keys' do
        result = described_class.parse('fruit.name = "banana"')
        expect(result['fruit']['name']).to eq('banana')
      end

      it 'parses quoted dotted keys' do
        result = described_class.parse('"site"."name" = "example"')
        expect(result['site']['name']).to eq('example')
      end
    end

    context 'with comments' do
      it 'ignores line comments' do
        toml = <<~TOML
          # This is a comment
          key = "value" # inline comment
        TOML
        result = described_class.parse(toml)
        expect(result['key']).to eq('value')
      end
    end

    context 'with errors' do
      it 'raises ParseError for duplicate keys' do
        toml = <<~TOML
          key = 1
          key = 2
        TOML
        expect { described_class.parse(toml) }.to raise_error(Philiprehberger::TomlKit::ParseError)
      end

      it 'raises ParseError for duplicate tables' do
        toml = <<~TOML
          [a]
          key = 1
          [a]
          key = 2
        TOML
        expect { described_class.parse(toml) }.to raise_error(Philiprehberger::TomlKit::ParseError)
      end
    end
  end

  describe '.valid?' do
    it 'returns true for valid TOML' do
      expect(described_class.valid?('key = "value"')).to be true
    end

    it 'returns false for invalid TOML' do
      expect(described_class.valid?('key = [broken')).to be false
    end

    it 'returns true for an empty document' do
      expect(described_class.valid?('')).to be true
    end
  end

  describe '.dump' do
    it 'serializes simple key-value pairs' do
      hash = { 'name' => 'test', 'version' => 1 }
      toml = described_class.dump(hash)
      expect(toml).to include('name = "test"')
      expect(toml).to include('version = 1')
    end

    it 'serializes nested tables' do
      hash = { 'server' => { 'host' => 'localhost', 'port' => 8080 } }
      toml = described_class.dump(hash)
      expect(toml).to include('[server]')
      expect(toml).to include('host = "localhost"')
      expect(toml).to include('port = 8080')
    end

    it 'serializes arrays' do
      hash = { 'tags' => %w[a b c] }
      toml = described_class.dump(hash)
      expect(toml).to include('tags = ["a", "b", "c"]')
    end

    it 'serializes array of tables' do
      hash = {
        'products' => [
          { 'name' => 'Hammer' },
          { 'name' => 'Nail' }
        ]
      }
      toml = described_class.dump(hash)
      expect(toml).to include('[[products]]')
      expect(toml).to include('name = "Hammer"')
      expect(toml).to include('name = "Nail"')
    end

    it 'serializes booleans' do
      hash = { 'enabled' => true, 'debug' => false }
      toml = described_class.dump(hash)
      expect(toml).to include('enabled = true')
      expect(toml).to include('debug = false')
    end

    it 'serializes dates' do
      hash = { 'created' => Date.new(2026, 3, 26) }
      toml = described_class.dump(hash)
      expect(toml).to include('created = 2026-03-26')
    end

    it 'serializes special floats' do
      hash = { 'inf_val' => Float::INFINITY, 'neg_inf' => -Float::INFINITY, 'nan_val' => Float::NAN }
      toml = described_class.dump(hash)
      expect(toml).to include('inf_val = inf')
      expect(toml).to include('neg_inf = -inf')
      expect(toml).to include('nan_val = nan')
    end
  end

  describe 'roundtrip' do
    it 'roundtrips simple documents' do
      original = { 'name' => 'test', 'version' => 1, 'active' => true }
      toml = described_class.dump(original)
      result = described_class.parse(toml)
      expect(result).to eq(original)
    end

    it 'roundtrips nested tables' do
      original = {
        'database' => {
          'host' => 'localhost',
          'port' => 5432
        }
      }
      toml = described_class.dump(original)
      result = described_class.parse(toml)
      expect(result).to eq(original)
    end

    it 'roundtrips array of tables' do
      original = {
        'servers' => [
          { 'name' => 'alpha', 'port' => 8001 },
          { 'name' => 'beta', 'port' => 8002 }
        ]
      }
      toml = described_class.dump(original)
      result = described_class.parse(toml)
      expect(result).to eq(original)
    end
  end

  describe '.load and .save' do
    it 'loads a TOML file' do
      file = Tempfile.new(['test', '.toml'])
      file.write("key = \"value\"\n")
      file.close

      result = described_class.load(file.path)
      expect(result['key']).to eq('value')
    ensure
      file&.unlink
    end

    it 'saves a hash to a TOML file' do
      file = Tempfile.new(['test', '.toml'])
      file.close

      described_class.save({ 'key' => 'value' }, file.path)
      content = File.read(file.path)
      expect(content).to include('key = "value"')
    ensure
      file&.unlink
    end

    it 'roundtrips through file operations' do
      file = Tempfile.new(['test', '.toml'])
      file.close

      original = { 'app' => { 'name' => 'test', 'port' => 3000 } }
      described_class.save(original, file.path)
      result = described_class.load(file.path)
      expect(result).to eq(original)
    ensure
      file&.unlink
    end

    it 'raises Errno::ENOENT for missing file' do
      expect { described_class.load('/nonexistent/path.toml') }.to raise_error(Errno::ENOENT)
    end
  end

  describe '.parse_with_comments / CommentDocument' do
    it 'parses and preserves header comments' do
      toml = <<~TOML
        # Configuration file
        # Version 2
        title = "My App"
      TOML
      doc = described_class.parse_with_comments(toml)
      expect(doc.comments['title'][:before]).to include('# Configuration file')
      expect(doc.comments['title'][:before]).to include('# Version 2')
      expect(doc['title']).to eq('My App')
    end

    it 'parses and preserves inline comments on keys' do
      toml = <<~TOML
        port = 8080 # default port
      TOML
      doc = described_class.parse_with_comments(toml)
      expect(doc['port']).to eq(8080)
      expect(doc.comments['port'][:inline]).to eq('# default port')
    end

    it 'parses and preserves comments before keys' do
      toml = <<~TOML
        # Server port
        port = 8080
      TOML
      doc = described_class.parse_with_comments(toml)
      expect(doc.comments['port'][:before]).to include('# Server port')
    end

    it 'parses and preserves table comments' do
      toml = <<~TOML
        # Database section
        [database]
        host = "localhost"
      TOML
      doc = described_class.parse_with_comments(toml)
      expect(doc.table_comments['[database]'][:before]).to include('# Database section')
      expect(doc['database']['host']).to eq('localhost')
    end

    it 'round-trips a document with comments' do
      toml = <<~TOML
        # Config file
        title = "My App"

        # Database section
        [database]
        host = "localhost"
      TOML
      doc = described_class.parse_with_comments(toml)
      output = doc.to_toml
      expect(output).to include('# Config file')
      expect(output).to include('# Database section')
      expect(output).to include('title = "My App"')
      expect(output).to include('host = "localhost"')
    end

    it 'returns data via to_h' do
      doc = described_class.parse_with_comments('key = "value"')
      expect(doc.to_h).to eq('key' => 'value')
    end

    it 'supports []= for setting values' do
      doc = described_class.parse_with_comments('key = "value"')
      doc['key'] = 'new_value'
      expect(doc['key']).to eq('new_value')
    end
  end

  describe 'Schema' do
    let(:schema) do
      Philiprehberger::TomlKit::Schema.new(
        'name' => { type: String, required: true },
        'port' => { type: Integer, required: true },
        'debug' => { type: :boolean, required: false },
        'database' => {
          type: Hash,
          required: true,
          properties: {
            'host' => { type: String, required: true },
            'port' => { type: Integer }
          }
        },
        'tags' => { type: Array, items: { type: String } }
      )
    end

    it 'validates a correct document' do
      data = {
        'name' => 'my_app',
        'port' => 8080,
        'debug' => true,
        'database' => { 'host' => 'localhost', 'port' => 5432 },
        'tags' => %w[web api]
      }
      errors = schema.validate(data)
      expect(errors).to be_empty
    end

    it 'reports missing required keys' do
      data = { 'port' => 8080, 'database' => { 'host' => 'localhost' } }
      errors = schema.validate(data)
      expect(errors).to include('Missing required key: name')
    end

    it 'reports type mismatches' do
      data = {
        'name' => 123,
        'port' => 8080,
        'database' => { 'host' => 'localhost' }
      }
      errors = schema.validate(data)
      expect(errors.any? { |e| e.include?('Type mismatch at name') }).to be true
    end

    it 'validates nested properties' do
      data = {
        'name' => 'app',
        'port' => 8080,
        'database' => { 'host' => 123 }
      }
      errors = schema.validate(data)
      expect(errors.any? { |e| e.include?('Type mismatch at database.host') }).to be true
    end

    it 'validates array items' do
      data = {
        'name' => 'app',
        'port' => 8080,
        'database' => { 'host' => 'localhost' },
        'tags' => ['valid', 123]
      }
      errors = schema.validate(data)
      expect(errors.any? { |e| e.include?('Type mismatch at tags[1]') }).to be true
    end

    it 'validates boolean type' do
      data = {
        'name' => 'app',
        'port' => 8080,
        'debug' => 'yes',
        'database' => { 'host' => 'localhost' }
      }
      errors = schema.validate(data)
      expect(errors.any? { |e| e.include?('Type mismatch at debug') }).to be true
    end

    it 'raises with validate!' do
      data = { 'port' => 8080, 'database' => { 'host' => 'localhost' } }
      expect { schema.validate!(data) }.to raise_error(Philiprehberger::TomlKit::SchemaError)
    end

    it 'returns true on validate! with valid data' do
      data = {
        'name' => 'app',
        'port' => 8080,
        'database' => { 'host' => 'localhost' }
      }
      expect(schema.validate!(data)).to be true
    end

    it 'reports missing required nested keys' do
      data = {
        'name' => 'app',
        'port' => 8080,
        'database' => { 'port' => 5432 }
      }
      errors = schema.validate(data)
      expect(errors).to include('Missing required key: database.host')
    end
  end

  describe 'Merger' do
    let(:left) do
      {
        'title' => 'App',
        'database' => { 'host' => 'localhost', 'port' => 5432 },
        'only_left' => true
      }
    end

    let(:right) do
      {
        'title' => 'New App',
        'database' => { 'host' => 'remote', 'timeout' => 30 },
        'only_right' => true
      }
    end

    describe 'with :override strategy' do
      it 'right-side wins on conflicts' do
        result = described_class.merge(left, right, strategy: :override)
        expect(result['title']).to eq('New App')
      end

      it 'deep merges nested hashes' do
        result = described_class.merge(left, right, strategy: :override)
        expect(result['database']['host']).to eq('remote')
        expect(result['database']['port']).to eq(5432)
        expect(result['database']['timeout']).to eq(30)
      end

      it 'keeps keys unique to each side' do
        result = described_class.merge(left, right, strategy: :override)
        expect(result['only_left']).to be true
        expect(result['only_right']).to be true
      end
    end

    describe 'with :keep_existing strategy' do
      it 'left-side wins on conflicts' do
        result = described_class.merge(left, right, strategy: :keep_existing)
        expect(result['title']).to eq('App')
      end

      it 'deep merges nested hashes' do
        result = described_class.merge(left, right, strategy: :keep_existing)
        expect(result['database']['host']).to eq('localhost')
        expect(result['database']['timeout']).to eq(30)
      end
    end

    describe 'with :error_on_conflict strategy' do
      it 'raises on conflicting keys' do
        expect do
          described_class.merge(left, right, strategy: :error_on_conflict)
        end.to raise_error(Philiprehberger::TomlKit::MergeConflictError, /title/)
      end

      it 'merges successfully when no conflicts' do
        no_conflict_right = { 'only_right' => true, 'database' => { 'timeout' => 30 } }
        result = described_class.merge(left, no_conflict_right, strategy: :error_on_conflict)
        expect(result['only_right']).to be true
        expect(result['database']['timeout']).to eq(30)
      end
    end

    it 'does not mutate the original hashes' do
      original_left = left.dup
      described_class.merge(left, right, strategy: :override)
      expect(left['title']).to eq(original_left['title'])
    end

    it 'raises on invalid strategy' do
      expect do
        Philiprehberger::TomlKit::Merger.new(:bad)
      end.to raise_error(ArgumentError, /Unknown merge strategy/)
    end
  end

  describe 'Query' do
    let(:data) do
      {
        'title' => 'App',
        'database' => {
          'host' => 'localhost',
          'port' => 5432,
          'replicas' => [
            { 'host' => 'replica1', 'port' => 5433 },
            { 'host' => 'replica2', 'port' => 5434 }
          ]
        },
        'tags' => %w[web api]
      }
    end

    describe '.query (get)' do
      it 'retrieves top-level values' do
        expect(described_class.query(data, 'title')).to eq('App')
      end

      it 'retrieves nested values' do
        expect(described_class.query(data, 'database.host')).to eq('localhost')
      end

      it 'retrieves deeply nested values' do
        expect(described_class.query(data, 'database.port')).to eq(5432)
      end

      it 'returns default for missing paths' do
        expect(described_class.query(data, 'missing.path', default: 'N/A')).to eq('N/A')
      end

      it 'returns nil by default for missing paths' do
        expect(described_class.query(data, 'missing')).to be_nil
      end

      it 'accesses array elements by index' do
        expect(described_class.query(data, 'tags[0]')).to eq('web')
        expect(described_class.query(data, 'tags[1]')).to eq('api')
      end

      it 'accesses array of table elements' do
        expect(described_class.query(data, 'database.replicas[0].host')).to eq('replica1')
        expect(described_class.query(data, 'database.replicas[1].port')).to eq(5434)
      end
    end

    describe 'Query.set' do
      it 'sets a top-level value' do
        hash = {}
        Philiprehberger::TomlKit::Query.set(hash, 'name', 'test')
        expect(hash['name']).to eq('test')
      end

      it 'sets a nested value creating intermediate hashes' do
        hash = {}
        Philiprehberger::TomlKit::Query.set(hash, 'database.host', 'localhost')
        expect(hash['database']['host']).to eq('localhost')
      end

      it 'sets array element values' do
        hash = { 'tags' => %w[a b c] }
        Philiprehberger::TomlKit::Query.set(hash, 'tags[1]', 'updated')
        expect(hash['tags'][1]).to eq('updated')
      end
    end

    describe 'Query.exists?' do
      it 'returns true for existing paths' do
        expect(Philiprehberger::TomlKit::Query.exists?(data, 'database.host')).to be true
      end

      it 'returns false for missing paths' do
        expect(Philiprehberger::TomlKit::Query.exists?(data, 'database.missing')).to be false
      end

      it 'returns true for array element paths' do
        expect(Philiprehberger::TomlKit::Query.exists?(data, 'tags[0]')).to be true
      end
    end

    describe 'Query.delete' do
      it 'deletes a key and returns its value' do
        hash = { 'a' => 1, 'b' => 2 }
        result = Philiprehberger::TomlKit::Query.delete(hash, 'a')
        expect(result).to eq(1)
        expect(hash).not_to have_key('a')
      end

      it 'deletes a nested key' do
        hash = { 'db' => { 'host' => 'localhost', 'port' => 5432 } }
        Philiprehberger::TomlKit::Query.delete(hash, 'db.host')
        expect(hash['db']).not_to have_key('host')
        expect(hash['db']['port']).to eq(5432)
      end

      it 'returns nil for missing paths' do
        hash = { 'a' => 1 }
        expect(Philiprehberger::TomlKit::Query.delete(hash, 'missing')).to be_nil
      end
    end
  end

  describe 'TypeCoercion' do
    let(:coercion) { Philiprehberger::TomlKit::TypeCoercion.new }

    it 'registers and applies a serializer' do
      coercion.register(Symbol, serializer: lambda(&:to_s))
      result = coercion.coerce_for_serialize(:hello)
      expect(result).to eq('hello')
    end

    it 'handles nested hashes during serialization' do
      coercion.register(Symbol, serializer: lambda(&:to_s))
      data = { 'key' => :world, 'nested' => { 'inner' => :foo } }
      result = coercion.coerce_for_serialize(data)
      expect(result['key']).to eq('world')
      expect(result['nested']['inner']).to eq('foo')
    end

    it 'handles arrays during serialization' do
      coercion.register(Symbol, serializer: lambda(&:to_s))
      result = coercion.coerce_for_serialize(%i[a b c])
      expect(result).to eq(%w[a b c])
    end

    it 'supports tagged round-trip coercions' do
      coercion.register(
        Symbol,
        tag: 'symbol',
        serializer: lambda(&:to_s),
        deserializer: lambda(&:to_sym)
      )
      serialized = coercion.coerce_for_serialize(:hello)
      expect(serialized).to eq('__coerced:symbol:hello')

      deserialized = coercion.coerce_for_deserialize(serialized)
      expect(deserialized).to eq(:hello)
    end

    it 'leaves unregistered types alone' do
      result = coercion.coerce_for_serialize('plain string')
      expect(result).to eq('plain string')
    end

    it 'reports whether it handles a type' do
      expect(coercion.handles?(:sym)).to be false
      coercion.register(Symbol, serializer: lambda(&:to_s))
      expect(coercion.handles?(:sym)).to be true
    end

    it 'returns registered rules' do
      coercion.register(Symbol, serializer: lambda(&:to_s))
      expect(coercion.rules.length).to eq(1)
      expect(coercion.rules.first.type).to eq(Symbol)
    end

    it 'deserializes nested tagged values' do
      coercion.register(
        Symbol,
        tag: 'symbol',
        serializer: lambda(&:to_s),
        deserializer: lambda(&:to_sym)
      )
      data = { 'key' => '__coerced:symbol:hello', 'arr' => ['__coerced:symbol:world'] }
      result = coercion.coerce_for_deserialize(data)
      expect(result['key']).to eq(:hello)
      expect(result['arr'].first).to eq(:world)
    end
  end

  describe 'Diff' do
    let(:left) do
      {
        'title' => 'App',
        'version' => 1,
        'database' => { 'host' => 'localhost', 'port' => 5432 },
        'removed_key' => 'gone'
      }
    end

    let(:right) do
      {
        'title' => 'App',
        'version' => 2,
        'database' => { 'host' => 'remote', 'port' => 5432, 'timeout' => 30 },
        'added_key' => 'new'
      }
    end

    describe '.diff' do
      it 'detects changed values' do
        changes = described_class.diff(left, right)
        version_change = changes.find { |c| c.path == 'version' }
        expect(version_change).not_to be_nil
        expect(version_change.type).to eq(:changed)
        expect(version_change.left_value).to eq(1)
        expect(version_change.right_value).to eq(2)
      end

      it 'detects added keys' do
        changes = described_class.diff(left, right)
        added = changes.find { |c| c.path == 'added_key' }
        expect(added).not_to be_nil
        expect(added.type).to eq(:added)
        expect(added.right_value).to eq('new')
      end

      it 'detects removed keys' do
        changes = described_class.diff(left, right)
        removed = changes.find { |c| c.path == 'removed_key' }
        expect(removed).not_to be_nil
        expect(removed.type).to eq(:removed)
        expect(removed.left_value).to eq('gone')
      end

      it 'detects nested changes' do
        changes = described_class.diff(left, right)
        host_change = changes.find { |c| c.path == 'database.host' }
        expect(host_change).not_to be_nil
        expect(host_change.type).to eq(:changed)
        expect(host_change.left_value).to eq('localhost')
        expect(host_change.right_value).to eq('remote')
      end

      it 'detects nested additions' do
        changes = described_class.diff(left, right)
        timeout_add = changes.find { |c| c.path == 'database.timeout' }
        expect(timeout_add).not_to be_nil
        expect(timeout_add.type).to eq(:added)
      end

      it 'ignores unchanged values' do
        changes = described_class.diff(left, right)
        title_change = changes.find { |c| c.path == 'title' }
        expect(title_change).to be_nil
        port_change = changes.find { |c| c.path == 'database.port' }
        expect(port_change).to be_nil
      end
    end

    describe '.additions' do
      it 'returns only additions' do
        adds = Philiprehberger::TomlKit::Diff.additions(left, right)
        expect(adds.all? { |c| c.type == :added }).to be true
        expect(adds.map(&:path)).to include('added_key')
      end
    end

    describe '.removals' do
      it 'returns only removals' do
        rems = Philiprehberger::TomlKit::Diff.removals(left, right)
        expect(rems.all? { |c| c.type == :removed }).to be true
        expect(rems.map(&:path)).to include('removed_key')
      end
    end

    describe '.changes' do
      it 'returns only value changes' do
        chgs = Philiprehberger::TomlKit::Diff.changes(left, right)
        expect(chgs.all? { |c| c.type == :changed }).to be true
        expect(chgs.map(&:path)).to include('version')
      end
    end

    describe '.identical?' do
      it 'returns true for identical hashes' do
        expect(Philiprehberger::TomlKit::Diff.identical?(left, left)).to be true
      end

      it 'returns false for different hashes' do
        expect(Philiprehberger::TomlKit::Diff.identical?(left, right)).to be false
      end
    end

    it 'handles NaN values correctly' do
      a = { 'val' => Float::NAN }
      b = { 'val' => Float::NAN }
      expect(Philiprehberger::TomlKit::Diff.identical?(a, b)).to be true
    end
  end
end
