data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}


# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
#   token                  = data.aws_eks_cluster_auth.cluster.token
# }


locals {
  vpc_names           = distinct([for config in var.eks : config.vpc_name])
  private_subnets_map = { for cluster_name, config in var.eks : cluster_name => config.private_subnets_names }
}

# Create a map of VPC names to VPC IDs
data "aws_vpc" "vpcs_map" {
  for_each = toset(local.vpc_names)

  filter {
    name   = "tag:Name"
    values = [each.value]
  }

}

# Fetch all private subnets per cluster
# "dev" = [
#     "subnet-01a2b3c4d",
#     "subnet-02a2b3c4d"
# ],
# "stgn" = [
#     "subnet-03a2b3c4d",
#     "subnet-04a2b3c4d"
# ]
# }
data "aws_subnets" "private" {
  for_each = var.eks
  filter {
    name   = "tag:Name"
    values = each.value.private_subnets_names
  }
  tags = {
    Type = "Private"
  }
}


data "aws_subnets" "control_plane" {
  for_each = var.eks
  filter {
    name   = "tag:Name"
    values = each.value.control_plane_subnets_names
  }
  tags = {
    Type = "Intra"
  }
}


################################################################################
# EKS Module
################################################################################

module "eks" {
  for_each = var.eks
  source   = "github.com/HanYangZhao/aws-terraform-eks"

  cluster_name                   = each.key
  cluster_version                = each.value.cluster_version
  cluster_endpoint_public_access = true

  cluster_ip_family = "ipv4"

  # We are using the IRSA created below for permissions
  # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
  # and then turn this off after the cluster/node group is created. Without this initial policy,
  # the VPC CNI fails to assign IPs and nodes cannot join the cluster
  # See https://github.com/aws/containers-roadmap/issues/1666 for more context
  # TODO - remove this policy once AWS releases a managed version similar to AmazonEKS_CNI_Policy (IPv4)
  # create_cni_ipv6_iam_policy = true

  cluster_addons = {
    coredns = {
      most_recent = false
    }
    kube-proxy = {
      most_recent = false
    }
    vpc-cni = {
      most_recent              = false
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn // TODO: Set in the github.com/HanYangZhao/aws-terraform-eks module to fix a circular dependency
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "false"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id                    = data.aws_vpc.vpcs_map[each.key].id
  subnet_ids                = data.aws_subnets.private[each.key].ids
  control_plane_subnet_ids  = data.aws_subnets.control_plane[each.key].ids
  manage_aws_auth_configmap = true

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.small", "m6i.large", "m5.large", "m5n.large", "m5zn.large"]

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
  }

  aws_auth_roles = each.value.aws_auth_roles

  eks_managed_node_groups = {
    # Default node group - as provided by AWS EKS
    default_node_group = {
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      use_custom_launch_template = false
      # name                       = "${each.key}-default"
      # iam_role_use_name_prefix   = false
      # use_name_prefix            = false
      min_size       = each.value.min_node_size
      max_size       = each.value.max_node_size
      desired_size   = each.value.desired_node_size
      disk_size      = each.value.node_disk_size
      instance_types = [each.value.node_instance_type]
      capacity_type  = each.value.node_capacity_type
      # Remote access cannot be specified with a launch template
      remote_access = {
        ec2_ssh_key = module.key_pair[each.key].key_pair_name
        # ec2_ssh_key                 = aws_key_pair.eks.key_name
        source_security_group_ids = [aws_security_group.remote_access[each.key].id]
      }

      # iam_role_additional_policies = {
      #   AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      #   additional                         = aws_iam_policy.node_additional[each.key].arn
      # }
    }

    # # Use a custom AMI
    # custom_ami = {
    #   ami_type = "AL2_x86_64"
    #   # Current default AMI used by managed node groups - pseudo "custom"
    #   ami_id = data.aws_ami.eks_default_arm[each.key].image_id

    #   # This will ensure the bootstrap user data is used to join the node
    #   # By default, EKS managed node groups will not append bootstrap script;
    #   # this adds it back in using the default template provided by the module
    #   # Note: this assumes the AMI provided is an EKS optimized AMI derivative
    #   enable_bootstrap_user_data = true

    #   instance_types = [each.value.node_instance_type]
    # }
  }



  tags = each.value.tags
}


################################################################################
# Tags for the ASG to support cluster-autoscaler scale up from 0
################################################################################

# locals {

#   # We need to lookup K8s taint effect from the AWS API value
#   taint_effects = {
#     NO_SCHEDULE        = "NoSchedule"
#     NO_EXECUTE         = "NoExecute"
#     PREFER_NO_SCHEDULE = "PreferNoSchedule"
#   }

#   cluster_autoscaler_label_tags = merge([
#     for name, group in module.eks["dev"].eks_managed_node_groups : {
#       for label_name, label_value in coalesce(group.node_group_labels, {}) : "${name}|label|${label_name}" => {
#         autoscaling_group = group.node_group_autoscaling_group_names[0],
#         key               = "k8s.io/cluster-autoscaler/node-template/label/${label_name}",
#         value             = label_value,
#       }
#     }
#   ]...)

#   cluster_autoscaler_taint_tags = merge([
#     for name, group in module.eks["dev"].eks_managed_node_groups : {
#       for taint in coalesce(group.node_group_taints, []) : "${name}|taint|${taint.key}" => {
#         autoscaling_group = group.node_group_autoscaling_group_names[0],
#         key               = "k8s.io/cluster-autoscaler/node-template/taint/${taint.key}"
#         value             = "${taint.value}:${local.taint_effects[taint.effect]}"
#       }
#     }
#   ]...)

#   cluster_autoscaler_asg_tags = merge(local.cluster_autoscaler_label_tags, local.cluster_autoscaler_taint_tags)
# }

# resource "aws_autoscaling_group_tag" "cluster_autoscaler_label_tags" {
#   for_each = local.cluster_autoscaler_asg_tags

#   autoscaling_group_name = each.value.autoscaling_group

#   tag {
#     key   = each.value.key
#     value = each.value.value

#     propagate_at_launch = false
#   }
# }

# TODO : fix this to make it work with for_each
module "vpc_cni_irsa" {
  # for_each = var.eks
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA-dev"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks["dev"].oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

# module "ebs_kms_key" {
#   for_each = var.eks
#   source   = "terraform-aws-modules/kms/aws"
#   version  = "~> 1.5"

#   description = "Customer managed key to encrypt EKS managed node group volumes"

#   # Policy
#   key_administrators = [
#     data.aws_caller_identity.current.arn
#   ]

#   key_service_roles_for_autoscaling = [
#     # required for the ASG to manage encrypted volumes for nodes
#     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
#     # required for the cluster / persistentvolume-controller to create encrypted PVCs
#     module.eks[each.key].cluster_iam_role_arn,
#   ]

#   # Aliases
#   aliases = ["eks/${each.key}/ebs"]

#   tags = each.value.tags
# }


module "key_pair" {
  for_each = var.eks
  source   = "terraform-aws-modules/key-pair/aws"
  version  = "~> 2.0"

  key_name_prefix    = each.key
  create_private_key = true

  tags = each.value.tags
}

resource "aws_security_group" "remote_access" {
  for_each    = var.eks
  name_prefix = "${each.key}-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = data.aws_vpc.vpcs_map[each.key].id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = each.value.ssh_access_cidr
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(each.value.tags, { Name = "${each.key}-remote" })
}

resource "aws_iam_policy" "node_additional" {
  for_each    = var.eks
  name        = "${each.key}-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = each.value.tags
}

# data "aws_ami" "eks_default_arm" {
#   for_each    = var.eks
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["amazon-eks-node-${each.value.cluster_version}-v*"]
#   }
# }