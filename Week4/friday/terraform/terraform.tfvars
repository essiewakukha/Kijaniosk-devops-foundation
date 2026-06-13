aws_region       = "us-west-2"
instance_type    = "t3.micro"
key_name         = "terraform-key-new"
operator_ip_cidr = "41.212.10.176/32"
environment      = "staging"

servers = {
  api      = {}
  payments = {}
  logs     = {}
}