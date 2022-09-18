variable "region" {
  default = "us-east-2"
}

variable "cidr_block" {
  default = "172.25.0.0/16"
}

variable "project_name" {
  default = "zomato"
}

variable "project_env" {
  default = "prod"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  default = "ami-0568773882d492fc8"
}

variable "hosted_zone" {
  default = "your-zone-id"
}

variable "ssl_arn" {
  default = "your-ssl-arn"
}
