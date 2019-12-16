#---------------------------------------------------
# Inputs
#---------------------------------------------------

variable "ec2profile" {
  default = "ec2play"
}

variable "cred_file" {
  default = "~/.aws/credentials"
}

variable "region" {
  default = "ap-southeast-2"
}

variable "availability_zone_1" {
  default = "ap-southeast-2a"
}

variable "availability_zone_2" {
  default = "ap-southeast-2b"
}

variable "s3_bucket_name" {
  default = "ansibleroles"
}

variable "s3_bucket_media_name" {
  default = "media-assets-mm"
}

variable "s3_bucket_backup_name" {
  default = "backup-db-web-mm"
}

variable "s3_bucket_db_prefix" {
  default = "db"
}

variable "s3_bucket_www_prefix" {
  default = "www"
}

variable "s3_bucket_www_backup_file" {
  default = "backup.tgz"
}

variable "migrate_playbook" {
  default = "scripts/migrate_playbook.yaml"
}

variable "instance_type" {
  default = "t2.micro"
}

# names must be unique
variable "instance_config_asg" {
  type = map

  default = {
    "0" = {
      name = "web"

      region = "ap-southeast-2"

      availability_zone = "ap-southeast-2a"

      instance_type = "t2.micro"

      roles = "web"

      subnet = "private"

      security_group = "web_sg"

      port = "80"

      min = "1"

      max = "3"

      desired = "2"

      min_elb = "2"
    }
  }
}

# names must be unique
variable "instance_config" {
  type = map

  default = {
    "0" = {
      name = "bastion"

      region = "ap-southeast-2"

      availability_zone = "ap-southeast-2a"

      instance_type = "t2.micro"

      roles = "bastion"

      subnet = "public"

      security_group = "bastion_sg_pub"
    }
  }
}

variable "role_profiles" {
  type = map

  default = {
    web = ["wordpress"]

    bastion = ["nil"]
  }
}

variable "rds_config" {
  type = map

  default = {
    "0" = {
      identifier = "dbwp"

      allocated_storage = 20

      storage_type = "gp2"

      engine = "mysql"

      engine_version = "5.7.22"

      instance_class = "db.t2.micro"

      name = "dbwp"

      UN = ""

      PW = ""

      parameter_group_name = "default.mysql5.7"

      multi_az = "false"

      vpc_security_group_ids = "aws_security_group.rds_sg.id"

      port = "3306"
    }
  }
}

variable "elb_config" {
  type = map

  default = {
    "0" = {
      name           = "elbweb"
      subnet         = "public"
      security_group = "elb_web_sg"
      internal       = "false"
    }
  }
}

variable "elb_num" {
  default = "1"
}

variable "amis" {
  type = map

  default = {
    "ap-southeast-2" = "ami-5e8bb23b"
  }
}

variable "key_name" {
  default = "key_ec2"

  # default = "ec2_tf"
}

variable "private_ssh_key_path" {
  default = "~/.ssh/ec2_tf.pem"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  default = "10.0.2.0/24"
}

variable "private_subnet_cidr" {
  default = "10.0.3.0/24"
}

variable "private_subnet_2_cidr" {
  default = "10.0.4.0/24"
}

variable "dns_zone" {
  default = "tf.local"
}

variable "git_address" {
  default = "https://github.com/mymatt/Terraform-AWS-Wordpress.git"
}

variable "ami_name" {
  default = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"
}

variable "ami_type" {
  default = "hvm"
}

variable "ami_owner" {
  default = "099720109477" #Canonical
}

variable "rds_port" {
  default = "3306"
}

variable "sg" {
  default = "aws_security_group"
}

variable "id" {
  default = "id"
}

variable "www_domain_name" {
  default = "mattmyers.me"
}

variable "root_domain_name" {
  default = "mattmyers.me"
}

variable "s3_origin_id" {
  default = "media-assets-mm"
}

variable "db-UN" {
  default = ""
}

variable "db-PW" {
  default = ""
}

#---------------------------------------------------
# Outputs
#---------------------------------------------------

# output "proxy_public_ip" {
#   value = "${join(",", aws_eip.proxy.*.public_ip)}"
# }
#
# output "proxy_dns" {
#   value = "${data.aws_instance.proxy.public_dns}"
# }

output "bastion_public_ip" {
  value = "${data.aws_instance.bastion.public_ip}"
}

output "ext_proxy_elb_dns" {
  value = "${element(aws_elb.elb.*.dns_name, 0)}"
}
