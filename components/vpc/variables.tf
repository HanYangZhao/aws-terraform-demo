variable "vpc" {
    description = "VPC"
    type = map(object({
        deploy = bool
        cidr   = string
        enable_dns_hostnames = bool       //true
        enable_dns_support   = bool       //true
        manage_default_network_acl = bool //false
        manage_default_route_table = bool // false
        manage_default_security_group = bool //false 
        enable_nat_gateway            = bool //true
        single_nat_gateway            = bool // true

        tags = optional(map(object({
            resource-group = string
            cost-tag       = string
        })), {})                                  

    }))
}