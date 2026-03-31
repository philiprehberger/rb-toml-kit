# philiprehberger-toml_kit

[![Tests](https://github.com/philiprehberger/rb-toml-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-toml-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-toml_kit.svg)](https://rubygems.org/gems/philiprehberger-toml_kit)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-toml-kit)](https://github.com/philiprehberger/rb-toml-kit/commits/main)

TOML v1.0 parser and serializer for Ruby with comment preservation, schema validation, merging, querying, type coercion, and diffing.

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-toml_kit"
```

Or install directly:

```bash
gem install philiprehberger-toml_kit
```

## Usage

```ruby
require "philiprehberger/toml_kit"

data = Philiprehberger::TomlKit.parse('title = "TOML Example"')
# => {"title" => "TOML Example"}
```

### Parsing Strings

```ruby
toml = <<~TOML
  [database]
  host = "localhost"
  port = 5432
  enabled = true

  [[servers]]
  name = "alpha"
  port = 8001

  [[servers]]
  name = "beta"
  port = 8002
TOML

config = Philiprehberger::TomlKit.parse(toml)
config["database"]["host"]   # => "localhost"
config["servers"][0]["name"]  # => "alpha"
```

### Loading Files

```ruby
config = Philiprehberger::TomlKit.load("config.toml")
```

### Serializing to TOML

```ruby
hash = {
  "title" => "My App",
  "database" => { "host" => "localhost", "port" => 5432 },
  "servers" => [
    { "name" => "alpha", "port" => 8001 },
    { "name" => "beta", "port" => 8002 }
  ]
}

toml_string = Philiprehberger::TomlKit.dump(hash)
```

### Saving to Files

```ruby
Philiprehberger::TomlKit.save(hash, "output.toml")
```

### Supported Types

All TOML v1.0 types are supported:

```ruby
toml = <<~TOML
  str = "hello"
  int = 42
  hex = 0xDEADBEEF
  oct = 0o755
  bin = 0b11010110
  flt = 3.14
  inf_val = inf
  bool = true
  dt = 1979-05-27T07:32:00Z
  date = 1979-05-27
  time = 07:32:00
  arr = [1, 2, 3]
  inline = {x = 1, y = 2}
TOML

data = Philiprehberger::TomlKit.parse(toml)
```

### Comment Preservation

Parse a TOML document while preserving comments for round-trip editing:

```ruby
toml = <<~TOML
  # Application config
  title = "My App"

  # Database settings
  [database]
  host = "localhost" # primary host
TOML

doc = Philiprehberger::TomlKit.parse_with_comments(toml)
doc["title"]                    # => "My App"
doc["database"]["host"]         # => "localhost" (via doc.data)
doc.header_comments             # => ["# Application config"]
doc.comments["database.host"]   # => {inline: "# primary host"}

# Modify and re-serialize with comments intact
doc["title"] = "New App"
output = doc.to_toml
# Comments are preserved in the output
```

### Schema Validation

Define expected structure and validate parsed TOML against it:

```ruby
schema = Philiprehberger::TomlKit::Schema.new(
  "name" => { type: String, required: true },
  "port" => { type: Integer, required: true },
  "database" => {
    type: Hash,
    required: true,
    properties: {
      "host" => { type: String, required: true },
      "port" => { type: Integer }
    }
  },
  "tags" => { type: Array, items: { type: String } }
)

data = Philiprehberger::TomlKit.parse(toml_string)
errors = schema.validate(data)
# => [] if valid, or ["Missing required key: name", ...]

schema.validate!(data) # raises SchemaError if invalid
```

### Merging

Deep merge two TOML hashes with conflict resolution:

```ruby
base = Philiprehberger::TomlKit.parse(base_toml)
overrides = Philiprehberger::TomlKit.parse(override_toml)

# Right-side wins (default)
merged = Philiprehberger::TomlKit.merge(base, overrides)

# Left-side wins
merged = Philiprehberger::TomlKit.merge(base, overrides, strategy: :keep_existing)

# Raise on conflict
merged = Philiprehberger::TomlKit.merge(base, overrides, strategy: :error_on_conflict)
# raises MergeConflictError if keys conflict
```

### Query Support

Access nested values using dot-paths:

```ruby
data = Philiprehberger::TomlKit.parse(toml_string)

Philiprehberger::TomlKit.query(data, "database.host")
# => "localhost"

Philiprehberger::TomlKit.query(data, "servers[0].name")
# => "alpha"

Philiprehberger::TomlKit.query(data, "missing.path", default: "N/A")
# => "N/A"

# Additional Query methods
Philiprehberger::TomlKit::Query.set(data, "database.timeout", 30)
Philiprehberger::TomlKit::Query.exists?(data, "database.host")  # => true
Philiprehberger::TomlKit::Query.delete(data, "database.timeout") # => 30
```

### Type Coercion Hooks

Register custom serializers and deserializers for Ruby types:

```ruby
coercion = Philiprehberger::TomlKit::TypeCoercion.new

coercion.register(
  Symbol,
  tag: "symbol",
  serializer: ->(v) { v.to_s },
  deserializer: ->(v) { v.to_sym }
)

# Serialize: converts symbols to tagged strings
data = { "key" => :hello }
serialized = coercion.coerce_for_serialize(data)
toml = Philiprehberger::TomlKit.dump(serialized)

# Deserialize: converts tagged strings back to symbols
parsed = Philiprehberger::TomlKit.parse(toml)
restored = coercion.coerce_for_deserialize(parsed)
restored["key"] # => :hello
```

### TOML Diff

Compare two TOML documents and report differences:

```ruby
old_config = Philiprehberger::TomlKit.parse(old_toml)
new_config = Philiprehberger::TomlKit.parse(new_toml)

changes = Philiprehberger::TomlKit.diff(old_config, new_config)
changes.each do |change|
  puts "#{change.type}: #{change.path}"
  # => :added, :removed, or :changed
end

# Filter by type
Philiprehberger::TomlKit::Diff.additions(old_config, new_config)
Philiprehberger::TomlKit::Diff.removals(old_config, new_config)
Philiprehberger::TomlKit::Diff.changes(old_config, new_config)

# Check equality
Philiprehberger::TomlKit::Diff.identical?(old_config, new_config)
```

## API

| Method | Description |
|--------|-------------|
| `TomlKit.parse(string)` | Parse a TOML string into a Hash |
| `TomlKit.load(path)` | Parse a TOML file into a Hash |
| `TomlKit.dump(hash)` | Serialize a Hash to a TOML string |
| `TomlKit.save(hash, path)` | Write a Hash as a TOML file |
| `TomlKit.parse_with_comments(string)` | Parse TOML preserving comments, returns `CommentDocument` |
| `TomlKit.query(data, path, default:)` | Dot-path access into nested hashes |
| `TomlKit.merge(left, right, strategy:)` | Deep merge two hashes with conflict resolution |
| `TomlKit.diff(left, right)` | Compare two hashes, returns array of `Diff::Change` |
| `Schema.new(properties)` | Create a schema for validation |
| `Schema#validate(data)` | Validate data, returns array of error strings |
| `Schema#validate!(data)` | Validate data, raises `SchemaError` on failure |
| `Query.get(data, path, default:)` | Retrieve nested value by dot-path |
| `Query.set(data, path, value)` | Set nested value by dot-path |
| `Query.exists?(data, path)` | Check if a dot-path exists |
| `Query.delete(data, path)` | Delete value at dot-path |
| `Diff.diff(left, right)` | Full diff between two hashes |
| `Diff.additions(left, right)` | Keys added in right |
| `Diff.removals(left, right)` | Keys removed from left |
| `Diff.changes(left, right)` | Keys with changed values |
| `Diff.identical?(left, right)` | Check if two hashes are equal |
| `TypeCoercion#register(type, ...)` | Register custom type handler |
| `TypeCoercion#coerce_for_serialize(value)` | Apply serialization coercions |
| `TypeCoercion#coerce_for_deserialize(value)` | Apply deserialization coercions |
| `Merger.merge(left, right, strategy:)` | Merge with strategy |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-toml-kit)

🐛 [Report issues](https://github.com/philiprehberger/rb-toml-kit/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-toml-kit/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
