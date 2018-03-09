# frozen_string_literal: true
require 'yaml'
require 'config/table'

module PgdumpScrambler
  class Config
    IGNORED_ACTIVE_RECORD_TABLES = %w[ar_internal_metadata schema_migrations].freeze
    IGNORED_ACTIVE_RECORD_COLUMNS = %w[id created_at updated_at].to_set.freeze
    IGNORED_ACTIVE_RECORD_COLUMNS_REGEXPS = [/_id\z/].freeze
    KEY_DUMP_PARH = 'dump_path'
    KEY_TABLES = 'tables'
    attr_reader :dump_path

    def initialize(tables, dump_path)
      @table_hash = tables.sort_by(&:name).map { |table| [table.name, table] }.to_h
      @dump_path = dump_path
    end

    def table_names
      @table_hash.keys
    end

    def table(name)
      @table_hash[name]
    end

    def tables
      @table_hash.values
    end

    def update_with(other)
      new_tables = @table_hash.map do |_, table|
        if other_table = other.table(table.name)
          table.update_with(other_table)
        else
          table
        end
      end
      new_tables += (other.table_names - table_names).map { |table_name| other.table(table_name) }
      Config.new(new_tables, @dump_path)
    end

    def unspecified_columns
      @table_hash.map do |_, table|
        [table.name, table.unspecifiled_columns]
      end.to_h
    end

    def write(io)
      yml = {}
      yml[KEY_DUMP_PARH] = @dump_path
      yml[KEY_TABLES] = @table_hash.map do |_, table|
        columns = table.columns
        unless columns.empty?
          [
            table.name,
            columns.map { |column| [column.name, column.scramble_method] }.to_h,
          ]
        end
      end.compact.to_h
      YAML.dump(yml, io)
    end
    
    def write_file(path)
      File.open(path, 'w') do |io|
        write(io)
      end
    end

    def obfuscator_options
      tables.map(&:options).reject(&:empty?).join(' ')
    end

    class << self
      def read(io)
        yml = YAML.load(io)
        if yml['tables']
          tables = yml['tables'].map do |table_name, columns|
            Table.new(
              table_name, 
              columns.map { |name, scramble_method| Column.new(name, scramble_method) }
            )
          end
        else
          table = []
        end
        Config.new(tables, yml[KEY_DUMP_PARH])
      end

      def read_file(path)
        open(path, 'r') do |f|
          read(f)
        end
      end

      if defined?(Rails)
        def from_db
          table_names = ActiveRecord::Base.connection.tables.sort - IGNORED_ACTIVE_RECORD_TABLES
          tables = table_names.map do |table_name|
            klass = table_name.classify.constantize rescue nil
            if klass
              columns = klass.columns.map(&:name).reject do |name|
                IGNORED_ACTIVE_RECORD_COLUMNS.member?(name) || 
                  IGNORED_ACTIVE_RECORD_COLUMNS_REGEXPS.any? { |regexp| regexp.match?(name) }
              end.map do |name| 
                Column.new(name) 
              end
              Table.new(table_name, columns)  
            end
          end.compact
          Config.new(tables, 'scrambled.dump')
        end
      end
    end
  end
end