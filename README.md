# Rails PG Extras MCP [![Gem Version](https://badge.fury.io/rb/rails-pg-extras-mcp.svg)](https://badge.fury.io/rb/rails-pg-extras-mcp) [![GH Actions](https://github.com/pawurb/rails-pg-extras-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/pawurb/rails-pg-extras-mcp/actions)


MCP ([Model Context Protocol](https://modelcontextprotocol.io/introduction)) interface for [rails-pg-extras](https://github.com/pawurb/rails-pg-extras) gem. 

A tool for those adventurous enough to connect LLMs directly to the database.

## Installation

```bash
bundle add rails-pg-extras
bundle add rails-pg-extras-mcp
```

Library supports MCP protocol via HTTP SSE interface. 

`config/routes.rb`

```ruby
# Authentication is not yet supported
mount RailsPgExtras.mcp_app, at: "pg-extras-mcp"
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
        "http://localhost:3000/pg-extras-mcp/sse"
      ]
    }
  }
}
```

You can now ask LLM questions about the metadata and performance metrics of your database.

![LLM interface](https://github.com/pawurb/rails-pg-extras/raw/main/pg-extras-mcp.png)

## Status

Project is in an early beta, so proceed with caution.