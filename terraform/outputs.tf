# output "droplet_ip" {
#   value       = digitalocean_droplet.foundryvtt.ipv4_address
#   description = "The public IP address of the Foundry VTT droplet"
# }

# output "fqdn" {
#   value       = "${digitalocean_record.foundryvtt.name}.${digitalocean_record.foundryvtt.domain}"
#   description = "The fully qualified domain name for Foundry VTT"
# }