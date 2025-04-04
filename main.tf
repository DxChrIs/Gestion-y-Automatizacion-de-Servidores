provider "aws" {
    region = var.region
}
locals {
    instance_name = "autodeployment-srv-project"
    vpc_cidr      = "10.0.0.0/16"
    azs           = slice(data.aws_availability_zones.available.names, 0, 2)
}
data "aws_availability_zones" "available" {}

#############################################
#                 VPC                      #
#############################################
# Se crea una VPC con sus subredes públicas y privadas.
module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"
    version = "5.8.1"
    
    name = "vpc-${local.instance_name}"
    cidr = local.vpc_cidr
    
    azs             = local.azs
    private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
    public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]

    private_subnet_names = ["subnet-private-1", "subnet-private-2"]
    public_subnet_names  = ["subnet-public-1", "subnet-public-2"]

    create_database_subnet_group  = false # Se desactiva la creación del grupo de subredes de base de datos
    manage_default_network_acl    = false # Se desactiva la creación del ACL de red por defecto
    manage_default_route_table    = false # Se desactiva la creación de la tabla de rutas por defecto
    manage_default_security_group = false # Se desactiva la creación del grupo de seguridad por defecto

    enable_dns_hostnames = true # Se habilitan los nombres de host DNS
    enable_dns_support   = true # Se habilita el soporte DNS

    enable_nat_gateway = true # Se habilita el NAT Gateway
    single_nat_gateway = true # Se utiliza un solo NAT Gateway
    
    enable_flow_log                      = true # Se habilitan los logs de flujo
    create_flow_log_cloudwatch_iam_role  = true # Se crea el rol IAM para los logs de flujo
    create_flow_log_cloudwatch_log_group = true # Se crea el grupo de logs de CloudWatch
    flow_log_max_aggregation_interval    = 60
}

#############################################
#            Internet Gateway               #
#############################################
resource "aws_internet_gateway" "igw_project" {
    vpc_id = module.vpc.vpc_id

    tags = {
        Name = "igw-${local.instance_name}"
    }
}

#############################################
#           Public Route Table              #
#############################################
resource "aws_route_table" "rtb_public_project" {
    vpc_id = module.vpc.vpc_id

    tags = {
        Name = "rtb-public-${local.instance_name}"
    }
}

