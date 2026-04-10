# Looks up the inlet droplet by name so we can attach the reserved IP to it.
data "digitalocean_droplet" "inlet" {
  name = var.inlet_droplet_name
}

# A static IP that persists across droplet reprovisioning.
# After applying, assign it to the droplet once in the DO console or via:
#   doctl compute reserved-ip-action assign <reserved-ip> <droplet-id>
# Subsequent Terraform applies keep the assignment in sync automatically.
resource "digitalocean_reserved_ip" "inlet" {
  region = data.digitalocean_droplet.inlet.region

  # droplet_id is managed by digitalocean_reserved_ip_assignment below;
  # ignore it here to avoid the two resources fighting each other.
  lifecycle {
    ignore_changes = [droplet_id]
  }
}

resource "digitalocean_reserved_ip_assignment" "inlet" {
  ip_address = digitalocean_reserved_ip.inlet.ip_address
  droplet_id = data.digitalocean_droplet.inlet.id
}
