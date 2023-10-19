# frozen_string_literal: true

module PgdumpScrambler
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/pgdump_scrambler_tasks.rake', __dir__)
    end
  end
end
