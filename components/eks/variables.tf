variable "eks" {
  description = "EKS Cluster"
  type = map(object({
    vpc_name                    = string
    cluster_version             = string
    private_subnets_names       = list(string)
    control_plane_subnets_names = list(string)
    min_node_size               = number
    max_node_size               = number
    desired_node_size           = number
    node_instance_type          = string
    node_disk_size              = number
    node_capacity_type          = string
    aws_auth_roles = optional(list(object({
      rolearn  = string
      username = string,
      groups   = list(string)
    })), [])
    ssh_access_cidr = list(string)

    tags = map(string)

  }))
}