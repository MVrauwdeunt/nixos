
"""Allos MCP server using the official MCP Python SDK."""

import os

from mcp.server.fastmcp import FastMCP
from db import AllosDB

db = AllosDB(
    os.environ.get("ALLOS_DB_PATH", "/data/allos.db"),
    int(os.environ["ALLOS_PROFILE_ID"]),
)

mcp = FastMCP(
    "allos-mcp",
    host="0.0.0.0",
    port=8765,
    stateless_http=True,
    json_response=True,
)


@mcp.tool()
def allos_catalog() -> list[dict]:
    """List available health datasets and fields."""
    return db.catalog()


@mcp.tool()
def allos_metrics() -> list[dict]:
    """List available health metric types and counts."""
    return db.metrics()


@mcp.tool()
def allos_read(
    table: str,
    start: str | None = None,
    end: str | None = None,
    limit: int = 50,
) -> list[dict]:
    """
    Read health measurements from the authorized profile.

    Dates use YYYY-MM-DD.
    Maximum 100 records per request.
    """
    return db.read(
        table=table,
        start=start,
        end=end,
        limit=limit,
    )


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
