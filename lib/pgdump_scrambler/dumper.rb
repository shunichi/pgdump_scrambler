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
      puts "executing pg_dump..."
      puts full_command
      Open3.popen3(full_command) do |i, o, e, t|
        i.close
        rio = [o, e]
        while rio.any? { |io| !io.eof? }
          ready = IO.select(rio)
          if readable = ready[0]
            readable.each do |r|
              r.each do |line|
                puts line
              end
            end
          end
        end
      end
      puts "done!"
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
      command << "--username=#{Shellwords.escape(@db_config['username'])}" if @db_config['username']
      command << "--host='#{@db_config['host']}'" if @db_config['host']
      command << "--port='#{@db_config['port']}'" if @db_config['port']
      command << @db_config['database']
      command.join(' ')
    end

    def load_database_yml
      if defined?(Rails)
        db_config = open(Rails.root.join('config', 'database.yml'), 'r') do |f|
          YAML.load(f)
        end
        db_config[Rails.env]
      end
    end
  end
end
