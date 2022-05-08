#!/bin/bash
yum install httpd php git -y
git clone https://github.com/mithrams07/aws-elb-site /var/website
cp -r /var/website/* /var/www/html/
chown -R apache:apache /var/www/html/*
systemctl restart httpd.service
systemctl enable httpd.service
