output "servers_public_ip" {
  value = { for name, server in module.servers : name => server.public_ip }
}

output "servers_private_ip" {
  value = { for name, server in module.servers : name => server.private_ip }
}

output "servers_instance_id" {
  value = { for name, server in module.servers : name => server.instance_id }
}