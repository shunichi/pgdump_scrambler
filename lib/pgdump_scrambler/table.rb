# frozen_string_literal: true
require 'yaml'

module PgdumpScrambler
  class TableSet
    IGNORED_ACTIVE_RECORD_TABLES = %w[ar_internal_metadata schema_migrations].freeze

    def initialize(tables)
      @table_hash = tables.sort_by(&:name).map { |table| [table.name, table] }.to_h
    end

    def [](table_name)
      @table_hash[table_name]
    end

    def table_names
      @table_hash.keys
    end

    def tables
      @table_hash.values
    end

    def merge(other)
      new_tables = @table_hash.map do |_, table|
        if other_table = other[table.name]
          table.merge(other_table)
        else
          table
        end
      end
      new_tables += (other.table_names - table_names).map { |table_name| other[table] }
      TableSet.new(new_tables)
    end

    def write(io)
      hash = @table_hash.map do |_, table|
        [
          table.name,
          table.columns.map { |column| [column.name, column.scramble_method] }.to_h,
        ]
      end.to_h
      YAML.dump(hash, io)
    end
    
    def write_file(path)
      File.open(path, 'w') do |io|
        write(io)
      end
    end

    def obfuscator_options
      tables.map(&:options).join(' ')
    end

    class << self
      def read(io)
        hash = YAML.load(io)
        tables = hash.map do |table_name, columns|
          Table.new(
            table_name, 
            columns.map { |name, scramble_method| Column.new(name, scramble_method) }
          )
        end
        TableSet.new(tables)
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
              columns = klass.columns.map(&:name).map { |name| Column.new(name) }
              Table.new(table_name, columns)  
            end
          end.compact
          TableSet.new(tables)
        end
      end
    end
  end

  class Table
    attr_reader :name

    def initialize(name, columns)
      @name = name
      @column_hash = columns.sort_by(&:name).map { |column| [column.name, column] }.to_h
    end

    def columns
      @column_hash.values
    end

    def [](column_name)
      @column_hash[column_name]
    end

    def merge(other)
      Table.new(name, @column_hash.merge(other.column_hash).values)
    end

    def options
      columns.map(&:option).compact.map { |option| "-c #{name}:#{option}" }.join(' ')
    end

    protected

    attr_reader :column_hash
  end
  
  class Column
    SCRAMBLE_METHODS = %i[unspecified nop bytes sbytes digits email uemail inet].freeze
    NOP_METHODS = %i[unspecified nop].freeze
    attr_reader :name

    def initialize(name, scramble_method = :unspecified)
      scramble_method = scramble_method.to_sym
      unless SCRAMBLE_METHODS.member?(scramble_method)
        raise ArgumentError, "invalid scramble_method: #{scramble_method}"
      end
      @name = name
      @scramble_method = scramble_method
    end

    def scramble_method
      @scramble_method.to_s
    end

    def option
      unless NOP_METHODS.member?(@scramble_method)
        "#{@name}:#{scramble_method}"
      end
    end
  end
end