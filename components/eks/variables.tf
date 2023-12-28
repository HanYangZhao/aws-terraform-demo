variable "eks" {
  description = "EKS Cluster"
  type = map(object({
    vpc_id = string

    cluster_version     = string
    private_subnets_ids = list(string)
    intra_subnets_ids   = list(string)
    min_node_size       = number
    max_node_size       = number
    desired_node_size   = number
    node_instance_type  = string
    node_disk_size      = number
    capacity_type       = string

    tags = map(string)

  }))
}