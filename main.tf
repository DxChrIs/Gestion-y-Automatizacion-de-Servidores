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
# Crear la VPC
resource "aws_vpc" "main" {
    cidr_block = local.vpc_cidr
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "proyecto-vpc"
    }
}
# Crear Subredes Públicas
resource "aws_subnet" "public_subnet1" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.0.0/20"
    availability_zone = "us-east-1a"
    tags = {
        Name = "proyecto-subnet-public1-us-east-1a"
    }
}

resource "aws_subnet" "public_subnet2" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.16.0/20"
    availability_zone = "us-east-1b"
    tags = {
        Name = "proyecto-subnet-public2-us-east-1b"
    }
}

# Crear Subredes Privadas
resource "aws_subnet" "private_subnet1" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.128.0/20"
    availability_zone = "us-east-1a"
    tags = {
        Name = "proyecto-subnet-private1-us-east-1a"
    }
}

resource "aws_subnet" "private_subnet2" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.144.0/20"
    availability_zone = "us-east-1b"
    tags = {
        Name = "proyecto-subnet-private2-us-east-1b"
    }
}

# Crear el Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "proyecto-igw"
    }
}

# Crear la tabla de rutas públicas
resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "proyecto-rtb-public"
    }
}

resource "aws_route" "public_route" {
    route_table_id         = aws_route_table.public_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.igw.id
}

# Asociar subredes públicas con la tabla de rutas públicas
resource "aws_route_table_association" "public_subnet1_association" {
    subnet_id      = aws_subnet.public_subnet1.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet2_association" {
    subnet_id      = aws_subnet.public_subnet2.id
    route_table_id = aws_route_table.public_route_table.id
}

# Crear la Elastic IP
resource "aws_eip" "nat_eip" {
    domain = "vpc"
    tags = {
        Name = "proyecto-eip-us-east-1a"
    }
}

# Crear el NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id     = aws_subnet.public_subnet1.id
    tags = {
        Name = "proyecto-nat-public1-us-east-1a"
    }
}

# Crear la tabla de rutas privadas para la subred privada 1
resource "aws_route_table" "private_route_table_1" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "proyecto-rtb-private1-us-east-1a"
    }
}

resource "aws_route" "private_route_1" {
    route_table_id         = aws_route_table.private_route_table_1.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

# Asociar subred privada 1 con la tabla de rutas privadas 1
resource "aws_route_table_association" "private_subnet1_association" {
    subnet_id      = aws_subnet.private_subnet1.id
    route_table_id = aws_route_table.private_route_table_1.id
}

# Crear la tabla de rutas privadas para la subred privada 2
resource "aws_route_table" "private_route_table_2" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "proyecto-rtb-private2-us-east-1b"
    }
}

resource "aws_route" "private_route_2" {
    route_table_id         = aws_route_table.private_route_table_2.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

# Asociar subred privada 2 con la tabla de rutas privadas 2
resource "aws_route_table_association" "private_subnet2_association" {
    subnet_id      = aws_subnet.private_subnet2.id
    route_table_id = aws_route_table.private_route_table_2.id
}
