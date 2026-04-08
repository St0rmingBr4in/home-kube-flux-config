resource "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
  type = "proxy"

  protocol_providers = [
    for k, v in authentik_provider_proxy.apps : v.id
  ]

  # Only manage providers list — config and service_connection are Authentik-managed.
  lifecycle {
    ignore_changes = [config, service_connection]
  }
}
