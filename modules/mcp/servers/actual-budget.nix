
# Actual Budget MCP - Saga
{ ... }:

{
  services.hermes-agent.mcpServers.actual-budget = {
    enabled = true;

    url = "http://saga.fiordland-gar.ts.net:3001/mcp";

    headers.Authorization =
      "Bearer \${ACTUAL_MCP_TOKEN}";

    timeout = 120;

    tools.include = [
      "get-accounts"
      "get-transactions"
      "balance-history"
      "spending-by-category"
      "monthly-summary"
      "budget-vs-actual"
      "net-worth"
      "category-trends"
      "spending-by-payee"
      "cash-flow"
      "get-grouped-categories"
      "get-payees"
    ];
  };
}
