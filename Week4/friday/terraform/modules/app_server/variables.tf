variable "ami_id" {
  description = "AMI ID for the server instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to attach to the instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in"
  type        = string
}

variable "server_name" {
  description = "Name of the service this server runs (api, payments, logs)"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
  default     = "staging"
}
