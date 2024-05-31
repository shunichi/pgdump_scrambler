# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pgdump_scrambler/version'

Gem::Specification.new do |spec|
  spec.name          = 'pgdump_scrambler'
  spec.version       = PgdumpScrambler::VERSION
  spec.authors       = ['Shunichi Ikegami']
  spec.email         = ['sike.tm@gmail.com']

  spec.summary       = 'Scramble pg_dump columns'
  spec.description   = 'Scramble pg_dump columns.'
  spec.homepage      = 'https://github.com/shunichi/pgdump_scrambler'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/shunichi/pgdump_scrambler'
  spec.metadata['changelog_uri'] = 'https://github.com/shunichi/pgdump_scrambler/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
