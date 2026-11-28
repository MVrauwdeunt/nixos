
# modules/hermes/mcp/servers/homelable.nix

{ ... }:

{
  services.hermes-agent.mcpServers.homelable = {
    enabled = true;

    # Homelable MCP on Sif, accessed over the local network.
    url = "http://sif:8001/mcp/";

    headers = {
      "X-API-Key" = "\${HOMELABLE_MCP_API_KEY}";
    };

    timeout = 120;
  };
}
