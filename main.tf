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
        Name = "nat-private-1-${var.region}a"
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

# Entrada: permitir HTTP (80)
resource "aws_network_acl_rule" "inbound_http" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 130
    egress         = false
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 80
    to_port        = 80
}

# Entrada: permitir HTTPS (443)
resource "aws_network_acl_rule" "inbound_https" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 140
    egress         = false
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 443
    to_port        = 443
}

# Entrada: permitir ICMP
resource "aws_network_acl_rule" "inbound_icmp" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 150
    egress         = false
    protocol       = "icmp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = -1
    to_port        = -1
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

# Salida: permitir HTTP (80)
resource "aws_network_acl_rule" "outbound_http" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 130
    egress         = true
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 80
    to_port        = 80
}

# Salida: permitir HTTPS (443)
resource "aws_network_acl_rule" "outbound_https" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 140
    egress         = true
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 443
    to_port        = 443
}

# Salida: permitir ICMP
resource "aws_network_acl_rule" "outbound_icmp" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 150
    egress         = true
    protocol       = "icmp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = -1
    to_port        = -1
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

    ingress {
        description = "HTTPS access"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "ICMP access"
        from_port   = -1
        to_port     = -1
        protocol    = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_security_group" "winrm_rdp_access" {
    vpc_id      = aws_vpc.main.id
    name        = "winrm-rdp-${var.region}-ec2-sg"
    description = "Allow winRM and RDP access"

    ingress {
        description = "WinRM access"
        from_port   = 5985      # WinRM HTTP
        to_port     = 5985
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "RDP access"
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH access for Ansible playbooks"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTPS access"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "ICMP access"
        from_port   = -1
        to_port     = -1
        protocol    = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "Allow all outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks  = ["0.0.0.0/0"]
    }
    tags = {
        Name = "sg-${local.instance_name}-winrm-rdp"
    }
}

#############################################
#              Instance EC2                 #
#############################################
resource "aws_launch_template" "linux_template" {
    name_prefix   = "linux-template-"
    image_id      = var.linux_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name

    network_interfaces {
        associate_public_ip_address = true
        security_groups = [aws_security_group.ssh_access.id]
    }

    monitoring {
        enabled = true
    }

    block_device_mappings {
        device_name = "/dev/sda1"
        ebs {
            volume_size = 20
            volume_type = "gp2"
            encrypted   = true
        }
    }

    user_data = base64encode(file("arranque_linux.sh"))
    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "linux-${local.instance_name}"
        }
    }
}
resource "aws_launch_template" "windows_template" {
    name_prefix   = "windows-template-"
    image_id      = var.windows_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name

    network_interfaces {
        associate_public_ip_address = true
        security_groups = [aws_security_group.winrm_rdp_access.id]
    }

    monitoring {
        enabled = true
    }

    block_device_mappings {
        device_name = "/dev/sda1"
        ebs {
            volume_size = 30
            volume_type = "gp2"
            encrypted   = true
        }
    }

    user_data = base64encode(<<-EOF
        <powershell>
        $(file("arranque_windows.ps1"))
        </powershell>
        EOF
        )

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "windows-${local.instance_name}"
        }
    }

    lifecycle {
        create_before_destroy = true
    }
}

#############################################
#            Auto Scaling Group             #
#############################################
resource "aws_autoscaling_group" "linux_asg" {
    name                = "linux-asg-${local.instance_name}"

    desired_capacity    = 1
    max_size            = 2
    min_size            = 1

    health_check_type   = "EC2"
    health_check_grace_period = 300
    
    vpc_zone_identifier = [aws_subnet.public_subnet1.id]
    launch_template {
        id      = aws_launch_template.linux_template.id
        version = "$Latest"
    }

    tag {
        key = "Name"
        value = "linux-${local.instance_name}"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_autoscaling_group" "windows_asg" {
    name                = "windows-asg-${local.instance_name}"

    desired_capacity    = 1
    max_size            = 2
    min_size            = 1

    health_check_type   = "EC2"
    health_check_grace_period = 300

    vpc_zone_identifier = [aws_subnet.public_subnet2.id]

    launch_template {
        id      = aws_launch_template.windows_template.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "windows-${local.instance_name}"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}