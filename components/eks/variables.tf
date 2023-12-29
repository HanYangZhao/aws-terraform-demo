variable "eks" {
  description = "EKS Cluster"
  type = map(object({
    vpc_name              = string
    cluster_version       = string
    private_subnets_names = list(string)
    intra_subnets_names   = optional(list(string))
    min_node_size         = number
    max_node_size         = number
    desired_node_size     = number
    node_instance_type    = string
    node_disk_size        = number
    capacity_type         = string

    tags = map(string)

  }))
}