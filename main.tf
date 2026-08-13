terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

provider "aws" {}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.Public_CIDRs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.AZs[count.index]
  tags = {
    Name = var.Subnet_names[count.index]
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnets[1].id
}



resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "internet_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Internet_Route_Table"
  }
}

resource "aws_route_table_association" "internet_rta" {
  subnet_id      = aws_subnet.public_subnets[0].id
  route_table_id = aws_route_table.internet_route_table.id
}

resource "aws_route_table" "nat_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    "Name" = "Nat_Route_Table"
  }
}

resource "aws_route_table_association" "nat_application_rta" {
  count          = 2
  subnet_id      = aws_subnet.application_subnets[count.index].id
  route_table_id = aws_route_table.nat_route_table.id
}

resource "aws_route_table_association" "nat_rta" {
  subnet_id      = aws_subnet.public_subnets[1].id
  route_table_id = aws_route_table.internet_route_table.id
}

resource "aws_default_route_table" "db_route_table" {
  default_route_table_id = aws_vpc.main_vpc.default_route_table_id
  tags = {
    Name = "Isolated_DB_Route_Table"
  }
}

resource "aws_route_table_association" "db_iso_rta" {
  count          = 2
  subnet_id      = aws_subnet.db_subnet[count.index].id
  route_table_id = aws_default_route_table.db_route_table.id
}

resource "aws_subnet" "application_subnets" {
  count             = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.Private_CIDRs[count.index]
  availability_zone = var.AZs[count.index]
  tags = {
    Name = "${var.Subnet_names[2]}_${count.index + 1}"
  }
}


resource "aws_subnet" "db_subnet" {
  count             = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.Private_CIDRs[count.index + 2]
  availability_zone = var.AZs[count.index]
  tags = {
    Name = "${var.Subnet_names[3]}_${count.index + 1}"
  }
}

resource "aws_instance" "bastion" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.bastion_key.key_name
  tags = {
    Name = "bastion"
  }
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion_key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security group for bastion instance"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "bastion_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_my_ssh" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_bastion_traffic_ipv4" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_bastion_traffic_ipv6" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}


resource "aws_launch_template" "app_at" {
  name_prefix            = "app-template-"
  image_id               = "ami-0b6d9d3d33ba97d99"
  instance_type          = "c7i-flex.large"
  vpc_security_group_ids = [aws_security_group.apps_sg.id]
  key_name               = aws_key_pair.bastion_key.key_name
  user_data              = filebase64("run_ollama.sh")
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "App-ASG"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name_prefix               = "app-asg-"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  health_check_type         = "EC2"
  health_check_grace_period = 60
  vpc_zone_identifier       = aws_subnet.application_subnets[*].id

  launch_template {
    id      = aws_launch_template.app_at.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu_scaling_policy" {
  name                   = "cpu-target-tracking-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 40.0
  }
}

resource "aws_iam_role" "ec2_cw_role" {
  name = "ec2-cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_policy_attach" {
  role       = aws_iam_role.ec2_cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_cw_profile" {
  name = "ec2-cw-instance-profile"
  role = aws_iam_role.ec2_cw_role.name
}

resource "aws_autoscaling_policy" "memory_scaling_policy" {
  name                   = "memory-target-tracking-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    customized_metric_specification {
      metric_name = "mem_used_percent"
      namespace   = "CWAgent"
      statistic   = "Average"
    }

    target_value = 80.0
  }
}

resource "aws_security_group" "apps_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "apps_sg"
  tags = {
    Name = "Apps SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_bastion_ssh" {
  security_group_id = aws_security_group.apps_sg.id
  cidr_ipv4         = "10.0.1.0/24"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_app_traffic_ipv4" {
  security_group_id = aws_security_group.apps_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_app_traffic_ipv6" {
  security_group_id = aws_security_group.apps_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}
