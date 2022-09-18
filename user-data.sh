#!/bin/bash
yum install httpd php git -y

systemctl restart httpd.service
systemctl enable httpd.service

git clone https://github.com/hemanthsaju7/aws-elb-site.git /var/website/
cp -r /var/website/* /var/www/html/
chown -R apache:apache /var/www/html/*
