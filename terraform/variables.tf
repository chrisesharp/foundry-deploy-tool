variable "do_token" {}
variable "pvt_key" {}
variable "foundry_user" {}
variable "foundry_password" {}
variable "data_dir" {
    type = string
    # default = "~/Dropbox/FoundryVTT"
    default = "foundry-upload.tgz"
}
variable "digitalocean_ssh_keyname" {
    type = string
    default = "mac_token"
}
variable "docker_image" {
    type = string
    # default = "registry.digitalocean.com/chrisesharp/foundryvtt:12.343.0"
    default = "felddy/foundryvtt:13.351.0"
}

variable "domain_name" {
  type        = string
  description = "The domain name registered in DigitalOcean (e.g., duckdns.org)"
  default     = "chrisesharp.duckdns.org"
}

variable "subdomain" {
  type        = string
  description = "The subdomain for the A record (e.g., 'chrisesharp')"
  default     = "@"
}

variable "duckdns_token" {
  type        = string
  description = "Your DuckDNS token"
  sensitive   = true
}

variable "duckdns_subdomain" {
  type        = string
  description = "Your DuckDNS subdomain (e.g., 'chrisesharp' for chrisesharp.duckdns.org)"
  default     = "chrisesharp"
}