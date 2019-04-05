variable "tag" {
  default = "test"
}

variable "subnet" {
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "Run the EC2 Instances in these Availability Zones"
  type = "list"
  default = ["euw1-az1", "euw1-az3", "euw1-az2"]
}
variable "region" {
  default = "eu-west-1"
}

variable "PublicIP" {
  default = "10.12.12.1"
}

variable "db_ports" {
  default = ["3306", "1433", "5432"]
}

variable "web_ports" {
  default = ["80", "433"]
}

variable "app_ports" {
  default = ["80", "433"]
}

variable "provision_acl" {
  default = true
}

variable "zones" {
  default = ["app", "db", "tools", "web"]
}
