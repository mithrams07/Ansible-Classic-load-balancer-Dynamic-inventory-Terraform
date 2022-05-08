data "aws_instances" "ASG" {
  instance_tags = {
    Name = var.project
   }
}


output "instance" {

  value = data.aws_instances.ASG.public_ips
}
