vpc = {
  dev = {
    deploy                        = true
    cidr                          = "180.31.0.0/16"
    enable_dns_hostnames          = true
    enable_dns_support            = true
    manage_default_network_acl    = false
    manage_default_route_table    = false
    manage_default_security_group = false
    enable_nat_gateway            = true
    single_nat_gateway            = true
    public_subnet_tags = {
      "kubernetes.io/role/elb" = 1
    }
    private_subnet_tags = {
      "kubernetes.io/role/internal-elb" = 1
    }
    tags = {
      resource-group = "dev"
      cost-tag       = "dev"
    }
  }
}