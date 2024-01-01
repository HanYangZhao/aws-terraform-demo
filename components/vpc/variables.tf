variable "vpc" {
  description = "VPC"
  type = map(object({
    deploy                           = bool
    cidr                             = string
    enable_dns_hostnames             = bool //true
    enable_dns_support               = bool //true
    manage_default_network_acl       = bool //false
    manage_default_route_table       = bool // false
    manage_default_security_group    = bool //false 
    enable_nat_gateway               = bool //true
    single_nat_gateway               = bool // true
    public_subnet_tags               = map(string)
    private_subnet_tags              = map(string)
    enable_dhcp_options              = bool
    dhcp_options_domain_name_servers = list(string)
    private_subnet_names             = list(string)
    intra_subnet_names               = optional(list(string),[])
    tags                             = map(string)
  }))
}