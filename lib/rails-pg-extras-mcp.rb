# frozen_string_literal: true

require "fast_mcp"
require "rack"
require "ruby-pg-extras"
require "rails-pg-extras"
require "rails_pg_extras_mcp/version"

SKIP_QUERIES = %i[
  add_extensions
  pg_stat_statements_reset
  kill_pid
  kill_all
  mandelbrot
]

QUERY_TOOL_CLASSES = RubyPgExtras::QUERIES.reject { |q| SKIP_QUERIES.include?(q) }.map do |query_name|
  Class.new(FastMcp::Tool) do
    description RubyPgExtras.description_for(query_name: query_name)

    define_method :call do
      RailsPgExtras.public_send(query_name, in_format: :hash)
    end

    define_singleton_method :name do
      query_name.to_s
    end
  end
end

class MissingFkConstraintsTool < FastMcp::Tool
  description "Shows missing foreign key constraints"

  def call
    RailsPgExtras.missing_fk_constraints(in_format: :hash)
  end

  def self.name
    "missing_fk_constraints"
  end
end

class MissingFkIndexesTool < FastMcp::Tool
  description "Shows missing foreign key indexes"

  def call
    RailsPgExtras.missing_fk_indexes(in_format: :hash)
  end

  def self.name
    "missing_fk_indexes"
  end
end

class DiagnoseTool < FastMcp::Tool
  description "Performs a health check of the database"

  def call
    RailsPgExtras.diagnose(in_format: :hash)
  end

  def self.name
    "diagnose"
  end
end

class ExplainBaseTool < FastMcp::Tool
  DENYLIST = %w[
    delete,
    insert,
    update,
    truncate,
    drop,
    alter,
    create,
    grant,
    begin,
    commit
  ]

  def call(sql_query: nil)
    connection = RailsPgExtras.connection

    if DENYLIST.any? { |deny| sql_query.downcase.include?(deny) }
      raise "This query is not allowed. It contains a denied keyword. Denylist: #{DENYLIST.join(", ")}"
    end

    # Prevent multiple queries in one request
    sql_query = sql_query.gsub(/;/, "")

    connection.execute("BEGIN;")
    begin
      result = connection.execute("#{sql_query}")
      connection.execute("ROLLBACK;")
      result.to_a
    rescue => e
      connection.execute("ROLLBACK;") rescue nil
      raise e
    end
  end
end

class ExplainTool < ExplainBaseTool
  description "EXPLAIN a query. It must be an SQL string, without the EXPLAIN prefix"

  arguments do
    required(:sql_query).filled(:string).description("The SQL query to debug")
  end

  def self.name
    "explain"
  end

  def call(sql_query:)
    if sql_query.to_s.empty?
      return "sql_query param is required"
    end  

    if sql_query.downcase.include?("analyze")
      raise "This query is not allowed. It contains a denied ANALYZE keyword."
    end

    super(sql_query: "EXPLAIN #{sql_query}")
  end
end

class ExplainAnalyzeTool < ExplainBaseTool
  description "EXPLAIN ANALYZE a query. It must be an SQL string, without the EXPLAIN ANALYZE prefix"

  arguments do
    required(:sql_query).filled(:string).description("The SQL query to debug")
  end

  def self.name
    "explain_analyze"
  end

  def call(sql_query:)
    if sql_query.to_s.empty?
      return "sql_query param is required"
    end  

    super(sql_query: "EXPLAIN ANALYZE #{sql_query}")
  end
end

class IndexInfoTool < FastMcp::Tool
  description "Shows information about table indexes: name, table name, columns, index size, index scans, null frac"

  arguments do
    required(:table_name).filled(:string).description("The table name to get index info for")
  end

  def call(table_name:)
    if table_name.to_s.empty?
      return "table_name param is required"
    end  

    RailsPgExtras.index_info(args: { table_name: table_name }, in_format: :hash)
  end

  def self.name
    "index_info"
  end
end

class TableInfoTool < FastMcp::Tool
  description "Shows information about a table: name, size, cache hit, estimated rows, sequential scans, indexes scans"

  arguments do
    required(:table_name).filled(:string).description("The table name to get info for")
  end

  def call(table_name:)
    if table_name.to_s.empty?
      return "table_name param is required"
    end  

    RailsPgExtras.table_info(args: { table_name: table_name }, in_format: :hash)
  end

  def self.name
    "table_info"
  end
end

class TableSchemaTool < FastMcp::Tool
  description "Shows the schema of a table"

  arguments do
    required(:table_name).filled(:string).description("The table name to get schema for")
  end

  def call(table_name:)
    RailsPgExtras.table_schema(args: { table_name: table_name }, in_format: :hash)
  end

  def self.name
    "table_schema"
  end
end

class ReadmeResource < FastMcp::Resource
  uri "https://raw.githubusercontent.com/pawurb/rails-pg-extras/refs/heads/main/README.md"
  resource_name "README"
  description "The README for RailsPgExtras"
  mime_type "text/plain"

  def content
    File.read(uri)
  end
end

module RailsPgExtrasMcp
  class App
    def self.build(opts = {})
      app = lambda do |_env|
        [200, { "Content-Type" => "text/html" },
         ["<html><body><h1>Hello from Rack!</h1><p>This is a simple Rack app with MCP middleware.</p></body></html>"]]
      end

      default_opts = {
        name: "rails-pg-extras-mcp",
        version: RailsPgExtrasMcp::VERSION,
        path_prefix: "/pg_extras_mcp",
        logger: Logger.new($stdout),
      }

      opts = default_opts.merge(opts)

      rack_method_name = opts[:auth_token].present? ? :authenticated_rack_middleware : :rack_middleware

      # Create the MCP middleware
      FastMcp.public_send(rack_method_name,
                          app,
                          **opts) do |server|
        server.register_tools(DiagnoseTool)
        server.register_tools(MissingFkConstraintsTool)
        server.register_tools(MissingFkIndexesTool)
        server.register_tools(IndexInfoTool)
        server.register_tools(TableInfoTool)
        server.register_tools(TableSchemaTool)
        server.register_tools(*QUERY_TOOL_CLASSES)
        server.register_tools(ExplainTool) if ENV["PG_EXTRAS_MCP_EXPLAIN_ENABLED"] == "true"
        server.register_tools(ExplainAnalyzeTool) if ENV["PG_EXTRAS_MCP_EXPLAIN_ANALYZE_ENABLED"] == "true"

        server.register_resource(ReadmeResource)

        if !ENV["RAILS_PG_EXTRAS_MCP_DATABASE_URL"].to_s.empty?
          RailsPgExtras.database_url = ENV["RAILS_PG_EXTRAS_MCP_DATABASE_URL"]
        end
      end
    end
  end
end
