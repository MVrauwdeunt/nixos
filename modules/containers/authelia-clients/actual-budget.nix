
{ secret }:
{
  secretKey = "authelia/oidc/actual_budget_client_secret_hash";

  yaml = ''
    - client_id: actual-budget
      client_name: Actual Budget
      client_secret: "${secret "authelia/oidc/actual_budget_client_secret_hash"}"
      public: false
      authorization_policy: two_factor
      redirect_uris:
        - https://budget.fiordland-gar.ts.net/openid/callback
      scopes:
        - openid
        - profile
        - email
      response_types:
        - code
      grant_types:
        - authorization_code
      token_endpoint_auth_method: client_secret_basic
  '';
}
