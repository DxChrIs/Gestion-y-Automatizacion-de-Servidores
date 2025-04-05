output "region" {
    description = "The AWS region to deploy the resources in"
    value = var.region
}
output "instance_id" {
    description = "The ID of the EC2 instance"
    value       = aws_instance.linux_instance.id
}
output "instance_public_ip" {
    description = "The public IP address of the EC2 instance"
    value       = aws_instance.linux_instance.public_ip
}
output "instance_private_ip" {
    description = "The private IP address of the EC2 instance"
    value       = aws_instance.linux_instance.private_ip
}
output "instance_ami" {
    description = "The AMI ID of the EC2 instance"
    value       = aws_instance.linux_instance.ami
}