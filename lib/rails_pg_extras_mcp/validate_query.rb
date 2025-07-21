# frozen_string_literal: true

require 'pg_query'

class ValidateQuery
  InvalidQueryError = Class.new(StandardError)

  DENYLIST = %w[
    delete
    insert
    update
    truncate
    drop
    alter
    create
    grant
    begin
    commit
    explain
    analyze
  ].freeze

  def initialize(sql_query)
    @sql_query = sql_query.to_s.strip
  end

  def call
    raise InvalidQueryError, "Query is empty" if @sql_query.empty?

    if DENYLIST.any? { |word| @sql_query.downcase.include?(word) }
      raise InvalidQueryError, "Query contains denied keyword. Denylist: #{DENYLIST.join(', ')}"
    end

    begin
      tree = PgQuery.parse(@sql_query)
    rescue PgQuery::ParseError => e
      raise InvalidQueryError, "Invalid SQL syntax: #{e.message}"
    end

    if tree.tree.stmts.size > 1
      raise InvalidQueryError, "Multiple SQL statements are not allowed"
    end

    unless tree.tree.stmts.all? { |stmt| stmt.stmt.select_stmt }
      raise InvalidQueryError, "Only SELECT statements are allowed"
    end

    true
  end
end
