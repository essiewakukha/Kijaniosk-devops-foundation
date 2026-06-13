provider "aws" {
  region = var.aws_region
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}


# Default VPC

data "aws_vpc" "default" {
  default = true
}


# Subnets in default VPC

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
# Security Group

resource "aws_security_group" "kijanikiosk" {
  name   = "kijanikiosk-staging"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.operator_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# App Servers Module

module "servers" {
  source   = "./modules/app_server"
  for_each = var.servers

  server_name       = each.key
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  key_name          = var.key_name
  security_group_id = aws_security_group.kijanikiosk.id
  subnet_id         = data.aws_subnets.default.ids[0]
  environment       = var.environment
}