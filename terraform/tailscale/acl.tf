resource "tailscale_acl" "acl" {
  acl = jsonencode({
    tagOwners = {
      "tag:servers" = ["autogroup:admin"]
    }

    acls = [
      # Allow all traffic between all nodes (default permissive policy)
      {
        action = "accept"
        src    = ["*"]
        dst    = ["*:*"]
      }
    ]

    ssh = [
      # Allow SSH from any node to tagged servers (for Tailscale SSH)
      {
        action = "accept"
        src    = ["autogroup:admin"]
        dst    = ["tag:servers"]
        users  = ["autogroup:nonroot", "root"]
      }
    ]
  })
}
