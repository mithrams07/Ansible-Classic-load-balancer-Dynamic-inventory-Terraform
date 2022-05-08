data "aws_instances" "asg" {

  instance_tags = {
    Name = var.project
   }
}

output "instance" {

  value = data.aws_instances.asg.public_ips
}
