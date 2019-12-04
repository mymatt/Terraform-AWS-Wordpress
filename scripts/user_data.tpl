#!/usr/bin/env bash

sudo mkdir -p /terraform/
sudo chmod -R 755 /terraform/
python --version || sudo apt-get update &&
sudo apt-get -y install python python-pip
sudo pip install ansible boto3 botocore
sudo echo "127.0.0.1 $(hostname)" >> /etc/hosts

sudo cd /terraform/
sudo ansible-pull -U ${tr_git_address} -i 'localhost,' -c local ansible_pull/main.yaml -d /terraform/provisioners/ -e 'reg=${tr_region} s3bucket=${tr_s3bucket} ansible_roles=${tr_ansible_roles} rds_identifier=${tr_rds_identifier} cloudfront_url=${tr_cloudfront_url} name_db=${tr_db_name} username_db=${tr_db_username} password_db=${tr_db_password} backup_bucket=${tr_backup_bucket} backup_prefix=${tr_bucket_prefix_www} backup_www_file=${tr_bucket_backup_file}' -v 2>&1 | sudo tee -a /terraform/log
