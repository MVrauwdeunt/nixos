
{ secret }:
{
  secretKey = "authelia/oidc/wallos_client_secret_hash";

  yaml = ''
    - client_id: wallos
      client_name: Wallos
      client_secret: "${secret "authelia/oidc/wallos_client_secret_hash"}"
      public: false
      authorization_policy: two_factor
      require_pkce: false
      redirect_uris:
        - https://wallos.fiordland-gar.ts.net/index.php
      scopes:
        - openid
        - email
        - profile
      response_types:
        - code
      grant_types:
        - authorization_code
      token_endpoint_auth_method: client_secret_post
  '';
}
