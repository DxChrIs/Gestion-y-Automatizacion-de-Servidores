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
    cidr_block           = local.vpc_cidr
    instance_tenancy     = "default"
    enable_dns_support   = true
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
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.0.0/24"
    availability_zone = "${var.region}a"
    tags = {
        Name = "subnet-public-1-${var.region}"
    }
}

resource "aws_subnet" "public_subnet2" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.16.0/24"
    availability_zone = "${var.region}b"
    tags = {
        Name = "subnet-public-2-${var.region}"
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
#               Network ACL                 #
#############################################
resource "aws_network_acl" "public_acl" {
    vpc_id     = aws_vpc.main.id
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

# Entrada: permitir SQL
resource "aws_network_acl_rule" "inbound_sql" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 160
    egress         = false
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 3306
    to_port        = 3306
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

# Salida: permitir SQL
resource "aws_network_acl_rule" "outbound_sql" {
    network_acl_id = aws_network_acl.public_acl.id
    rule_number    = 160
    egress         = true
    protocol       = "tcp"
    rule_action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 3306
    to_port        = 3306
}

#############################################
#             Security Group                #
#############################################
resource "aws_security_group" "linux_access" {
    vpc_id      = aws_vpc.main.id
    name        = "linux-${var.region}-sg"
    description = "Allow SSH, ICMP, HTTPS access"
    ingress {
        description = "SSH access"
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
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "sg-${local.instance_name}-linux"
    }
}
#-----------Linux Web Server----------
resource "aws_security_group" "web_linux_access" {
    vpc_id      = aws_vpc.main.id
    name        = "web-linux-${var.region}-sg"
    description = "Allow SSH, HTTP and ICMP access"
    ingress {
        description = "SSH access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP access"
        from_port   = 80
        to_port     = 80
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
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "web-sg-${local.instance_name}-linux"
    }
}
#-----------Linux SQL Server------------
resource "aws_security_group" "sql_linux_access" {
    vpc_id      = aws_vpc.main.id
    name        = "sql-linux-${var.region}-sg"
    description = "Allow SSH, ICMP and SQL access"
    ingress {
        description = "SSH access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SQL access Ofuscated"
        from_port   = 3306
        to_port     = 3306
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
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "sql-sg-${local.instance_name}-linux"
    }
}
#-----------Windows Control Node-----------
resource "aws_security_group" "windows_access" {
    vpc_id      = aws_vpc.main.id
    name        = "windows-${var.region}-sg"
    description = "Allow winRM, RDP, SSH, HTTPS, HTTP access"

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
        description = "HTTP access"
        from_port   = 80
        to_port     = 80
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
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "sg-${local.instance_name}-windows"
    }
}
#------------Windows IIS Server------------
resource "aws_security_group" "iis_windows_access" {
    vpc_id      = aws_vpc.main.id
    name        = "iis_windows-${var.region}-sg"
    description = "Allow winRM, RDP, HTTP access"

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
        description = "HTTP access"
        from_port   = 80
        to_port     = 80
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
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "iis-sg-${local.instance_name}-windows"
    }
}
#------------Windows AD Server-------------
resource "aws_security_group" "ad_windows_access" {
    vpc_id      = aws_vpc.main.id
    name        = "ad-windows-${var.region}-sg"
    description = "Allow winRM, RDP access"

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
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "ad-sg-${local.instance_name}-windows"
    }
}
#-----------Windows File Server-------------
resource "aws_security_group" "file_windows_access" {
    vpc_id      = aws_vpc.main.id
    name        = "file-windows-${var.region}-sg"
    description = "Allow winRM, RDP access"

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
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "file-sg-${local.instance_name}-windows"
    }
}

#############################################
#              Instance EC2                 #
#############################################
#-----------Linux Control node---------------
resource "aws_instance" "linux_control_node" {
    ami = var.linux_ami
    instance_type = var.instance_type
    key_name = var.key_name
    subnet_id = aws_subnet.public_subnet1.id
    security_groups = [aws_security_group.linux_access.id]
    associate_public_ip_address = true

    root_block_device {
        volume_size = 20
        volume_type = "gp2"
        encrypted   = true
    }

    iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
    
    user_data = base64encode(file("linux_control_node.sh"))

    monitoring = true

    provisioner "file" {
        source = "./ssh-code.pem"
        destination = "/home/ubuntu/ssh-code.pem"
    }

    provisioner "remote-exec" {
        inline = ["chmod 400 /home/ubuntu/ssh-code.pem"]
    }

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = file("./ssh-code.pem")
        host = aws_instance.linux_control_node.public_ip
    }

    tags = {
        Name = "linux-control-node-${local.instance_name}"
    }
}
#-------------Linux web server---------------
resource "aws_launch_template" "web_linux_template" {
    name_prefix   = "web-linux-template-"
    image_id      = var.linux_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name

    iam_instance_profile {
        name = aws_iam_instance_profile.ec2_instance_profile.name
    }

    network_interfaces {
        associate_public_ip_address = true
        security_groups             = [aws_security_group.web_linux_access.id]
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

    user_data = base64encode(file("web_server_linux.sh"))

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "web-linux-${local.instance_name}"
            Role = "web"
        }
    }
}
#-------------Linux sql server---------------
resource "aws_launch_template" "sql_linux_template" {
    name_prefix   = "sql-linux-template-"
    image_id      = var.linux_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name

    iam_instance_profile {
        name = aws_iam_instance_profile.ec2_instance_profile.name
    }

    network_interfaces {
        associate_public_ip_address = true
        security_groups             = [aws_security_group.sql_linux_access.id]
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

    user_data = base64encode(file("sql_server_linux.sh"))

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "sql-linux-${local.instance_name}"
            Role = "sql"
        }
    }
}
#-----------Windows Control Node------------
resource "aws_instance" "windows_control_node" {
    ami = var.linux_ami
    instance_type = var.instance_type
    key_name = var.key_name
    subnet_id = aws_subnet.public_subnet2.id
    security_groups = [aws_security_group.windows_access.id]
    associate_public_ip_address = true

    root_block_device {
        volume_size = 20
        volume_type = "gp2"
        encrypted   = true
    }

    iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
    
    user_data = base64encode(file("windows_control_node.sh"))

    monitoring = true

    provisioner "file" {
        source = "./ssh-code.pem"
        destination = "/home/ubuntu/ssh-code.pem"
    }

    provisioner "remote-exec" {
        inline = ["chmod 400 /home/ubuntu/ssh-code.pem"]
    }

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = file("./ssh-code.pem")
        host = aws_instance.windows_control_node.public_ip
    }

    tags = {
        Name = "windows-control-node-${local.instance_name}"
    }
}
#-------------Windows IIS Server--------------
resource "aws_launch_template" "iis_windows_template" {
    name_prefix   = "iis-windows-template-"
    image_id      = var.windows_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name

    iam_instance_profile {
        name = aws_iam_instance_profile.ec2_instance_profile.name
    }
    network_interfaces {
        associate_public_ip_address = true
        security_groups             = [aws_security_group.iis_windows_access.id]
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

    user_data = base64encode(file("/iis_server_windows.ps1"))

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "windows-${local.instance_name}"
            Role = "iis"
        }
    }

    lifecycle {
        create_before_destroy = true
    }
}
#---------Windows Active Directory-----------
resource "aws_launch_template" "ad_windows_template" {
    name_prefix   = "ad-windows-template-"
    image_id      = var.windows_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name

    iam_instance_profile {
        name = aws_iam_instance_profile.ec2_instance_profile.name
    }
    network_interfaces {
        associate_public_ip_address = true
        security_groups             = [aws_security_group.ad_windows_access.id]
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

    user_data = base64encode(file("/ad_server_windows.ps1"))

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "windows-${local.instance_name}"
            Role = "ad"
        }
    }

    lifecycle {
        create_before_destroy = true
    }
}
#---------Windows File Server-----------
resource "aws_launch_template" "file_windows_template" {
    name_prefix   = "file-windows-template-"
    image_id      = var.windows_ami
    instance_type = var.instance_type
    
    key_name      = var.key_name

    iam_instance_profile {
        name = aws_iam_instance_profile.ec2_instance_profile.name
    }
    network_interfaces {
        associate_public_ip_address = true
        security_groups             = [aws_security_group.file_windows_access.id]
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

    user_data = base64encode(file("/file_server_windows.ps1"))

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "windows-${local.instance_name}"
            Role = "file"
        }
    }

    lifecycle {
        create_before_destroy = true
    }
}

#############################################
#            Auto Scaling Group             #
#############################################
#-------------Linux web server---------------
resource "aws_autoscaling_group" "web_linux_asg" {
    name                = "web-linux-asg-${local.instance_name}"

    desired_capacity    = 1
    max_size            = 3
    min_size            = 1

    target_group_arns         = [aws_lb_target_group.web_linux_tg.arn]
    health_check_type         = "EC2"
    health_check_grace_period = 300
    
    vpc_zone_identifier = [aws_subnet.public_subnet1.id]
    launch_template {
        id      = aws_launch_template.web_linux_template.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "web-linux-${local.instance_name}"
        propagate_at_launch = true
    }
    tag {
        key                 = "Role"
        value               = "web"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_autoscaling_policy" "web_lin_scale_up" {
    name                   = "web-lin-scale-up-${var.region}"
    autoscaling_group_name = aws_autoscaling_group.web_linux_asg.name
    scaling_adjustment     = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
}
#--------------Linux sql server---------------
resource "aws_autoscaling_group" "sql_linux_asg" {
    name                = "sql-linux-asg-${local.instance_name}"

    desired_capacity    = 1
    max_size            = 3
    min_size            = 1

    target_group_arns         = [aws_lb_target_group.sql_linux_tg.arn]
    health_check_type         = "EC2"
    health_check_grace_period = 300
    
    vpc_zone_identifier = [aws_subnet.public_subnet1.id]
    launch_template {
        id      = aws_launch_template.sql_linux_template.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "sql-linux-${local.instance_name}"
        propagate_at_launch = true
    }

    tag {
        key                 = "Role"
        value               = "sql"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_autoscaling_policy" "sql_lin_scale_up" {
    name                   = "sql_lin-scale-up-${var.region}"
    autoscaling_group_name = aws_autoscaling_group.sql_linux_asg.name
    scaling_adjustment     = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
}
#------------Windows IIS Server------------
resource "aws_autoscaling_group" "iis_windows_asg" {
    name                = "iis-windows-asg-${local.instance_name}"

    desired_capacity    = 1
    max_size            = 3
    min_size            = 1

    health_check_type   = "EC2"
    health_check_grace_period = 300

    vpc_zone_identifier = [aws_subnet.public_subnet2.id]

    launch_template {
        id      = aws_launch_template.iis_windows_template.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "iis-windows-${local.instance_name}"
        propagate_at_launch = true
    }
    
    tag {
        key                 = "Role"
        value               = "iis"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_autoscaling_policy" "iis_win_scale_up" {
    name                   = "iis-win-scale-up-${var.region}"
    autoscaling_group_name = aws_autoscaling_group.iis_windows_asg.name
    scaling_adjustment     = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
}
#---------Windows AD Server------------
resource "aws_autoscaling_group" "ad_windows_asg" {
    name                = "ad-windows-asg-${local.instance_name}"

    desired_capacity    = 1
    max_size            = 3
    min_size            = 1

    health_check_type   = "EC2"
    health_check_grace_period = 300

    vpc_zone_identifier = [aws_subnet.public_subnet2.id]

    launch_template {
        id      = aws_launch_template.ad_windows_template.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "ad-windows-${local.instance_name}"
        propagate_at_launch = true
    }
    
    tag {
        key                 = "Role"
        value               = "ad"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_autoscaling_policy" "ad_win_scale_up" {
    name                   = "ad-win-scale-up-${var.region}"
    autoscaling_group_name = aws_autoscaling_group.ad_windows_asg.name
    scaling_adjustment     = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
}
#------------Windows File Server-------------
resource "aws_autoscaling_group" "file_windows_asg" {
    name                = "file-windows-asg-${local.instance_name}"

    desired_capacity    = 1
    max_size            = 3
    min_size            = 1

    health_check_type   = "EC2"
    health_check_grace_period = 300

    vpc_zone_identifier = [aws_subnet.public_subnet2.id]

    launch_template {
        id      = aws_launch_template.file_windows_template.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "file-windows-${local.instance_name}"
        propagate_at_launch = true
    }
    
    tag {
        key                 = "Role"
        value               = "file"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_autoscaling_policy" "file_win_scale_up" {
    name                   = "file-win-scale-up-${var.region}"
    autoscaling_group_name = aws_autoscaling_group.file_windows_asg.name
    scaling_adjustment     = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
}

#############################################
#           Elastic Load Balancer           #
#############################################
#-------------Linux web server---------------
resource "aws_lb_target_group" "web_linux_tg" {
    name     = "web-linux-tg-${var.region}"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.main.id
}
#-------------Linux sql server---------------
resource "aws_lb_target_group" "sql_linux_tg" {
    name     = "sql-linux-tg-${var.region}"
    port     = 3306
    protocol = "TCP"
    vpc_id   = aws_vpc.main.id
}
#--------------Linux web server---------------
resource "aws_lb" "web_linux_lb" {
    name               = "web-linux-lb-${var.region}"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.web_linux_access.id]
    subnets            = [aws_subnet.public_subnet1.id, 
                            aws_subnet.public_subnet2.id]

    tags = {
        Name = "web-linux-lb-${local.instance_name}"
    }
}
#-------------Linux sql server---------------
resource "aws_lb" "sql_linux_lb" {
    name               = "sql-linux-lb-${var.region}"
    internal           = false
    load_balancer_type = "network"
    subnets            = [aws_subnet.public_subnet1.id, 
                            aws_subnet.public_subnet2.id]

    tags = {
        Name = "web-linux-lb-${local.instance_name}"
    }
}
#-------------Linux web server---------------
resource "aws_lb_listener" "web_linux_lb_listener" {
    load_balancer_arn = aws_lb.web_linux_lb.arn
    port              = 80
    protocol          = "HTTP"
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.web_linux_tg.arn
    }
}
#-------------Linux sql server---------------
resource "aws_lb_listener" "sql_linux_lb_listener" {
    load_balancer_arn = aws_lb.sql_linux_lb.arn
    port              = 3306
    protocol          = "TCP"
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.sql_linux_tg.arn
    }
}
#-------------Linux web server---------------
resource "aws_autoscaling_attachment" "web_linux_attach" {
    autoscaling_group_name = aws_autoscaling_group.web_linux_asg.id
    lb_target_group_arn    = aws_lb_target_group.web_linux_tg.arn
}
#-------------Linux sql server---------------
resource "aws_autoscaling_attachment" "sql_linux_attach" {
    autoscaling_group_name = aws_autoscaling_group.sql_linux_asg.id
    lb_target_group_arn    = aws_lb_target_group.sql_linux_tg.arn
}

###############################################
#            CloudWatch Dashboard             #
###############################################
resource "aws_cloudwatch_dashboard" "autodeployment_dashboard" {
    depends_on = [ aws_instance.linux_control_node, aws_instance.windows_control_node,
                    aws_autoscaling_group.web_linux_asg, aws_autoscaling_group.sql_linux_asg, aws_autoscaling_group.iis_windows_asg, aws_autoscaling_group.file_windows_asg,
                    aws_autoscaling_group.ad_windows_asg ]

    dashboard_name = "autodeployment-server-dashboard"
    dashboard_body = jsonencode({
        widgets = [
            {
                type    = "metric"
                x       = 0
                y       = 0
                width   = 24
                height  = 6

                properties = {
                    title   = "Linux-Control-Node Resource"
                    region  = var.region
                    stat    = "Average"
                    period  = 120

                    metrics = [
                        [
                            "AWS/EC2",
                            "CPUUtilization",
                            "InstanceId",
                            "${aws_instance.linux_control_node.id}"
                        ]
                    ]
                }
            },
            {
                type    = "metric"
                x       = 0
                y       = 6
                width   = 24
                height  = 6

                properties = {
                    title   = "Windows-Control-Node Resource"
                    region  = var.region
                    stat    = "Average"
                    period  = 300

                    metrics = [
                        [
                            "AWS/EC2",
                            "CPUUtilization",
                            "InstanceId",
                            "${aws_instance.windows_control_node.id}"
                        ]
                    ]
                }
            },
            {
                type    = "metric"
                x       = 0
                y       = 12
                width   = 24
                height  = 6

                properties = {
                    title   = "Web-Linux-Server Resource"
                    region  = var.region
                    stat    = "Average"
                    period  = 120

                    metrics = [
                        [
                            "AWS/EC2",
                            "CPUUtilization",
                            "AutoScalingGroupName",
                            "${aws_autoscaling_group.web_linux_asg.name}"
                        ]
                    ]
                }
            },
            {
                type    = "metric"
                x       = 0
                y       = 18
                width   = 24
                height  = 6

                properties = {
                    title   = "SQL-Linux-Server Resource"
                    region  = var.region
                    stat    = "Average"
                    period  = 120

                    metrics = [
                        [
                            "AWS/EC2",
                            "CPUUtilization",
                            "AutoScalingGroupName",
                            "${aws_autoscaling_group.sql_linux_asg.name}"
                        ]
                    ]
                }
            },
            {
                type    = "metric"
                x       = 0
                y       = 24
                width   = 24
                height  = 6

                properties = {
                    title   = "IIS-Windows-Server Resource"
                    region  = var.region
                    stat    = "Average"
                    period  = 120

                    metrics = [
                        [
                            "AWS/EC2",
                            "CPUUtilization",
                            "AutoScalingGroupName",
                            "${aws_autoscaling_group.iis_windows_asg.name}"
                        ]
                    ]
                }
            },
            {
                type    = "metric"
                x       = 0
                y       = 30
                width   = 24
                height  = 6

                properties = {
                    title   = "AD-Windows-Server Resource"
                    region  = var.region
                    stat    = "Average"
                    period  = 120

                    metrics = [
                        [
                            "AWS/EC2",
                            "CPUUtilization",
                            "AutoScalingGroupName",
                            "${aws_autoscaling_group.ad_windows_asg.name}"
                        ]
                    ]
                }
            },
            {
                type    = "metric"
                x       = 0
                y       = 36
                width   = 24
                height  = 6

                properties = {
                    title   = "File-Windows-Server Resource"
                    region  = var.region
                    stat    = "Average"
                    period  = 120

                    metrics = [
                        [
                            "AWS/EC2",
                            "CPUUtilization",
                            "AutoScalingGroupName",
                            "${aws_autoscaling_group.file_windows_asg.name}"
                        ]
                    ]
                }
            }
        ]
    })
}

###############################################
#          CloudWatch Alarm Instance          #
###############################################
# CPU Utilization >80%
#-------------Linux Control Node-----------------
resource "aws_cloudwatch_metric_alarm" "linux_control_node_alarm" {
    alarm_description = "Monitoring CPU Utilization"
    alarm_name          = "Linux-Control-Node"
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    statistic           = "Average"
    period              = 120
    evaluation_periods  = 2
    threshold           = 80
    comparison_operator = "GreaterThanThreshold"

    dimensions = {
        InstanceId = aws_instance.linux_control_node.id
    }
}
#------------Windows Control Node---------------
resource "aws_cloudwatch_metric_alarm" "windows_control_node_alarm" {
    alarm_description = "Monitoring CPU Utilization"
    alarm_name          = "Windows-Control-Node"
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    statistic           = "Average"
    period              = 120
    evaluation_periods  = 2
    threshold           = 80
    comparison_operator = "GreaterThanThreshold"

    dimensions = {
        InstanceId = aws_instance.windows_control_node.id
    }
}

###############################################
#           CloudWatch Alarm ASG              #
###############################################
#-------------Linux web server---------------
resource "aws_cloudwatch_metric_alarm" "web_linux_scale_prevention" {
    alarm_description   = "Monitoring CPU utilization"
    alarm_actions       = [aws_autoscaling_policy.web_lin_scale_up.arn]
    alarm_name          = "Web-Linux-CPU-Scale-Up-${local.instance_name}"
    comparison_operator = "GreaterThanThreshold"
    namespace           = "AWS/EC2"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    threshold           = 80
    period              = 120
    statistic           = "Average"

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.web_linux_asg.name
    }
}
#-------------Linux sql server---------------
resource "aws_cloudwatch_metric_alarm" "sql_linux_scale_prevention" {
    alarm_description   = "Monitoring CPU utilization"
    alarm_actions       = [aws_autoscaling_policy.sql_lin_scale_up.arn]
    alarm_name          = "SQL-Linux-CPU-Scale-Up-${local.instance_name}"
    comparison_operator = "GreaterThanThreshold"
    namespace           = "AWS/EC2"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    threshold           = 80
    period              = 120
    statistic           = "Average"

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.sql_linux_asg.name
    }
}
#-----------Windows IIS Server-------------
resource "aws_cloudwatch_metric_alarm" "iis_windows_scale_prevention" {
    alarm_description   = "Monitoring CPU utilization"
    alarm_actions       = [aws_autoscaling_policy.iis_win_scale_up.arn]
    alarm_name          = "IIS-Win-CPU-Scale-Up-${local.instance_name}"
    comparison_operator = "GreaterThanThreshold"
    namespace           = "AWS/EC2"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    threshold           = 80
    period              = 120
    statistic           = "Average"

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.iis_windows_asg.name
    }
}
#----------Windows AD Server-------------
resource "aws_cloudwatch_metric_alarm" "ad_windows_scale_prevention" {
    alarm_description   = "Monitoring CPU utilization"
    alarm_actions       = [aws_autoscaling_policy.ad_win_scale_up.arn]
    alarm_name          = "AD-Win-CPU-Scale-Up-${local.instance_name}"
    comparison_operator = "GreaterThanThreshold"
    namespace           = "AWS/EC2"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    threshold           = 80
    period              = 120
    statistic           = "Average"

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.ad_windows_asg.name
    }
}
#-----------Windows File Server-----------
resource "aws_cloudwatch_metric_alarm" "file_windows_scale_prevention" {
    alarm_description   = "Monitoring CPU utilization"
    alarm_actions       = [aws_autoscaling_policy.file_win_scale_up.arn]
    alarm_name          = "File-Win-CPU-Scale-Up-${local.instance_name}"
    comparison_operator = "GreaterThanThreshold"
    namespace           = "AWS/EC2"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    threshold           = 80
    period              = 120
    statistic           = "Average"

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.file_windows_asg.name
    }
}

###############################################
#            CloudWatch EventBridge           #
###############################################
resource "aws_cloudwatch_event_bus" "autodeployment_bus" {
    name = "autodeployment-server-bus"
}
#----------EC2 Instances Event-----------
resource "aws_cloudwatch_event_rule" "ec2_state_change" {
    name            = "EC2StateChange"
    description     = "Captura cambios de estado de instancias EC2"
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    event_pattern   = file("${path.module}/event_patterns/ec2_changes.json")
}
resource "aws_cloudwatch_event_target" "ec2_state_change_target" {
    rule            = aws_cloudwatch_event_rule.ec2_state_change.name
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    arn             = aws_cloudwatch_log_group.eventbridge_logs.arn
}
#---------Autoscaling Group Event-----------
resource "aws_cloudwatch_event_rule" "autoscaling_activity" {
    name            = "AutoScalingGroupActivity"
    description     = "Autoscaling Group Event"
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    event_pattern   = file("${path.module}/event_patterns/autoscaling_activity.json")
}
resource "aws_cloudwatch_event_target" "autoscaling_activity_target" {
    rule            = aws_cloudwatch_event_rule.autoscaling_activity.name
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    arn             = aws_cloudwatch_log_group.eventbridge_logs.arn
}
#---------RDS Group Event-----------
resource "aws_cloudwatch_event_rule" "rds_failures" {
    name            = "RDSFailures"
    description     = "RDS Show Failures"
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    event_pattern   = file("${path.module}/event_patterns/rds_failures.json")
}
resource "aws_cloudwatch_event_target" "rds_failures_target" {
    rule            = aws_cloudwatch_event_rule.rds_failures.name
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    arn             = aws_cloudwatch_log_group.eventbridge_logs.arn
}
#---------Elastic Load Balancer Group Event-----------
resource "aws_cloudwatch_event_rule" "elb_healthstatus" {
    name            = "ELBHealthStatus"
    description     = "Show ELB Health Status"
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    event_pattern   = file("${path.module}/event_patterns/elb_healthstatus.json")
}
resource "aws_cloudwatch_event_target" "elb_healthstatus_target" {
    rule            = aws_cloudwatch_event_rule.elb_healthstatus.name
    event_bus_name  = aws_cloudwatch_event_bus.autodeployment_bus.name
    arn             = aws_cloudwatch_log_group.eventbridge_logs.arn
}

###############################################
#      CloudWatch EventBridge Archives        #
###############################################
resource "aws_cloudwatch_event_archive" "autodeployment_archive" {
    name                = "Autodeployment-Archive_logs"
    event_source_arn    = aws_cloudwatch_event_bus.autodeployment_bus.arn
    retention_days      = 1
}

###############################################
#           CloudWatch Log Groups             #
###############################################
# Logs de las aplicaciones (CloudWatch Agent)
resource "aws_cloudwatch_log_group" "eventbridge_logs" {
    name              = "/ec2/control-node-logs"
    retention_in_days = 1
}

###############################################
#                 IAM Role                    #
###############################################
resource "aws_iam_role" "ec2_role" {
    name = "ec2-readonly-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }
        ]
    })
}

###############################################
#                IAM Policies                 #
###############################################
resource "aws_iam_policy" "ec2_get_password_data" {
    name        = "EC2GetPasswordDataPolicy"
    description = "Permite llamar a ec2:GetPasswordData"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                "ec2:GetPasswordData"
                ],
                Resource = "*"
            }
        ]
    })
}
resource "aws_iam_role_policy" "eventbridge_to_logs_policy" {
    role = aws_iam_role.ec2_role.id
    name = "EventBridgeLogsPolicy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
            "logs:PutLogEvents",
            "logs:CreateLogStream",
            "logs:DescribeLogStreams"
            ]
            Resource = "${aws_cloudwatch_log_group.eventbridge_logs.arn}:*"
        }
        ]
    })
}

###############################################
#              IAM Attachments                #
###############################################
resource "aws_iam_role_policy_attachment" "ec2_readonly_policy" {
    role       = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_attach" {
    role        = aws_iam_role.ec2_role.name
    policy_arn  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_role_policy_attachment" "attach_get_password_data" {
    role       = aws_iam_role.ec2_role.name
    policy_arn = aws_iam_policy.ec2_get_password_data.arn
}

###############################################
#               IAM Profile                   #
###############################################
resource "aws_iam_instance_profile" "ec2_instance_profile" {
    name = "ec2-instance-profile"
    role = aws_iam_role.ec2_role.name
}