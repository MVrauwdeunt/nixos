
# modules/mcp/servers/homeassistant.nix
{ ... }:

{
  services.hermes-agent.mcpServers.homeassistant = {
    enabled = true;

    # Home Assistant MCP via Tailscale
    url = "https://5owiilae76quj17nutjt2j2ezplunhsz.ui.nabu.casa/api/mcp";

    # OAuth 2.1 met automatische tokenvernieuwing
    auth = "oauth";

    timeout = 120;
    connect_timeout = 60;
  };
}
