#---------------------------------------------------
# Terraform State file Location on S3 Bucket
#---------------------------------------------------
terraform {
  backend "s3" {
    bucket  = "tf-m-state"
    key     = "terraform_aws_wp.tfstate"
    region  = "ap-southeast-2"
    profile = "ec2play"
  }
}

#---------------------------------------------------
# AWS Provider - Credentials for Authentication
#---------------------------------------------------
provider "aws" {
  region                  = var.region
  shared_credentials_file = var.cred_file
  profile                 = var.ec2profile
}

provider "aws" {
  alias = "east"
  region = "us-east-1"
}

#---------------------------------------------------
# Create SSH key for Bastion Access
#---------------------------------------------------
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.generated.public_key_openssh
}

resource "local_file" "vpc_id" {
  content  = tls_private_key.generated.private_key_pem
  filename = "${var.key_name}.pem"

  provisioner "local-exec" {
    command = "chmod 600 ${var.key_name}.pem"
  }
}

#---------------------------------------------------
# Setup IAM policies for accessing AWS S3, EC2, RDS and Loadbalancers
#---------------------------------------------------
resource "aws_iam_role" "ec2_access_role" {
  name               = "ec2_role"
  assume_role_policy = data.aws_iam_policy_document.ec2policy.json
}

resource "aws_iam_role" "rds_access_role" {
  name               = "rds_role"
  assume_role_policy = data.aws_iam_policy_document.rdspolicy.json
}

data "aws_iam_policy_document" "ec2policy" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "rdspolicy" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "rds.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_iam_profile"
  role = aws_iam_role.ec2_access_role.name
}

resource "aws_iam_instance_profile" "rds_profile" {
  name = "rds_iam_profile"
  role = aws_iam_role.rds_access_role.name
}

data "aws_iam_policy_document" "ec2_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "s3:PutObject",
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "rds:Describe*",
    ]
    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "rds_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "s3:PutObject",
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::*",
    ]
  }
}

resource "aws_iam_policy" "allow_ec2_access_policy" {
  name        = "ec2_policy"
  description = "A ec2 policy"
  policy      = data.aws_iam_policy_document.ec2_access.json
}

resource "aws_iam_policy" "allow_rds_access_policy" {
  name        = "rds_policy"
  description = "A rds policy"
  policy      = data.aws_iam_policy_document.rds_access.json
}

resource "aws_iam_policy_attachment" "ec2-attach" {
  name       = "ec2_attach_policy"
  roles      = [aws_iam_role.ec2_access_role.name]
  policy_arn = aws_iam_policy.allow_ec2_access_policy.arn
}

resource "aws_iam_policy_attachment" "rds-attach" {
  name       = "rds_attach_policy"
  roles      = [aws_iam_role.rds_access_role.name]
  policy_arn = aws_iam_policy.allow_rds_access_policy.arn
}

#---------------------------------------------------
# Create Bucket for Images served over cloudfront
#---------------------------------------------------

resource "aws_s3_bucket" "media_assets" {
  bucket = var.s3_bucket_media_name
  acl    = "private"

  tags = {
    Name = "Media_Assets"
  }
}

#---------------------------------------------------
# Create Bucket for apache and mysql backup
#---------------------------------------------------

resource "aws_s3_bucket" "backup" {
  bucket = var.s3_bucket_backup_name
  acl    = "private"

  tags = {
    Name = "Backups"
  }
}

#---------------------------------------------------
# Migrate web server and db to S3 buckets
#---------------------------------------------------

resource "null_resource" "web_db_migration" {
  depends_on = [aws_s3_bucket.backup, aws_s3_bucket.media_assets]

  # provisioner "local-exec" {
  #   command = "sudo /usr/bin/apt-get -y install software-properties-common python3-dev python3 python3-pip python3-virtualenv libyaml-dev python3-httplib2"
  # }
  #
  # provisioner "local-exec" {
  #   command = "sudo /usr/bin/pip3 install ansible boto3 botocore hvac"
  # }

  provisioner "local-exec" {
    command = "ansible-playbook --connection=local --inventory 127.0.0.1, ${var.migrate_playbook} -vv -e 'ansible_python_interpreter=/usr/bin/python3 media_bucket=${var.s3_bucket_media_name} backup_bucket=${var.s3_bucket_backup_name} bucket_prefix_db=${var.s3_bucket_db_prefix} bucket_prefix_www=${var.s3_bucket_www_prefix} bucket_backup_file=${var.s3_bucket_www_backup_file} db_user=${var.db-UN} db_pass=${var.db-PW}' "
  }

  triggers = {
    before = aws_s3_bucket.backup.id
  }
}

#---------------------------------------------------
# Get Latest AMI
#---------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "virtualization-type"
    values = [var.ami_type]
  }

  owners = [var.ami_owner]
}

#---------------------------------------------------
# Local variables for use in Dynamic Creation of resources
#---------------------------------------------------
locals {
  count_inst     = "${length(var.instance_config) >= 1 ? length(var.instance_config) : 0 }"
  count_inst_asg = "${length(var.instance_config_asg) >= 1 ? length(var.instance_config_asg) : 0 }"
  count_elb      = "${length(var.elb_config) >= 1 ? length(var.elb_config) : 0 }"
  count_db       = "${length(var.rds_config) >= 1 ? length(var.rds_config) : 0 }"
}

#---------------------------------------------------
# Setup template file for shell and ansible provisioning
#---------------------------------------------------
data "template_file" "user_data" {
  count = local.count_inst

  template = "${file("scripts/user_data.tpl")}"

  vars = {
    tr_git_address   = "${var.git_address}"
    tr_region        = "${var.region}"
    tr_s3bucket      = "${var.s3_bucket_name}"
    tr_ip            = "${lookup(var.instance_config[count.index], "subnet")=="private" ? cidrhost(var.private_subnet_cidr, count.index + 21) : cidrhost(var.public_subnet_cidr, count.index + 21)}"
    tr_ansible_roles = "${jsonencode(var.role_profiles[lookup(var.instance_config[count.index], "roles")])}"

    tr_rds_identifier = "${lookup(var.rds_config[count.index], "identifier")}"
    tr_db_name = "${lookup(var.rds_config[count.index], "name")}"
    tr_db_username = "${lookup(var.rds_config[count.index], "UN")}"
    tr_db_password = "${lookup(var.rds_config[count.index], "PW")}"

    tr_cloudfront_url = "${var.www_domain_name}"

    tr_backup_bucket = "${var.s3_bucket_backup_name}"
    tr_bucket_prefix_www = "${var.s3_bucket_www_prefix}"
    tr_bucket_backup_file = "${var.s3_bucket_www_backup_file}"

  }
}

#---------------------------------------------------
# Create single EC2 instances not in ASG: bastion
#---------------------------------------------------
resource "aws_instance" "tf_example" {
  count = local.count_inst

  private_ip             = lookup(var.instance_config[count.index], "subnet")=="private" ? cidrhost(var.private_subnet_cidr, count.index + 21) : cidrhost(var.public_subnet_cidr, count.index + 21)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = lookup(var.instance_config[count.index], "instance_type")
  key_name               = aws_key_pair.generated_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.bastion_sg_pub.id]
  subnet_id              = lookup(var.instance_config[count.index], "subnet")=="private" ? aws_subnet.private-subnet.id : aws_subnet.public-subnet.id

  tags = {
    Name = lookup(var.instance_config[count.index], "name")
  }
}

#---------------------------------------------------
# Create AWS launch configurations for ASG's
#---------------------------------------------------
resource "aws_launch_configuration" "tf_lc" {
  count = local.count_inst_asg

  # name     = "${lookup(var.instance_config_asg[count.index], "name")}"
  image_id = data.aws_ami.ubuntu.id

  instance_type        = lookup(var.instance_config_asg[count.index], "instance_type")
  key_name             = aws_key_pair.generated_key.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  security_groups = [aws_security_group.web_sg.id]


  user_data = element(data.template_file.user_data.*.rendered, count.index)

  lifecycle {
    create_before_destroy = true
  }
}

#---------------------------------------------------
# Create AWS autoscaling groups
#---------------------------------------------------
resource "aws_autoscaling_group" "tf_asg" {
  count = local.count_inst_asg

  depends_on = [aws_elb.elb]

  name                 = "${lookup(var.instance_config_asg[count.index], "name")}-${element(aws_launch_configuration.tf_lc.*.name, count.index)}"
  launch_configuration = element(aws_launch_configuration.tf_lc.*.name, count.index)

  load_balancers = [lookup(var.elb_config[count.index], "name")]

  vpc_zone_identifier = [aws_subnet.private-subnet.id, aws_subnet.private-subnet-2.id]

  min_size          = lookup(var.instance_config_asg[count.index], "min")
  max_size          = lookup(var.instance_config_asg[count.index], "max")
  desired_capacity = lookup(var.instance_config_asg[count.index], "desired")

  health_check_type = "ELB"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = lookup(var.instance_config_asg[count.index], "name")
    propagate_at_launch = true
  }
}

#---------------------------------------------------
# Certificate Management ELB
#---------------------------------------------------

resource "aws_acm_certificate" "cert" {
  domain_name       = var.www_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "zone" {
  name         = var.www_domain_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.zone.id
  records = [aws_acm_certificate.cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

#---------------------------------------------------
# Certificate Management Cloudfront
#---------------------------------------------------

resource "aws_acm_certificate" "cert2" {
  provider = aws.east
  domain_name       = var.www_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation2" {
  provider = aws.east
  allow_overwrite = true
  name    = aws_acm_certificate.cert2.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cert2.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.zone.id
  records = [aws_acm_certificate.cert2.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert2" {
  provider = aws.east
  certificate_arn         = aws_acm_certificate.cert2.arn
  validation_record_fqdns = [aws_route53_record.cert_validation2.fqdn]
}

#---------------------------------------------------
# Create AWS Classic Elastic Load Balancer
#---------------------------------------------------
resource "aws_elb" "elb" {
  count = local.count_elb

  depends_on = [aws_acm_certificate_validation.cert]

  name  = lookup(var.elb_config[count.index], "name")

  subnets = ["${lookup(var.elb_config[count.index], "subnet")=="private" ? aws_subnet.private-subnet.id : aws_subnet.public-subnet.id}", "${lookup(var.elb_config[count.index], "subnet")=="private" ? aws_subnet.private-subnet-2.id : aws_subnet.public-subnet-2.id}"]

  security_groups = [aws_security_group.elb_web_sg.id]

  cross_zone_load_balancing = true

  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  internal = lookup(var.elb_config[count.index], "internal")

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:80/"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 8888
    instance_protocol = "http"
  }

  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = 8888
    instance_protocol  = "http"
    ssl_certificate_id = aws_acm_certificate_validation.cert.certificate_arn
  }

  tags = {
    Name = lookup(var.elb_config[count.index], "name")
  }
}

#---------------------------------------------------
# Scaling Up - Policy and Alarm
#---------------------------------------------------
resource "aws_autoscaling_policy" "up_policy" {
  count = local.count_inst_asg
  name = "up_policy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = element(aws_autoscaling_group.tf_asg.*.name, count.index)
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  count = local.count_inst_asg
  alarm_name = "alarm_cpu_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "80"

  dimensions = {
    AutoScalingGroupName = element(aws_autoscaling_group.tf_asg.*.name, count.index)
  }

  alarm_description = "CPU utilization EC2 - Up"
  alarm_actions = [element(aws_autoscaling_policy.up_policy.*.arn, count.index)]
}

#---------------------------------------------------
# Scaling Down - Policy and Alarm
#---------------------------------------------------
resource "aws_autoscaling_policy" "down_policy" {
  count = local.count_inst_asg
  name = "down_policy"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = element(aws_autoscaling_group.tf_asg.*.name, count.index)
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  count = local.count_inst_asg
  alarm_name = "alarm_cpu_down"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "10"

  dimensions = {
    AutoScalingGroupName = element(aws_autoscaling_group.tf_asg.*.name, count.index)
  }

  alarm_description = "CPU utilization EC2 - Down"
  alarm_actions = [element(aws_autoscaling_policy.up_policy.*.arn, count.index)]
}

#---------------------------------------------------
# Attach Autoscaling groups to elb
#---------------------------------------------------
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  count = local.count_inst_asg
  autoscaling_group_name = element(aws_autoscaling_group.tf_asg.*.id, count.index)
  elb                    = element(aws_elb.elb.*.id, count.index)
}

#---------------------------------------------------
# Create RDS DB for Wordpress
#---------------------------------------------------
resource "aws_db_instance" "db_wp" {
  count = local.count_db

  depends_on = [null_resource.web_db_migration]

  identifier             = lookup(var.rds_config[count.index], "identifier")
  allocated_storage      = lookup(var.rds_config[count.index], "allocated_storage")
  storage_type           = lookup(var.rds_config[count.index], "storage_type")
  engine                 = lookup(var.rds_config[count.index], "engine")
  engine_version         = lookup(var.rds_config[count.index], "engine_version")
  instance_class         = lookup(var.rds_config[count.index], "instance_class")
  name                   = lookup(var.rds_config[count.index], "name")
  username               = var.db-UN
  password               = var.db-PW
  parameter_group_name   = lookup(var.rds_config[count.index], "parameter_group_name")
  multi_az               = lookup(var.rds_config[count.index], "multi_az")
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  port                   = lookup(var.rds_config[count.index], "port")

  db_subnet_group_name   = aws_db_subnet_group.default.name
  auto_minor_version_upgrade = false


  s3_import {
    source_engine         = lookup(var.rds_config[count.index], "engine")
    source_engine_version = lookup(var.rds_config[count.index], "engine_version")
    bucket_name           = var.s3_bucket_backup_name
    bucket_prefix         = var.s3_bucket_db_prefix
    ingestion_role        = aws_iam_role.rds_access_role.arn
  }

  tags = {
    Name = lookup(var.rds_config[count.index], "name")
  }

}

#---------------------------------------------------
# Cloudfront Distribution
#---------------------------------------------------

# OAI for S3 bucket for cloudfront access only
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "Origin Access Identity for S3"
}

data "aws_iam_policy_document" "media_public_access" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.media_assets.arn}/*"]

    principals {
      type = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }

  statement {
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.media_assets.arn]

    principals {
      type = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "ma" {
  bucket = aws_s3_bucket.media_assets.id
  policy = data.aws_iam_policy_document.media_public_access.json
}

resource "aws_cloudfront_distribution" "s3_distribution" {

  depends_on = [aws_elb.elb, aws_db_instance.db_wp, aws_acm_certificate_validation.cert2]

  origin {
    domain_name = aws_s3_bucket.media_assets.bucket_regional_domain_name
    origin_id   = var.s3_origin_id

    # Respond to requests only from cloudfront
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  # Include All edge locations
  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = [var.www_domain_name]

  tags = {
    Environment = "cloudfront"
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert2.certificate_arn
    minimum_protocol_version = "TLSv1"
    ssl_support_method       = "sni-only"
  }
}

#---------------------------------------------------
# Setup Route53
#---------------------------------------------------
data "aws_route53_zone" "mm" {
  name = var.www_domain_name
}

resource "aws_route53_record" "mm_alias_route53_record" {
  zone_id = data.aws_route53_zone.mm.zone_id
  name    = var.www_domain_name
  type    = "A"

  alias {
    name                   = aws_elb.elb.0.dns_name
    zone_id                = aws_elb.elb.0.zone_id
    evaluate_target_health = true
  }
}

#---------------------------------------------------
# Instance Data Source - used to output Bastion IP in io.tf
#---------------------------------------------------

data "aws_instance" "bastion" {
  filter {
    name   = "tag:Name"
    values = ["bastion"]
  }

  depends_on = [aws_instance.tf_example]
}


#---------------------------------------------------
# Elastic IP's required for NAT Gateways
#---------------------------------------------------
resource "aws_eip" "nat1" {
  vpc = true
}

resource "aws_eip" "nat2" {
  vpc = true
}
