variable "AZs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "Public_CIDRs" {
  type    = list(string)
  default = ["10.0.0.0/27", "10.0.0.32/27"]
}

variable "Private_CIDRs" {
  type    = list(string)
  default = ["10.0.0.64/27", "10.0.0.96/27", "10.0.0.128/27", "10.0.0.160/27"]
}

variable "Subnet_names" {
  type    = list(string)
  default = ["Bastion_subnet", "Nat_subnet", "Application_subnet", "DB_subnet"]
}
