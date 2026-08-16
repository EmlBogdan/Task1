variable "AZs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "Public_CIDRs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "Private_CIDRs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "Subnet_names" {
  type    = list(string)
  default = ["Bastion_subnet", "Nat_subnet", "Application_subnet", "DB_subnet"]
}

variable "my_ip" {
  type        = string
  description = "Allow my SSH"
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}
