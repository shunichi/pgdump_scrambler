# frozen_string_literal: true

require 'open3'
module PgdumpScrambler
  class Dumper
    def initialize(config, db_config = {})
      @db_config = db_config.empty? ? load_database_yml : config
      @config = config
      @output_path = config.dump_path
    end

    def run
      puts 'executing pg_dump...'
      puts full_command
      raise 'pg_dump failed!' unless system(full_command)

      puts 'done!'
    end

    private

    def full_command
      [pgdump_command, obfuscator_command, 'gzip -c'].compact.join(' | ') + "> #{@output_path}"
    end

    def obfuscator_command
      return unless (options = @config.obfuscator_options)

      command = File.expand_path('../../bin/pgdump-obfuscator', __dir__)
      "#{command} #{options}"
    end

    def pgdump_command
      command = []
      command << "PGPASSWORD=#{Shellwords.escape(@db_config['password'])}" if @db_config['password']
      command << 'pg_dump'
      command << @config.pgdump_args if @config.pgdump_args
      command << "--username=#{Shellwords.escape(@db_config['username'])}" if @db_config['username']
      command << "--host='#{@db_config['host']}'" if @db_config['host']
      command << "--port='#{@db_config['port']}'" if @db_config['port']
      if @config.exclude_tables.present?
        command << @config.exclude_tables.map do |exclude_table|
          "--exclude-table-data=#{exclude_table}"
        end.join(' ')
      end
      command << @db_config['database']
      command.join(' ')
    end

    def load_database_yml
      return unless defined?(Rails)

      db_config = YAML.safe_load_file(
        Rails.root.join('config', 'database.yml'),
        permitted_classes: [],
        permitted_symbols: [],
        aliases: true
      )
      db_config[Rails.env]
    end
  end
end
