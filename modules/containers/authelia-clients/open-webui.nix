
{ secret }:
{
  secretKey = "authelia/oidc/open_webui_client_secret_hash";

  yaml = ''
    - client_id: open-webui
      client_name: Open WebUI
      client_secret: "${secret "authelia/oidc/open_webui_client_secret_hash"}"
      public: false
      authorization_policy: one_factor
      require_pkce: true
      pkce_challenge_method: S256
      redirect_uris:
        - https://ai.gladsheimr.nl/oauth/oidc/callback
        - https://openwebui.fiordland-gar.ts.net/oauth/oidc/callback
        - https://openwebui.fiordland-gar.ts.net:443/oauth/oidc/callback
      scopes:
        - openid
        - profile
        - email
        - groups
      response_types:
        - code
      grant_types:
        - authorization_code
      token_endpoint_auth_method: client_secret_basic
  '';
}
