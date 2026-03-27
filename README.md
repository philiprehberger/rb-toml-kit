# philiprehberger-toml_kit

[![Tests](https://github.com/philiprehberger/rb-toml-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-toml-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-toml_kit.svg)](https://rubygems.org/gems/philiprehberger-toml_kit)
[![License](https://img.shields.io/github/license/philiprehberger/rb-toml-kit)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

TOML v1.0 parser and serializer for Ruby

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

## API

| Method | Description |
|--------|-------------|
| `TomlKit.parse(string)` | Parse a TOML string into a Hash |
| `TomlKit.load(path)` | Parse a TOML file into a Hash |
| `TomlKit.dump(hash)` | Serialize a Hash to a TOML string |
| `TomlKit.save(hash, path)` | Write a Hash as a TOML file |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

[MIT](LICENSE)
