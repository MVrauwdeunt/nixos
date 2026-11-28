{ ... }:

{
  services.hermes-agent.mcpServers.allos = {
    enabled = true;

    url = "https://saga.fiordland-gar.ts.net:8765/mcp";

    headers.Authorization =
      "Bearer \${ALLOS_MCP_TOKEN}";

    timeout = 60;
    connect_timeout = 15;
  };
}
