# frozen_string_literal: true
require "pgdump_scrambler/version"
require "pgdump_scrambler/config"
require "pgdump_scrambler/dumper"
if defined?(Rails)
  require 'pgdump_scrambler/railtie'
end

module PgdumpScrambler
end
