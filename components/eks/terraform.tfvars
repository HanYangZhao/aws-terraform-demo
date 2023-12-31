eks = {
  dev = {
    vpc_name              = "dev"
    cluster_version       = "1.27"
    private_subnets_names = ["Private Subnet One", "Private Subnet Two"]
    min_node_size         = 1
    max_node_size         = 2
    desired_node_size     = 1
    node_instance_type    = "t3.small"
    node_disk_size        = "50" //GB
    node_capacity_type    = "SPOT"
    aws_auth_roles = [
      {
        rolearn  = "arn:aws:iam::412136911237:role/eks_admin"
        username = "eks_admin"
        groups   = ["system:masters"]
      },
    ]
    tags = {
      "Name" = "dev"
    }
  }
}
