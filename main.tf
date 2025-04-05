provider "aws" {
    region = var.region
}
locals {
    instance_name  = "autodeployment-srv-project"
    vpc_cidr       = "10.0.0.0/16"
    azs            = slice(data.aws_availability_zones.available.names, 0, 2)
}
data "aws_availability_zones" "available" {}

#############################################
#                 VPC                       #
#############################################
# Se crea una VPC con sus subredes públicas y privadas.
# Crear la VPC
resource "aws_vpc" "main" {
    cidr_block = local.vpc_cidr
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "vpc-${local.instance_name}"
    }
}
#############################################
#             Public Subnet                 #
#############################################
# Crear Subredes Públicas
resource "aws_subnet" "public_subnet1" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "${var.region}a"
    tags = {
        Name = "subnet-public-1-${var.region}"
    }
}

resource "aws_subnet" "public_subnet2" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.16.0/24"
    availability_zone = "${var.region}b"
    tags = {
        Name = "subnet-public-2-${var.region}"
    }
}

#############################################
#             Private Subnet                #
#############################################
# Crear Subredes Privadas
resource "aws_subnet" "private_subnet1" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.32.0/24"
    availability_zone = "${var.region}a"
    tags = {
        Name = "subnet-private-1-${var.region}"
    }
}

resource "aws_subnet" "private_subnet2" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.64.0/24"
    availability_zone = "${var.region}b"
    tags = {
        Name = "subnet-private-2-${var.region}"
    }
}

#############################################
#            Internet Gateway               #
#############################################
# Crear el Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "igw-${local.instance_name}"
    }
}

#############################################
#           Public Route Table              #
#############################################
# Crear la tabla de rutas públicas
resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "rtb-public-${local.instance_name}"
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

#############################################
#               Elastic IP                  #
#############################################
# Crear la Elastic IP
resource "aws_eip" "nat_eip" {
    domain = "vpc"
    tags = {
        Name = "eip-nat-${var.region}a"
    }
}

#############################################
#               NAT Gateway                 #
#############################################
# Crear el NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id     = aws_subnet.public_subnet1.id
    tags = {
        Name = "nat-public-1-${var.region}a"
    }
}

#############################################
#            Private Route Table            #
#############################################
# Crear la tabla de rutas privadas para la subred privada 1
resource "aws_route_table" "private_route_table_1" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "rtb-private-1-${var.region}a"
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
        Name = "rtb-private-2-${var.region}b"
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

#############################################
#               Network ACL                 #
#############################################
resource "aws_network_acl" "public_acl" {
    vpc_id = aws_vpc.main.id
    subnet_ids = [
        aws_subnet.public_subnet1.id,
        aws_subnet.public_subnet2.id
    ]
    tags = {
        Name = "acl-public-${var.region}"
    }
}
# Entrada: permitir SSH (22)
resource "aws_network_acl_rule" "inbound_ssh" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 100
    egress         = false
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 22
    to_port        = 22
}
# Entrada: permitir RDP (3389)
resource "aws_network_acl_rule" "inbound_rdp" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 110
    egress         = false
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 3389
    to_port        = 3389
}
# Entrada: permitir respuesta a conexiones ya establecidas
resource "aws_network_acl_rule" "inbound_ephemeral" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 120
    egress         = false
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 1024
    to_port        = 65535
}
# Salida: permitir SSH
resource "aws_network_acl_rule" "outbound_ssh" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 100
    egress         = true
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 22
    to_port        = 22
}
# Salida: permitir RDP
resource "aws_network_acl_rule" "outbound_rdp" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 110
    egress         = true
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 3389
    to_port        = 3389
}
# Salida: permitir conexiones efímeras (respuesta)
resource "aws_network_acl_rule" "outbound_ephemeral" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 120
    egress         = true
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 1024
    to_port        = 65535
}

#############################################
#             Security Group                #
#############################################

resource "aws_security_group" "ssh_access" {
    vpc_id      = aws_vpc.main.id
    name        = "ssh-${var.region}-ec2-sg"
    description = "Allow SSH access"
    ingress {
        description = "SSH access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks  = ["0.0.0.0/0"]
    }

    egress {
        description = "Allow all outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks  = ["0.0.0.0/0"]
    }
    tags = {
        Name = "sg-${local.instance_name}-ssh"
    }
}

resource "aws_security_group" "rdp_access" {
    vpc_id      = aws_vpc.main.id
    name        = "rdp-${var.region}-ec2-sg"
    description = "Allow RDP access"

    ingress {
        description = "RDP access"
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks  = ["10.0.0.0/8"]
    }

    egress {
        description = "Allow all outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks  = ["0.0.0.0/0"]
    }
    tags = {
        Name = "sg-${local.instance_name}-rdp"
    }
}

#############################################
#              Instance EC2                 #
#############################################

resource "aws_instance" "linux_instance" {
    ami           = var.linux_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name
    vpc_security_group_ids = [aws_security_group.ssh_access.id]

    subnet_id     = aws_subnet.public_subnet1.id
    associate_public_ip_address = true

    monitoring = true
    root_block_device {
        volume_size = 20
        volume_type = "gp2"
        encrypted = true
    }

    # user_data = [arranque_linux.sh]
    tags = {
        Name = "linux-${local.instance_name}"
    }
}