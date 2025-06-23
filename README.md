# Rails PG Extras MCP [![Gem Version](https://badge.fury.io/rb/rails-pg-extras-mcp.svg)](https://badge.fury.io/rb/rails-pg-extras-mcp) [![GH Actions](https://github.com/pawurb/rails-pg-extras-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/pawurb/rails-pg-extras-mcp/actions)

MCP ([Model Context Protocol](https://modelcontextprotocol.io/introduction)) interface for [rails-pg-extras](https://github.com/pawurb/rails-pg-extras) gem. It enables PostgreSQL metadata and performance analysis with a simple LLM prompt.  

![LLM interface](https://github.com/pawurb/rails-pg-extras/raw/main/pg-extras-mcp.png)

## Installation

```bash
bundle add rails-pg-extras
bundle add rails-pg-extras-mcp
```

The library supports MCP protocol via HTTP SSE interface. 

`config/routes.rb`

```ruby
mount RailsPgExtras.mcp_app, at: "pg-extras-mcp"
```

with optional authorization:

```ruby
mount RailsPgExtras.mcp_app(auth_token: "secret"), at: "pg-extras-mcp"
```

Install [mcp-remote](https://github.com/geelen/mcp-remote):

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
        "http://localhost:3000/pg-extras-mcp/sse",
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

Enabling these features means that an LLM, can run arbitrary queries in your database. The execution context is wrapped in a transaction and rolled back, so, in theory, any data modification should not be possible. But it's advised to configure a read-only permission if you want to use these features. By specifying `ENV['RAILS_PG_EXTRAS_DATABASE_URL']` you can overwrite the default Rails ActiveRecord database connection to restrict an access scope.

## Status

The project is in an early beta, so proceed with caution.
