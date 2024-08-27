# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.3] - 2026-04-08

### Changed
- Align gemspec summary with README description.

## [0.2.2] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-28

### Added

- Comment preservation during round-trip parse/serialize via `TomlKit.parse_with_comments` and `CommentDocument`
- TOML schema validation with `Schema` class supporting required keys, type checks, nested properties, and array items
- TOML merging with conflict resolution strategies (`:override`, `:keep_existing`, `:error_on_conflict`) via `TomlKit.merge`
- Dot-path query support via `TomlKit.query` with array indexing, `Query.set`, `Query.exists?`, and `Query.delete`
- Type coercion hooks via `TypeCoercion` for custom serializer/deserializer registration with optional tagged round-trips
- TOML diff via `TomlKit.diff` to compare two documents reporting additions, removals, and changes

## [0.1.1] - 2026-03-26

### Added

- Add GitHub funding configuration

## [0.1.0] - 2026-03-26

### Added
- Initial release
- TOML v1.0 parser with full type support
- Key types: bare keys, quoted keys, dotted keys
- Value types: strings, integers, floats, booleans, datetimes, arrays, inline tables
- Integer formats: decimal, hexadecimal (0x), octal (0o), binary (0b)
- Special float values: inf, -inf, nan
- Date/time types: offset datetime, local datetime, local date, local time
- Standard tables and array of tables
- Multiline basic and literal strings
- Hash to TOML serializer
- `TomlKit.parse` for parsing TOML strings
- `TomlKit.load` for parsing TOML files
- `TomlKit.dump` for serializing hashes to TOML strings
- `TomlKit.save` for writing hashes to TOML files
