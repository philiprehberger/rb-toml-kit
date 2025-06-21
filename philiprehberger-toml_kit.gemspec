# frozen_string_literal: true

require_relative 'lib/philiprehberger/toml_kit/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-toml_kit'
  spec.version = Philiprehberger::TomlKit::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']
  spec.summary = 'TOML v1.0 parser and serializer for Ruby with comment preservation, schema validation, ' \
                 'merging, querying, type coercion, and diffing'
  spec.description = 'Parse and generate TOML v1.0 documents with full type support including ' \
                     'datetimes, inline tables, and array of tables. Zero dependencies.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-toml_kit'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-toml-kit'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-toml-kit/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-toml-kit/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
