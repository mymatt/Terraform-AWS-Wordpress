#!/usr/bin/env bash

sudo mkdir -p /terraform/
sudo chmod -R 755 /terraform/
sudo /usr/bin/apt-get update
sudo /usr/bin/apt-get -y install software-properties-common python3-dev python3 python3-pip python3-virtualenv libyaml-dev python3-httplib2
sudo /usr/bin/pip3 install ansible boto3 botocore hvac
sudo echo "127.0.0.1 $(hostname)" >> /etc/hosts

sudo cd /terraform/
sudo ansible-pull -U ${tr_git_address} -i 'localhost,' -c local provisioners/ansible_pull.yaml -d /terraform/ -e 'reg=${tr_region} s3bucket=${tr_s3bucket} ansible_roles=${tr_ansible_roles} rds_identifier=${tr_rds_identifier} cloudfront_url=${tr_cloudfront_url} name_db=${tr_db_name} username_db=${tr_db_username} password_db=${tr_db_password} backup_bucket=${tr_backup_bucket} backup_prefix=${tr_bucket_prefix_www} backup_www_file=${tr_bucket_backup_file}' -vv 2>&1 | sudo tee -a /terraform/log
