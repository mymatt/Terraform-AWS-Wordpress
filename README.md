## Overview

- Automates the process of Migrating an existing local wordpress site (using mysql) to AWS Creating a new Wordpress site running on EC2 instances with images served via a cloudfront distribution from an S3 bucket and an RDS database
- Terraform creates and manages the AWS infrastructure, with Ansible providing provisioning.
- HTTPS is setup using AWS Certificate Manager which validates and manages certificates on the Elastic Load Balancer, which uses the SNI protocol, and on the Cloudfront distribution. Validation via DNS
- Regarding the DB migration, Terraform RDS S3 Import process (using RestoreDBInstanceFromS3) is automated whereby DB content is backed up to an S3 bucket using percona and then loaded into a new RDS instance. RestoreDBInstanceFromS3 uses mysql 5.7.22
- Autoscaling group with Cloudwatch metrics based on CPU Utilization are created.
- terraform user_data & template are used for provisioning
- ansible-pull is used to pull an ansible playbook from github that then retrieves and executes a set of ansible roles from an s3 bucket
- ansible roles are: wordpress and db_migrate
- wordpress ansible role installs wordpress (php), generates wordpress configuration files, configures apache server (url rewrites to cloudfront for images, file ownership/permissions, alternate port access) and imports an existing wordpress site from an S3 bucket
- db_migrate role uses Vault to access AWS credentials
- an EC2 IAM role is setup for s3 access via ansible (boto3), and for RDS to access backup S3 buckets
- Bastion setup for SSH access with terraform generating keys locally
- terraform state stored on s3 bucket
- Bastion and Load Balancer on public subnet, Web on private subnet
- NAT gateway setup for outbound from private subnet
- Origin Access Identity used to limit access to cloudfront source (S3 bucket)
- Route53 alias 'A' record for ELB setup and S3 Cloudfront distribution 


### Installing

1. Install Terraform with appropriate system package. Update PATH

2. Setup credentials here ~/.aws/credentials
```
[profile_name]
aws_access_key_id = ""
aws_secret_access_key = ""
region = us-east-2
```
or ~/.bashrc
```
export AWS_REGION='ap-southeast-2'
export AWS_PROFILE=xxxx
export AWS_ACCESS_KEY_ID=xxxxx
export AWS_SECRET_ACCESS_KEY=xxxxxx
```

3. Vault Server setup with details contained within ~/.bashrc
```
export VAULT_ADDR=xxxxxxx
export VAULT_TOKEN=xxxxxxx
```
Add the following keys
```
vault kv put secret/aws AWS_ACCESS_KEY_ID=xxxxxxx AWS_SECRET_ACCESS_KEY=xxxxxxxx
```

See https://github.com/mymatt/Vault for setting up local vault server

NOTE: This project uses 2 methods for retrieving AWS credentials, purely for demonstration purposes. One can remove vault references and use the credentials setup at ~/.aws

4. Change variables in io.tf file for aws profile, credentials file, s3 bucket, and for ones own domain name:
```
./var_tf.sh -v "variable_name1=foo variable_name2=bar"
```
```
./var_tf.sh -v "ec2profile=foo cred_file=bar s3_bucket_name=baz www_domain_name=yourname.com"
```

5. Zip each ansible role folder separately from Ansible_Roles repo and upload to own bucket (bucket name added to variables above)

6. Run Terraform
```
terraform init
terraform plan
terraform apply -var="db-UN=$WP_USER" -var="db-PW=$WP_PASS"
```
Where db-UN and db-PW are the username and password for the existing database to be migrated, and which will be used for the new RDS database. In this case environmental variables $WP_USER and $WP_PASS were used

7. ssh into Bastion using private key key_ec2.pem, which is generated by terraform
```
ssh -i key_ec2.pem ubuntu@bastion_ip
```
#### License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
