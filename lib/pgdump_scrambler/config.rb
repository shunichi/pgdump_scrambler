# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'set'
require 'config/table'

module PgdumpScrambler
  class Config
    IGNORED_ACTIVE_RECORD_TABLES = %w[ar_internal_metadata schema_migrations].freeze
    IGNORED_ACTIVE_RECORD_COLUMNS = %w[id created_at updated_at].to_set.freeze
    KEY_DUMP_PATH = 'dump_path'
    KEY_TABLES = 'tables'
    KEY_EXCLUDE_TABLES = 'exclude_tables'
    KEY_PGDUMP_ARGS = 'pgdump_args'
    KEY_S3 = 's3'
    DEFAULT_S3_PROPERTIES = {
      'bucket' => 'YOUR_S3_BUCKET',
      'region' => 'YOUR_S3_REGION',
      'prefix' => 'YOUR_S3_PATH_PREFIX',
      'access_key_id' => "<%= ENV['AWS_ACCESS_KEY_ID'] %>",
      'secret_key' => "<%= ENV['AWS_SECRET_KEY'] %>"
    }.freeze
    attr_reader :dump_path, :s3, :resolved_s3, :exclude_tables, :pgdump_args

    def initialize(tables, dump_path, s3, exclude_tables, pgdump_args) # rubocop:disable Naming/MethodParameterName
      @table_hash = tables.sort_by(&:name).to_h { |table| [table.name, table] }
      @dump_path = dump_path
      @s3 = s3
      @resolved_s3 = s3.transform_values { |v| ERB.new(v).result } if s3
      @exclude_tables = exclude_tables
      @pgdump_args = pgdump_args
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
        if (other_table = other.table(table.name))
          table.update_with(other_table)
        else
          table
        end
      end
      new_tables += (other.table_names - table_names).map { |table_name| other.table(table_name) }
      Config.new(new_tables, @dump_path, @s3, @exclude_tables, @pgdump_args)
    end

    def unspecified_columns
      @table_hash.map do |_, table|
        columns = table.unspecifiled_columns
        [table.name, columns] unless columns.empty?
      end.compact.to_h
    end

    def write(io)
      yml = {}
      yml[KEY_DUMP_PATH] = @dump_path
      yml[KEY_S3] = @s3 if @s3
      yml[KEY_EXCLUDE_TABLES] = @exclude_tables if @exclude_tables.size.positive?
      yml[KEY_TABLES] = @table_hash.map do |_, table|
        columns = table.columns
        next if columns.empty?

        [
          table.name,
          columns.to_h { |column| [column.name, column.scramble_method] }
        ]
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
        yml = YAML.safe_load(io, permitted_classes: [], permitted_symbols: [], aliases: true)
        tables =
          if yml[KEY_TABLES]
            yml[KEY_TABLES].map do |table_name, columns|
              Table.new(
                table_name,
                columns.map { |name, scramble_method| Column.new(name, scramble_method) }
              )
            end
          else
            []
          end
        Config.new(tables, yml[KEY_DUMP_PATH], yml[KEY_S3], yml[KEY_EXCLUDE_TABLES] || [], yml[KEY_PGDUMP_ARGS])
      end

      def read_file(path)
        File.open(path, 'r') do |f|
          read(f)
        end
      end

      if defined?(Rails)
        def from_db
          if defined?(Zeitwerk) && Rails.autoloaders.zeitwerk_enabled?
            Zeitwerk::Loader.eager_load_all
          else
            Rails.application.eager_load!
          end
          klasses_by_table = ActiveRecord::Base.descendants.to_h { |klass| [klass.table_name, klass] }
          table_names = ActiveRecord::Base.connection.tables.sort - IGNORED_ACTIVE_RECORD_TABLES
          tables = table_names.map do |table_name|
            klass = klasses_by_table[table_name]
            next unless klass

            column_names = klass.columns.map(&:name).reject do |name|
              IGNORED_ACTIVE_RECORD_COLUMNS.member?(name)
            end
            columns = column_names.map { |name| Column.new(name) }
            Table.new(table_name, columns)
          end.compact
          Config.new(tables, 'scrambled.dump.gz', Config::DEFAULT_S3_PROPERTIES, [], nil)
        end
      end
    end
  end
end
