# frozen_string_literal: true
namespace :pgdump_scrambler do
  desc 'create table from db'
  task from_db: :environment do
    PgdumpScrambler::TableSet.from_db.write_file('pgdump_scrambler.yml')
  end
end