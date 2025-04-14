output "region" {
    description = "The AWS region to deploy the resources in"
    value = var.region
}
output "key_name" {
    description = "The name of the key pair to use for SSH access to the instance"
    value = var.key_name
}