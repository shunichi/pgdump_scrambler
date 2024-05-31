# frozen_string_literal: true

require 'pgdump_scrambler/version'
require 'pgdump_scrambler/config'
require 'pgdump_scrambler/dumper'
require 'pgdump_scrambler/s3_uploader'
require 'pgdump_scrambler/railtie' if defined?(Rails)

module PgdumpScrambler
end
