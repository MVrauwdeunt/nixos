
# modules/hermes/mcp/servers/allos.nix
#
# Direct MCP connection from PULSE to Allos on Saga.
# Uses the existing Tailscale network.

{ ... }:

{
  services.hermes-agent.mcpServers.allos = {
    enabled = true;

    # Replace with Saga's Tailscale IPv4 address.
    url = "http://100.89.53.60:8765/mcp";

    timeout = 60;
    connect_timeout = 15;
  };
}
