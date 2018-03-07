# frozen_string_literal: true
require "pgdump_scrambler/version"
require "pgdump_scrambler/table"
if defined?(Rails)
  require 'pgdump_scrambler/railtie'
end

module PgdumpScrambler
end
