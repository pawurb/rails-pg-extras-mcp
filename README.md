# Rails PG Extras MCP [![Gem Version](https://badge.fury.io/rb/rails-pg-extras-mcp.svg)](https://badge.fury.io/rb/rails-pg-extras-mcp) [![GH Actions](https://github.com/pawurb/rails-pg-extras-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/pawurb/rails-pg-extras-mcp/actions)

MCP ([Model Context Protocol](https://modelcontextprotocol.io/introduction)) interface for [rails-pg-extras](https://github.com/pawurb/rails-pg-extras) gem. Easily explore PostgreSQL metadata and debug performance issues. Check for table bloat, slow queries, unused indexes, and more. Run `EXPLAIN ANALYZE` on bottlenecks and get clear, LLM-powered insights to optimize your database. 

Use a minimally privileged, [read-only user](#least-responsibility) to eliminate the risk of data modification or exposure.

Check out [this post](https://pawelurbanek.com/rails-postgresql-mcp) for more in-depth info on the project.

![LLM interface](https://github.com/pawurb/rails-pg-extras/raw/main/pg-extras-mcp.png)

## Installation

```bash
bundle add rails-pg-extras-mcp
```

The library supports MCP protocol via HTTP SSE interface. 

`config/routes.rb`

```ruby
mount RailsPgExtrasMcp::App.build, at: "pg_extras_mcp"
```

with optional authorization:

```ruby
opts = { auth_token: "secret" }
mount RailsPgExtrasMcp::App.build(opts), at: "pg_extras_mcp"
```

Refer to the [fast-mcp docs](https://github.com/yjacquin/fast-mcp) for a complete list of supported options (the `opts` hash is passed directly as-is). For production deployments, you'll likely need a similar config:

```ruby
opts = { allowed_origins: [ /.*./ ], allowed_ips: [ "*" ], auth_token: "secret", localhost_only: false }
mount RailsPgExtrasMcp::App.build(opts) at: "pg_extras_mcp"
```

Next, install [mcp-remote](https://github.com/geelen/mcp-remote):

```bash
npm install -g mcp-remote
```

and in your LLM of choice:

```json
{
  "mcpServers": {
    "pg-extras": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:3000/pg_extras_mcp/sse",
        "--header",
        "Authorization: secret"
      ]
    }
  }
}
```

You can now ask LLM questions about the metadata and performance metrics of your database.


## Optional EXPLAIN ANALYZE support

[`calls`](https://github.com/pawurb/rails-pg-extras?tab=readme-ov-file#calls) and [`outliers`](https://github.com/pawurb/rails-pg-extras?tab=readme-ov-file#outliers) methods return a list of bottleneck queries. LLM can get better insights into these queries by performing `EXPLAIN` and `EXPLAIN ANALYZE` analysis. MCP server exposes two optional methods for this purpose: `explain` and `explain_analyze`. 

You can enable them by setting the following `ENV` variables:

`ENV['PG_EXTRAS_MCP_EXPLAIN_ENABLED'] = 'true'`
`ENV['PG_EXTRAS_MCP_EXPLAIN_ANALYZE_ENABLED'] = 'true'`

Enabling these features means that an LLM, can run arbitrary queries in your database. The execution context is wrapped in a transaction and rolled back, so, in theory, any data modification should not be possible. But it's advised to configure a read-only permission if you want to use these features. By specifying `ENV['RAILS_PG_EXTRAS_MCP_DATABASE_URL']` you can overwrite the default Rails ActiveRecord database connection to restrict an access scope:

## Least responsibility 

If you're not planing to use `EXPLAIN ANALYZE` features, you should configure a user with read access only to the metadata tables:

```sql
CREATE ROLE extras_viewer NOLOGIN;
CREATE USER extras_user WITH PASSWORD 'your_password';
GRANT extras_viewer TO extras_user;

GRANT CONNECT ON DATABASE your_db_name TO extras_user;
GRANT USAGE ON SCHEMA public TO extras_user;

GRANT SELECT ON pg_stat_statements TO extras_user;
GRANT SELECT ON pg_stat_activity, pg_locks TO extras_user;
GRANT SELECT ON pg_stat_user_indexes, pg_index TO extras_user;
GRANT SELECT ON pg_stat_all_tables, pg_stat_database, pg_settings, pg_namespace TO extras_user;

GRANT EXECUTE ON FUNCTION pg_relation_size(regclass) TO extras_user;
GRANT EXECUTE ON FUNCTION pg_indexes_size(regclass) TO extras_user;
GRANT EXECUTE ON FUNCTION pg_table_size(regclass) TO extras_user;
GRANT EXECUTE ON FUNCTION pg_total_relation_size(regclass) TO extras_user;
```

You can ask an LLM to check which db user it's connected with using `connections` tool.

## Status

The project is in an early beta, so proceed with caution.
