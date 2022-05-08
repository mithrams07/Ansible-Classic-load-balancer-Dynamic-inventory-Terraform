# Ansible-Dynamic-inventory-using-Terraform

## Description

Here, Our scenario is:

We have classic load balancer which have 2 ec2 instances created from an autoscaling group. The site have website contents which is uploaded via userdata(contents clonned from a git repository) while creating launch configuration. If the git repository is updated with new version of the site, we have to make the changes in our ec2 instances. How can we do it without recreating the servers. Lets check it.

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
