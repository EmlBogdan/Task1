data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = "db_creds"
}

locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.db_credentials.secret_string
  )
}

resource "aws_db_instance" "postgres" {
  identifier             = "ollama-postgres"
  engine                 = "postgres"
  engine_version         = "18.3"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.ollama_db_group.name

  db_name  = "postgres"
  username = local.db_creds.username
  password = local.db_creds.password
}

resource "aws_db_subnet_group" "ollama_db_group" {
  name       = "ollama_db_group"
  subnet_ids = aws_subnet.db_subnet[*].id

}

resource "aws_security_group" "db_security_group" {
  name   = "db_sg"
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "db_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_postgres_for_asg" {
  security_group_id = aws_security_group.db_security_group.id
  cidr_ipv4         = "10.0.0.0/16"
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.db_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

output "postgres_endpoint" {
  description = "PostgreSQL connection endpoint"
  value       = aws_db_instance.postgres.endpoint
}

