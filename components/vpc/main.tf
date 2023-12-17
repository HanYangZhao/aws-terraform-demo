
data "aws_availability_zones" "available" {}

locals {
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "github.com/HanYangZhao/terraform-aws-vpc"
  for_each = var.vpc
  create_vpc = each.value.deploy
  name = each.key
  cidr = each.value.cidr

  azs                 = local.azs
  private_subnets     = [for k, v in local.azs : cidrsubnet(each.value.cidr, 8, k)] #/24, 251 addresses + 5 reserved
  public_subnets      = [for k, v in local.azs : cidrsubnet(each.value.cidr, 8, k + 4)] #/24, 251 addresses + 5 reserved
  database_subnets    = [for k, v in local.azs : cidrsubnet(each.value.cidr, 8, k + 8)] #/24, 251 addresses + 5 reserved
  elasticache_subnets = [for k, v in local.azs : cidrsubnet(each.value.cidr, 8, k + 12)] #/24, 251 addresses + 5 reserved
  redshift_subnets    = [for k, v in local.azs : cidrsubnet(each.value.cidr, 8, k + 16)] #/24, 251 addresses + 5 reserved
  intra_subnets       = [for k, v in local.azs : cidrsubnet(each.value.cidr, 8, k + 20)] #/24, 251 addresses + 5 reserved

  private_subnet_names = ["Private Subnet One", "Private Subnet Two", "Private Subnet Three"]
  # public_subnet_names omitted to show default name generation for all three subnets
  database_subnet_names    = ["DB Subnet One"]
  elasticache_subnet_names = ["Elasticache Subnet One", "Elasticache Subnet Two"]
  redshift_subnet_names    = ["Redshift Subnet One", "Redshift Subnet Two", "Redshift Subnet Three"]
  intra_subnet_names       = []

  create_database_subnet_group  = false
  manage_default_network_acl    = each.value.manage_default_network_acl
  manage_default_route_table    = each.value.manage_default_route_table
  manage_default_security_group = each.value.manage_default_security_group

  enable_dns_hostnames = each.value.enable_dns_hostnames
  enable_dns_support   = each.value.enable_dns_support

  enable_nat_gateway = each.value.enable_nat_gateway
  single_nat_gateway = each.value.single_nat_gateway

  customer_gateways = {
    # IP1 = {
    #   bgp_asn     = 65112
    #   ip_address  = "1.2.3.4"
    #   device_name = "some_name"
    # },
    # IP2 = {
    #   bgp_asn    = 65112
    #   ip_address = "5.6.7.8"
    # }
  }

  enable_vpn_gateway = true

  enable_dhcp_options              = true
  dhcp_options_domain_name         = "service.consul"
  dhcp_options_domain_name_servers = ["127.0.0.1", "10.10.0.2"]

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = each.value.tags
}

################################################################################
# VPC Endpoints Module
################################################################################

module "vpc_endpoints" {
  for_each = module.vpc
  source = "github.com/HanYangZhao/aws-terraform-vpc-endpoints"

  vpc_id = each.value.vpc_id

  create_security_group      = true
  security_group_name_prefix = "${each.key}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [each.value.vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service = "s3"
      tags    = { Name = "s3-vpc-endpoint" }
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = flatten([each.value.intra_route_table_ids,each.value.private_route_table_ids, each.value.public_route_table_ids])
      policy          = data.aws_iam_policy_document[each.key].dynamodb_endpoint_policy.json
      tags            = { Name = "dynamodb-vpc-endpoint" }
    },
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
      subnet_ids          = each.value.private_subnets
    },
    ecs_telemetry = {
      create              = false
      service             = "ecs-telemetry"
      private_dns_enabled = true
      subnet_ids          = each.value.private_subnets
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = each.value.private_subnets
      policy              = data.aws_iam_policy_document[each.key].generic_endpoint_policy.json
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = each.value.private_subnets
      policy              = data.aws_iam_policy_document[each.key].generic_endpoint_policy.json
    },
    rds = {
      service             = "rds"
      private_dns_enabled = true
      subnet_ids          = each.value.private_subnets
      security_group_ids  = [aws_security_group[each.key].rds.id]
    },
  }

  tags = merge(each.value.tags, {
    Project  = "Secret"
    Endpoint = "true"
  })
}

# module "vpc_endpoints_nocreate" {
#   source = "github.com/HanYangZhao/terraform-aws-vpc-endpoints"

#   create = false
# }

################################################################################
# Supporting Resources
################################################################################

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  for_each = module.vpc
  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpc"

      values = [each.value.vpc_id]
    }
  }
}

data "aws_iam_policy_document" "generic_endpoint_policy" {
  for_each = module.vpc
  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"

      values = [each.value.vpc_id]
    }
  }
}

resource "aws_security_group" "rds" {
  for_each = module.vpc
  name_prefix = "${each.key}-rds"
  description = "Allow PostgreSQL inbound traffic"
  vpc_id      = each.value.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [each.value.vpc_cidr_block]
  }

  tags = each.value.tags
}
