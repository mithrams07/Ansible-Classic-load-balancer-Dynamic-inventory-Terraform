resource "aws_security_group" "webserver" {

  name        = "webserver"
  description = "allows all port conntection"


  ingress {
    description      = ""
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  ingress {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  tags = {
    Name = "${var.project}"
    project = var.project
  }

}

# Classic Loadbalncer


resource "aws_elb" "clb" {

  name_prefix        = "${substr(var.project, 0, 5)}-"
  security_groups    = [aws_security_group.webserver.id]
  availability_zones = [ "ap-south-1a", "ap-south-1b" ]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }


  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    target              = "HTTP:80/health.html"
    interval            = 15
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 60
  connection_draining         = true
  connection_draining_timeout = 5

  tags   = {

    Name = var.project
    project = var.project
  }
}



# Launch Configuration
resource "aws_launch_configuration" "version" {

  name_prefix     = "${var.project}-"
  key_name        = "devops2"
  image_id        = "${var.instance_ami}"
  instance_type   = "t2.micro"
  user_data       = file("setup.sh")
  security_groups = [aws_security_group.webserver.id]
  lifecycle {
    create_before_destroy = true
  }
}



# AutoScaling Group
resource "aws_autoscaling_group" "version" {

  name_prefix               = "${var.project}-"
  launch_configuration      = aws_launch_configuration.version.name
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 2
  health_check_grace_period = 120
  availability_zones = [ "ap-south-1a", "ap-south-1b" ]
  load_balancers            = [ aws_elb.clb.id ]
  wait_for_elb_capacity     = 2
  health_check_type         = "ELB"
  tag {
    key                 = "Name"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "asg"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "project"
    value               = var.project
    propagate_at_launch = true
  }


  lifecycle {
    create_before_destroy = true
  }


}
