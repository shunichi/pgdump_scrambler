# frozen_string_literal: true
require 'open3'
require 'erb'

module PgdumpScrambler
  class Dumper
    def initialize(config, db_config = {})
      @db_config = db_config.empty? ? load_database_yml : config
      @config = config
      @output_path = config.dump_path
    end

    def run
      puts "executing pg_dump..."
      puts full_command
      if system(full_command)
        puts "done!"
      else
        raise "pg_dump failed!"
      end
    end

    private

    def full_command
      [pgdump_command, obfuscator_command, 'gzip -c'].compact.join(' | ') + "> #{@output_path}"
    end

    def obfuscator_command
      if options = @config.obfuscator_options
        command = File.expand_path('../../../bin/pgdump-obfuscator', __FILE__)
        "#{command} #{options}"
      end
    end

    def pgdump_command
      command = []
      command << "PGPASSWORD=#{Shellwords.escape(@db_config['password'])}" if @db_config['password']
      command << 'pg_dump'
      command << @config.pgdump_args if @config.pgdump_args
      command << "--username=#{Shellwords.escape(@db_config['username'])}" if @db_config['username']
      command << "--host='#{@db_config['host']}'" if @db_config['host']
      command << "--port='#{@db_config['port']}'" if @db_config['port']
      command << @config.exclude_tables.map { |exclude_table| "--exclude-table-data=#{exclude_table}" }.join(' ') if @config.exclude_tables.present?
      command << @db_config['database']
      command.join(' ')
    end

    def load_database_yml
      if defined?(Rails)
        database_yaml_file = File.read(Rails.root.join('config', 'database.yml'))
        database_yaml_body = ERB.new(database_yaml_file).result
        # NOTE: Ruby3.1以降ではYAML.loadが廃止されたので、YAML.safe_loadを使う。
        db_config = if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')
                      YAML.safe_load(database_yaml_body, aliases: true)
                    else
                      YAML.load(database_yaml_body)
                    end

        db_config[Rails.env].key?('read_replica') ? db_config[Rails.env]['read_replica'] : db_config[Rails.env]
      end
    end
  end
end
