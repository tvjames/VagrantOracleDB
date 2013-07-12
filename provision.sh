#!/bin/bash

if [ -f "/var/vagrant_provision" ]; then 
	exit 0
fi

echo "Performing provisioning..."
echo "Running as: " `whoami`

yum update -y
yum install -y puppet

echo "127.0.0.1     oracle oracle.vagrantup.com" >> /etc/hosts

# http://en.kioskea.net/faq/4405-linux-installing-oracle-11g-on-ubuntu
# http://www.makina-corpus.org/blog/howto-install-oracle-11g-ubuntu-linux-1204-precise-pangolin-64bits


date >> /etc/vagrant_provisioned_at
touch /var/vagrant_provision

