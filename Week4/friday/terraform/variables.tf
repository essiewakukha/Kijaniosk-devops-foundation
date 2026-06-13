variable "aws_region" {
  description = "aws_region"
  type        = string
}
variable "operator_ip_cidr" {
  description = "Your IP for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "AWS SSH key pair name"
  type        = string
}


variable "environment" {
  description = "Environment name (e.g., staging)"
  type        = string
}
variable "servers" {
  description = "Map of servers"
  type        = map(any)
}