# Ansible-Dynamic-inventory-using-Terraform

## Description

Here, Our scenario is:

Consider we have classic load balancer which have 2 ec2 instances created from an autoscaling group. The site have website contents which is uploaded via below userdata(contents clonned from a git repository) while creating launch configuration.

```
#!/bin/bash
yum install httpd php git -y
git clone https://github.com/mithrams07/aws-elb-site /var/website
cp -r /var/website/* /var/www/html/
chown -R apache:apache /var/www/html/*
systemctl restart httpd.service
systemctl enable httpd.service
```
If the git repository is updated with new version of the site, we have to make the changes in our ec2 instances. How can we do it without recreating the servers. Lets check it.

We can do this by Ansible. Here I am using Terraform to build the infra.


## Pre-Requests

Terraform installation
```
$ wget https://releases.hashicorp.com/terraform/1.1.7/terraform_1.1.7_linux_amd64.zip
$ unzip terraform_1.1.7_linux_amd64.zip 
$ ls -l
total 80136
-rwxr-xr-x 1 ec2-user ec2-user 63262720 Mar  2 19:17 terraform
-rw-rw-r-- 1 ec2-user ec2-user 18795309 Mar  2 19:32 terraform_1.1.7_linux_amd64.zip

$ sudo mv terraform /usr/local/bin/
$ terraform version
Terraform v1.1.7
on linux_amd64
```

Ansible installation
```
sudo amazon-linux-extras install ansible2 -y
```

## Code

Below is the code to build infra using Terraform.
```
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
```

Here I have mentioned the key that I already have. If you want to create a new key-pair add the below code above code.
```
resource "aws_key_pair" "mykey" {

  key_name   = "${var.project}-key"
  public_key = file("../key/terrakey.pub")
  tags = {
    Name = "${var.project}-key"
    project = var.project
  }

}
```
And in replace the value of "key_name" as following.
```
  key_name = aws_key_pair.mykey.id
  ```
  
  Output.tf will be like below:
  
  ```
  data "aws_instances" "asg" {

  instance_tags = {
    Name = var.project
   }
}

output "instance" {

  value = data.aws_instances.asg.public_ips
}
```
That means the output will be the Public IP addresses of 2 ec2 instances.

provider.tf and variable.tf files are attached.

Now lets have a look into ansible-playbook and understand how can we update website contents without server recreation. Please note that we are able to apply this method only because the the content is updated using userdata. I have combined 2 plays in this playbook.

### Ansible-playbook

```
---
- name: "Aws Infrastructure using ansible"
  hosts: localhost
  become: true

  tasks:
    - name: Basic deploy of a service
      community.general.terraform:
        project_path: "./terr/"
        state: present
        force_init: true
      register: inst

    - name: "Print the Public IPs"
      debug:
        msg: "Instance-Id : {{ item }}"
      with_items: "{{ inst.outputs.instance.value }}"

    - name: "Creating Dynamic Inventory"
      add_host:
        hostname: '{{ item }}'
        groups: "backend"
        ansible_host: '{{ item }}'
        ansible_port: 22
        ansible_user: "ec2-user"  
        ansible_ssh_private_key_file: "ansible.pem"
        ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
      with_items:
        - "{{ inst.outputs.instance.value }}"


- name: "Deployment From GitHub"
  hosts: backend
  become: true
  serial: 1
  vars:
    packages:
      - httpd
      - php
      - git
    repo: https://github.com/mithrams07/aws-elb-site.git
  tasks:

    - name: "Package Installation"
      yum:
        name: "{{ packages }}"
        state: present

    - name: "Clonning Github Repository {{ repo }}"
      git:
        repo: "{{ repo }}"
        dest: "/var/website/"
      register: gitstatus

    - name: "Backend off loading from elb"
      when: gitstatus.changed
      file:
        path: "/var/www/html/health.html"
        mode: 0000

    - name: "waiting for connection draining"
      when: gitstatus.changed
      wait_for:
        timeout: 30

    - name: "updating site contents"
      when: gitstatus.changed
      copy:
        src: "/var/website/"
        dest: "/var/www/html/"
        remote_src: true
        owner: apache
        group: apache

    - name: "loading backend to elb"
      when: gitstatus.changed
      file:
        path: "/var/www/html/health.html"
        mode: 0644

    - name: "waiting for connection draining"
      when: gitstatus.changed
      wait_for:
        timeout: 20
```

Let me **explain each task** in Playbook

#### Play 1

***Task 1 : Basic deploy of a service***
       Here using the "community.general.terraform" module and mentioning the terraform project path, our terraform code will be executed and whole infra will be created. The output is then storing to the "inst" .
       
***Task 2: Print the Public IPs***
Using the value stored in "inst" of previous task, print the public IP address of 2 ec2 instances.
 
***Task 3: Creating Dynamic Inventory***
Using the value stored in "inst" of 1st task, that is using those public IP addresses, inventory file will be created

#### Play 2

By default, Ansible runs each task on all hosts affected by a play before starting the next task on any host (by default upto 5 servers). Here inorder to avoid down time, we have to execute all tasks for 1 server then for the remaining. For that purpose, we can use the serial keyword. Here we used the serial keyword and it is set to 1. Hence all tasks will be bexecuted for the 1st server then for the second one.

***Task 1: Package Installation***
Install php, httpd and git packages on server.

***Task 2: Clonning Github Repository***
Clonning git repository https://github.com/mithrams07/aws-elb-site.git to directory /var/website/ and register it to variable gitstatus.

***Task 3: Backend off loading from elb***
Server heath check is confirming by checking the file health.html.By making its permission to 000, the server will be offloaded from the load balancer after 30 seconds.

***Task 4: waiting for connection draining***
waiting for connection draining time. 

***Task 5: updating site contents***
Now the one of the servers is in offloaded state. In this task the updated website content that we have clonned in task 2 will be copied to /var/www/html/. This task will be excuted only when the register variable gitstatus changed status is true.

***Task 6: loading backend to elb***
Here the health.html file permission will be reverted to 644 and server will be again inservice status in load balancer.

***Task 7 : waiting for connection draining"***
Wait for the connection draining time. Server will be active then.

The tasks 3, 4, 5, 6 and 7 will be excuted only when the gitstatus changed state is true. That means only when the git repository is updated with new version of the site.


## Conclusion

Here I have explained about how to update the site newer version without server recreation (load balancer + autoscaling group) only applicable when the site update is via userdata.


