# ---------------------------------------------------------------------------
# CLAW Website — OIDC provider (Auth.js manages the session, not Authentik)
# ---------------------------------------------------------------------------

resource "authentik_provider_oauth2" "claw_website" {
  name               = "CLAW Website"
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id

  client_id = "claw-website"

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://claw.${local.base_domain}/api/auth/callback/authentik"
    }
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]

  access_token_validity = local.app_token_validity

  lifecycle {
    ignore_changes = [jwt_federation_providers, jwt_federation_sources]
  }
}

resource "authentik_application" "claw_website" {
  name               = "CLAW Website"
  slug               = "claw-website"
  protocol_provider  = authentik_provider_oauth2.claw_website.id
  meta_launch_url    = "https://claw.${local.base_domain}"
  meta_description   = "Convention Lille Anthro Weekend"
  policy_engine_mode = "any"
  open_in_new_tab    = true
}

# Separate from secret/claw-website so Terraform owns only the keys it generates.
resource "vault_kv_secret_v2" "claw_website_authentik" {
  mount = "secret"
  name  = "authentik/claw-website"

  data_json = jsonencode({
    AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.claw_website.client_id
    AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.claw_website.client_secret
    AUTHENTIK_ISSUER        = "https://authentik.${local.base_domain}/application/o/claw-website/"
  })
}
