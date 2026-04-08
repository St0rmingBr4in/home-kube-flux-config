resource "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
  type = "proxy"

  protocol_providers = [
    for k, v in authentik_provider_proxy.apps : v.id
  ]

  # Preserve existing Kubernetes deployment config — only providers list is managed here.
  lifecycle {
    ignore_changes = [config]
  }
}
