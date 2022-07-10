output "vpc" {
  value = aws_vpc.this
}


output "sg_public_id" {
  value = aws_security_group.public.id
}
output "sg_open_id" {
  value = aws_security_group.open.id
}
output "sg_private_id" {
  value = aws_security_group.private.id
}

output "internet_gateway_id" {
  value = try(aws_internet_gateway.this[0].id, null)
}

output "subnets" {
 value = aws_subnet.this
}

output "transit_gateway_attachment_id" {
  value = try(aws_ec2_transit_gateway_vpc_attachment.this[0].id, null)
}
