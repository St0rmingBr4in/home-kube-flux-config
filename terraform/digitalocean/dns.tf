# Import existing domain:
#   terraform import digitalocean_domain.st0rmingbr4in_com st0rmingbr4in.com
resource "digitalocean_domain" "st0rmingbr4in_com" {
  name = "st0rmingbr4in.com"
}

# inlet A record → reserved IP (stable across droplet reprovisioning)
resource "digitalocean_record" "inlet" {
  domain = digitalocean_domain.st0rmingbr4in_com.id
  type   = "A"
  name   = "inlet"
  value  = digitalocean_reserved_ip.inlet.ip_address
  ttl    = 300
}

# Wildcard CNAME → inlet, so all *.st0rmingbr4in.com routes through inlet
resource "digitalocean_record" "wildcard" {
  domain = digitalocean_domain.st0rmingbr4in_com.id
  type   = "CNAME"
  name   = "*"
  value  = "${digitalocean_record.inlet.fqdn}."
  ttl    = 300
}
