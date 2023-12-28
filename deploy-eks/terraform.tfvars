eks = {
  dev = {
    vpc_name              = "dev"
    cluster_version       = "1.27"
    private_subnets_names = ["Pirvate Subnet One", "Private Subnet Two"]
    min_node_size         = 1
    max_node_size         = 2
    desired_node_size     = 1
    node_instance_type    = "t3.small"
    node_disk_size        = "50" //GB
    capacity_type         = "SPOT"
    tags = {
      "Name" = "dev"
    }
  }
}