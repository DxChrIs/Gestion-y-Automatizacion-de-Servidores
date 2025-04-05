output "region" {
    description = "The AWS region to deploy the resources in"
    value = var.region
}
output "route_table_info" {
    value = aws_route_table.private_route_table_1.id
}
# output "instance_id" {
#     description = "The ID of the EC2 instance"
#     value       = aws_instance.my_instance.id
# }
# output "instance_public_ip" {
#     description = "The public IP address of the EC2 instance"
#     value       = aws_instance.my_instance.public_ip
# }
# output "instance_private_ip" {
#     description = "The private IP address of the EC2 instance"
#     value       = aws_instance.my_instance.private_ip
# }
# output "instance_ami" {
#     description = "The AMI ID of the EC2 instance"
#     value       = aws_instance.my_instance.ami
# }
# output "instance_ami_name" {
#     description = "The AMI name of the EC2 instance"
#     value       = aws_instance.my_instance.ami_name
# }
