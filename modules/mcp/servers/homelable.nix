
# modules/mcp/servers/homelable.nix
{ ... }:

{
  services.hermes-agent.mcpServers.homelable = {
    enabled = true;

    # Homelable MCP draait op Sif.
    # Rechtstreeks via LAN, zonder Tailscale Service.
    url = "http://sif:8001/mcp/";

    headers = {
      "X-API-Key" = "\${HOMELABLE_MCP_API_KEY}";
    };

    timeout = 120;
  };
}
