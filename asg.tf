resource "aws_launch_template" "app_at" {
  name_prefix            = "app-template-"
  image_id               = "ami-0d2aff5bf3ccf067b"
  instance_type          = "t3.medium"
  vpc_security_group_ids = [aws_security_group.apps_sg.id]
  key_name               = aws_key_pair.bastion_key.key_name
  user_data = base64encode(
    <<-EOF
                              #!/bin/bash
                              export PGPASSWORD="${aws_db_instance.postgres.password}"
                              psql -h ${aws_db_instance.postgres.address} -p 5432 -U ${aws_db_instance.postgres.username} -d postgres -c 'CREATE EXTENSION IF NOT EXISTS vector;'
                              EOF 
  )
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

  depends_on = [
    aws_db_instance.postgres
  ]
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

