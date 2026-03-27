# frozen_string_literal: true

require_relative 'lib/philiprehberger/toml_kit/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-toml_kit'
  spec.version       = Philiprehberger::TomlKit::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']
  spec.summary       = 'TOML v1.0 parser and serializer for Ruby'
  spec.description   = 'Parse and generate TOML v1.0 documents with full type support including ' \
                       'datetimes, inline tables, and array of tables. Zero dependencies.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-toml-kit'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
