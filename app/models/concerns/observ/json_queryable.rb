# frozen_string_literal: true

module Observ
  # Provides database-agnostic JSON querying capabilities.
  #
  # This concern allows models with JSON/JSONB columns to query nested
  # JSON fields in a way that works across different database adapters
  # (PostgreSQL, SQLite, MySQL, etc.)
  #
  # Usage:
  #   class Session < ApplicationRecord
  #     include Observ::JsonQueryable
  #   end
  #
  #   # Query by JSON field
  #   Session.where_json(:metadata, :agent_type, "MyAgent")
  #   Session.where_json(:metadata, "nested.path", "value")
  #
  module JsonQueryable
    extend ActiveSupport::Concern

    class_methods do
      # Query records where a JSON column's nested field equals a value.
      #
      # @param column [Symbol] The JSON column name
      # @param path [String, Symbol] The JSON path (e.g., "agent_type" or "nested.path")
      # @param value [String, Integer, Boolean] The value to match
      # @return [ActiveRecord::Relation]
      #
      # @example Simple path
      #   Session.where_json(:metadata, :agent_type, "MyAgent")
      #
      # @example Nested path
      #   Session.where_json(:metadata, "config.mode", "production")
      #
      def where_json(column, path, value)
        json_query = JsonQuery.new(connection, table_name, column, path)
        where(json_query.to_sql, value)
      end

      # Query records where a JSON column's nested field is not null.
      #
      # @param column [Symbol] The JSON column name
      # @param path [String, Symbol] The JSON path
      # @return [ActiveRecord::Relation]
      #
      def where_json_present(column, path)
        json_query = JsonQuery.new(connection, table_name, column, path)
        where("#{json_query.extract_sql} IS NOT NULL")
      end

      # Pluck values from a JSON column's nested field.
      #
      # @param column [Symbol] The JSON column name
      # @param path [String, Symbol] The JSON path
      # @return [Array]
      #
      def pluck_json(column, path)
        json_query = JsonQuery.new(connection, table_name, column, path)
        pluck(Arel.sql(json_query.extract_sql))
      end
    end

    # Internal class that generates database-specific SQL for JSON queries.
    class JsonQuery
      attr_reader :connection, :table_name, :column, :path

      def initialize(connection, table_name, column, path)
        @connection = connection
        @table_name = table_name
        @column = column.to_s
        @path = path.to_s
      end

      # Returns SQL fragment for WHERE clause comparison (with placeholder)
      def to_sql
        "#{extract_sql} = ?"
      end

      # Returns SQL fragment for extracting the JSON value
      def extract_sql
        case adapter_name
        when /postgresql/i
          postgresql_extract
        when /sqlite/i
          sqlite_extract
        when /mysql|mariadb/i
          mysql_extract
        else
          # Fallback for unknown adapters - try PostgreSQL syntax
          postgresql_extract
        end
      end

      private

      def adapter_name
        connection.adapter_name
      end

      def quoted_column
        "#{quoted_table}.#{connection.quote_column_name(column)}"
      end

      def quoted_table
        connection.quote_table_name(table_name)
      end

      # PostgreSQL: Uses ->> operator for text extraction
      # For nested paths like "a.b.c", chains -> operators: col->'a'->'b'->>'c'
      def postgresql_extract
        parts = path.split(".")

        if parts.size == 1
          "#{quoted_column}->>'#{parts.first}'"
        else
          # Chain -> operators for intermediate keys, ->> for final key
          intermediate = parts[0..-2].map { |p| "->#{connection.quote(p)}" }.join
          "#{quoted_column}#{intermediate}->>#{connection.quote(parts.last)}"
        end
      end

      # SQLite: Uses json_extract function
      # Path format: $.key or $.nested.path
      def sqlite_extract
        json_path = "$." + path.gsub(".", ".")
        "json_extract(#{quoted_column}, '#{json_path}')"
      end

      # MySQL/MariaDB: Uses JSON_EXTRACT or ->> operator (MySQL 5.7.13+)
      # Path format: $.key or $.nested.path
      def mysql_extract
        json_path = "$." + path.gsub(".", ".")
        "JSON_UNQUOTE(JSON_EXTRACT(#{quoted_column}, '#{json_path}'))"
      end
    end
  end
end
