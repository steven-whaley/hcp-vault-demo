locals {
  logout_redirect_url = format("%s:%s", data.tfe_outputs.hcp_vault_demo_init.values.vault_url, "3000")
  callback_url        = format("%s%s", data.tfe_outputs.hcp_vault_demo_init.values.vault_url, "/ui/vault/auth/okta_oidc/oidc/callback")
}

resource "okta_app_oauth" "okta_app" {
  label                     = "HCP Vault Demo"
  type                      = "web"
  post_logout_redirect_uris = [local.logout_redirect_url]
  redirect_uris             = [local.callback_url, "http://localhost:8250/oidc/callback"]
  grant_types               = ["implicit", "authorization_code"]
  response_types = ["code", "id_token"]

  groups_claim {
    type        = "FILTER"
    filter_type = "REGEX"
    name        = "groups"
    value       = ".*"
  }
}

resource "okta_app_oauth_api_scope" "example" {
  app_id = okta_app_oauth.okta_app.id
  issuer = "https://integrator-6015579.okta.com"
  scopes = ["okta.groups.read", "okta.users.read.self"]
}

resource "okta_group" "vault_admin_users" {
  name        = "Vault Admin Users"
  description = "Vault Admin Users Group"
}

resource "okta_app_group_assignment" "vault_admin_users" {
  app_id   = okta_app_oauth.okta_app.id
  group_id = okta_group.vault_admin_users.id
}

resource "okta_group_memberships" "vault_admin_users" {
  group_id = okta_group.vault_admin_users.id
  users = [
    "00uxe8kwvfCHvQu2L697"
  ]
}

resource "vault_jwt_auth_backend" "okta_oidc" {
    description         = "Okta OIDC authentication"
    path                = "okta_oidc"
    oidc_discovery_url  = "https://integrator-6015579.okta.com"
    oidc_client_id        = okta_app_oauth.okta_app.client_id
    oidc_client_secret = okta_app_oauth.okta_app.client_secret
    default_role = "default-role"
}

resource "vault_jwt_auth_backend_role" "default-role" {
  backend         = vault_jwt_auth_backend.okta_oidc.path
  role_name       = "default-role"
  token_policies  = ["default"]
  allowed_redirect_uris = [local.callback_url, "http://localhost:8250/oidc/callback"]
  bound_audiences = ["0oaz6mxcdiSSIDQUl697"]

  groups_claim = "groups"
  user_claim      = "email"
  oidc_scopes = ["groups", "email", "profile"]
}

resource "vault_identity_group" "vault_admin_group" {
  name     = "vault_admins"
  type     = "external"
  policies = ["hcp-root"]
}

resource "vault_identity_group_alias" "group-alias" {
  name           = "Vault Admin Users"
  mount_accessor = vault_jwt_auth_backend.okta_oidc.accessor
  canonical_id   = vault_identity_group.vault_admin_group.id
}