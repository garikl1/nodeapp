output "elb" {
  value = aws_elb.nodeapp_elb.dns_name
}

output "ecr-us-east-2" {
  value = aws_ecr_repository.app.repository_url
}