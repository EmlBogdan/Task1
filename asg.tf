resource "aws_launch_template" "app_at" {
  name_prefix            = "app-template-"
  image_id               = "ami-067b421a0a52b1e07"
  instance_type          = "t3.large"
  vpc_security_group_ids = [aws_security_group.apps_sg.id]
  key_name               = aws_key_pair.bastion_key.key_name
  iam_instance_profile {
    arn = aws_iam_instance_profile.cw_role_profile.arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
    }
  }
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
  health_check_grace_period = 300
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

    target_value = 70.0
  }
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


    target_value = 40.0
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
