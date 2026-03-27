# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
