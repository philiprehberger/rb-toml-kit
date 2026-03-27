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
end
