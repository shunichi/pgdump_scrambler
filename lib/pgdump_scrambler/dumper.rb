# frozen_string_literal: true

require 'pgdump_scrambler/utils'
require 'open3'

module PgdumpScrambler
  class Dumper
    def initialize(config, db_config = {})
      @db_config = db_config.empty? ? load_database_yml : db_config
      @config = config
      @output_path = config.dump_path
    end

    def run
      puts 'Executing pg_dump...'
      puts full_command
      raise 'pg_dump failed!' unless system(env_vars, full_command)

      puts 'Done!'
    end

    private

    def env_vars
      vars = {}
      vars['PGPASSWORD'] = @db_config['password'] if @db_config['password']
      vars
    end

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

      db_config = Utils.load_yaml_with_erb(Rails.root.join('config', 'database.yml'))
      db_config[Rails.env]
    end
  end
end
