# frozen_string_literal: true

require "fast_mcp"
require "rack"
require "ruby-pg-extras"
require "rails-pg-extras"

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
    commit,
  ]

  arguments do
    required(:query).filled(:string).description("The query to debug")
  end

  def call(query:)
    connection = RailsPgExtras.connection

    if DENYLIST.any? { |deny| query.downcase.include?(deny) }
      raise "This query is not allowed. It contains a denied keyword. Denylist: #{DENYLIST.join(", ")}"
    end

    connection.execute("BEGIN")
    result = connection.execute("#{query}")
    connection.execute("ROLLBACK")

    result.to_a
  end
end

class ExplainTool < ExplainBaseTool
  description "EXPLAIN a query. It must be an SQL string, without the EXPLAIN prefix"

  def self.name
    "explain_analyze"
  end

  def call(query:)
    super(query: "EXPLAIN #{query}")
  end
end

class ExplainAnalyzeTool < ExplainBaseTool
  description "EXPLAIN ANALYZE a query. It must be an SQL string, without the EXPLAIN ANALYZE prefix"

  def self.name
    "explain_analyze"
  end

  def call(query:)
    super(query: "EXPLAIN ANALYZE #{query}")
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
    def self.build
      app = lambda do |_env|
        [200, { "Content-Type" => "text/html" },
         ["<html><body><h1>Hello from Rack!</h1><p>This is a simple Rack app with MCP middleware.</p></body></html>"]]
      end

      # Create the MCP middleware
      mcp_app = FastMcp.rack_middleware(
        app,
        name: "rails-pg-extras-mcp", version: RailsPgExtrasMcp::VERSION,
        path_prefix: "/pg-extras-mcp",
        logger: Logger.new($stdout),
      ) do |server|
        server.register_tools(DiagnoseTool)
        server.register_tools(MissingFkConstraintsTool)
        server.register_tools(MissingFkIndexesTool)
        server.register_tools(*QUERY_TOOL_CLASSES)
        server.register_tools(ExplainTool) if ENV["PG_EXTRAS_MCP_EXPLAIN_ENABLED"] == "true"
        server.register_tools(ExplainAnalyzeTool) if ENV["PG_EXTRAS_MCP_EXPLAIN_ANALYZE_ENABLED"] == "true"

        server.register_resource(ReadmeResource)

        Rack::Builder.new { run mcp_app }
      end
    end
  end
end
