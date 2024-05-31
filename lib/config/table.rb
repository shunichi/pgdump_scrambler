# frozen_string_literal: true

module PgdumpScrambler
  class Config
    class Table
      attr_reader :name

      def initialize(name, columns)
        @name = name
        @column_hash = columns.sort_by(&:name).to_h { |column| [column.name, column] }
      end

      def columns
        @column_hash.values
      end

      def [](column_name)
        @column_hash[column_name]
      end

      def update_with(other)
        Table.new(name, other.column_hash.merge(@column_hash).values)
      end

      def options
        columns.map(&:option).compact.map { |option| "-c #{name}:#{option}" }.join(' ')
      end

      def unspecifiled_columns
        @column_hash.map(&:second).select(&:unspecifiled?).map(&:name)
      end

      protected

      attr_reader :column_hash
    end

    class Column
      SCRAMBLE_METHODS = %w[unspecified nop bytes sbytes digits email uemail inet json nullify empty].freeze
      SCRAMBLE_CONST_REGEXP = /\Aconst\[.+\]\z/
      NOP_METHODS = %w[unspecified nop].freeze
      UNSPECIFIED = 'unspecified'
      attr_reader :name, :scramble_method

      def initialize(name, scramble_method = UNSPECIFIED)
        unless self.class.valid_scramble_method?(scramble_method)
          raise ArgumentError, "invalid scramble_method: #{scramble_method}"
        end

        @name = name
        @scramble_method = scramble_method
      end

      def unspecifiled?
        @scramble_method == UNSPECIFIED
      end

      def option
        return if NOP_METHODS.member?(@scramble_method)

        m = Shellwords.escape(scramble_method)
        "#{@name}:#{m}"
      end

      class << self
        def valid_scramble_method?(scramble_method)
          SCRAMBLE_CONST_REGEXP.match?(scramble_method) || SCRAMBLE_METHODS.member?(scramble_method)
        end
      end
    end
  end
end
