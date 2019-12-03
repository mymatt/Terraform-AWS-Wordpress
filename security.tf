#---------------------------------------------------
# Security Groups
#---------------------------------------------------

resource "aws_security_group" "bastion_sg_pub" {
  name = "bastion_sec_pub"

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "8"
    to_port     = "0"
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  egress {
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "icmp"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb_web_sg" {
  name = "elb_web_sec"

  depends_on = ["aws_security_group.bastion_sg_pub"]

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port       = "22"
    to_port         = "22"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.bastion_sg_pub.id}"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "8"
    to_port     = "0"
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg" {
  name = "web_sec"

  depends_on = ["aws_security_group.bastion_sg_pub", "aws_security_group.elb_web_sg"]

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port       = "22"
    to_port         = "22"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.bastion_sg_pub.id}"]
  }

  ingress {
    from_port       = "80"
    to_port         = "80"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.elb_web_sg.id}"]
  }

  ingress {
    from_port       = "8"
    to_port         = "0"
    protocol        = "icmp"
    security_groups = ["${aws_security_group.bastion_sg_pub.id}"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vault_sg" {
  name = "vault_sec"

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = "${var.vault_port}"
    to_port     = "${var.vault_port}"
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  ingress {
    from_port       = "22"
    to_port         = "22"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.bastion_sg_pub.id}"]
  }

  ingress {
    from_port       = "8"
    to_port         = "0"
    protocol        = "icmp"
    security_groups = ["${aws_security_group.bastion_sg_pub.id}"]
  }

  # ALL EGRESS
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name = "rds_sec"

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = "${var.rds_port}"
    to_port     = "${var.rds_port}"
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }
}
