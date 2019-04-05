provider "aws" {
  region = "eu-west-1"
  secret_key = ""
  access_key = ""
}

locals {
  az_count = "${length(var.azs)}"
  newbits  = "${max(4, local.az_count)}"
}

resource "aws_vpc" "3_tier" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "dedicated"

  tags = {
    Name = "vpc-${var.tag}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.3_tier.id}"

  tags = {
    Name = "gw-${var.tag}"
  }
}

#================================
# Subnets
#================================

resource "aws_subnet" "app" {
  count = "${length(var.azs)}"
  availability_zone_id = "${element(var.azs, count.index)}"
  vpc_id     = "${aws_vpc.3_tier.id}"
  cidr_block = "${cidrsubnet(var.subnet, local.newbits, 1*count.index )}"

  tags = {
    Name = "sn-app-${element(var.azs, count.index)}"
  }
}
resource "aws_subnet" "db" {
  count = "${length(var.azs)}"
  availability_zone_id = "${element(var.azs, count.index)}"
  vpc_id     = "${aws_vpc.3_tier.id}"
  cidr_block = "${cidrsubnet(var.subnet, local.newbits, 2*count.index )}"

  tags = {
    Name = "sn-db-${element(var.azs, count.index)}"
  }
}
resource "aws_subnet" "tools" {
  count = "${length(var.azs)}"
  availability_zone_id = "${element(var.azs, count.index)}"
  vpc_id     = "${aws_vpc.3_tier.id}"
  cidr_block = "${cidrsubnet(var.subnet, local.newbits, 3*count.index )}"

  tags = {
    Name = "sn-tools-${element(var.azs, count.index)}"
  }
}
resource "aws_subnet" "web" {
  count = "${length(var.azs)}"
  availability_zone_id = "${element(var.azs, count.index)}"
  vpc_id     = "${aws_vpc.3_tier.id}"
  cidr_block = "${cidrsubnet(var.subnet, local.newbits, 4*count.index )}"

  tags = {
    Name = "sn-web-${element(var.azs, count.index)}"
  }
}

#================================
# Route tables and associations
#================================

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.3_tier.id}"

  route {
    cidr_block = "0.0.0.0/24"
    gateway_id = "${aws_internet_gateway.main.id}"
  }

  tags = {
    Name = "public_rt-${var.tag}"
  }
}

resource "aws_route_table_association" "web" {
  subnet_id = "${element(aws_subnet.web.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "tools" {
  subnet_id = "${element(aws_subnet.tools.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}



#=================
# ACL's
#=================

resource "aws_network_acl" "web" {
  vpc_id = "${aws_vpc.3_tier.id}"
  #subnet_ids = [ "${aws_subnet.web.id}" ]
  subnet_ids = ["${aws_subnet.web.*.id}"]
  tags = {
    Name = "web_acl"
  }
}

resource "aws_network_acl_rule" "web_allow_allOutbound" {
  network_acl_id = "${aws_network_acl.web.id}"
  rule_number    = 106
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "web_allow_allInbound80" {
  network_acl_id = "${aws_network_acl.web.id}"
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  to_port        = 80
}

resource "aws_network_acl_rule" "web_allow_allInbound443" {
  network_acl_id = "${aws_network_acl.web.id}"
  rule_number    = 101
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  to_port        = 443
}

# Common ACL Across for web/app/db/tools zone #


resource "aws_network_acl_rule" "app_deny_allInbound22" {
  network_acl_id = "${aws_network_acl.app.id}"
  rule_number    = 700
  egress         = false
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  to_port        = 22
}

resource "aws_network_acl_rule" "app_allow_allInbound22_local" {
  network_acl_id = "${aws_network_acl.app.id}"
  rule_number    = 720
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
  to_port        = 22
}

resource "aws_network_acl_rule" "app_allow_allInbound22_PublicIP" {
  network_acl_id = "${aws_network_acl.app.id}"
  rule_number    = 740
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.PublicIP}/32"
}
resource "aws_network_acl_rule" "db_deny_allInbound22" {
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 701
  egress         = false
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  to_port        = 22
}

resource "aws_network_acl_rule" "db_allow_allInbound22_local" {
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 721
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
  to_port        = 22
}

resource "aws_network_acl_rule" "db_allow_allInbound22_PublicIP" {
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 741
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.PublicIP}/32"
}
resource "aws_network_acl_rule" "tools_deny_allInbound22" {
  network_acl_id = "${aws_network_acl.tools.id}"
  rule_number    = 702
  egress         = false
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  to_port        = 22
}

resource "aws_network_acl_rule" "tools_allow_allInbound22_local" {
  network_acl_id = "${aws_network_acl.tools.id}"
  rule_number    = 722
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
  to_port        = 22
}

resource "aws_network_acl_rule" "tools_allow_allInbound22_PublicIP" {
  network_acl_id = "${aws_network_acl.tools.id}"
  rule_number    = 742
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.PublicIP}/32"
}
resource "aws_network_acl_rule" "web_deny_allInbound22" {
  network_acl_id = "${aws_network_acl.web.id}"
  rule_number    = 703
  egress         = false
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  to_port        = 22
}

resource "aws_network_acl_rule" "web_allow_allInbound22_local" {
  network_acl_id = "${aws_network_acl.web.id}"
  rule_number    = 723
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
  to_port        = 22
}

resource "aws_network_acl_rule" "web_allow_allInbound22_PublicIP" {
  network_acl_id = "${aws_network_acl.web.id}"
  rule_number    = 743
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.PublicIP}/32"
}

# Common groups ends

resource "aws_network_acl" "app" {
  vpc_id = "${aws_vpc.3_tier.id}"
  subnet_ids = ["${aws_subnet.app.*.id}"]
  tags = {
    Name = "app_acl"
  }
}

resource "aws_network_acl_rule" "app_allow_allInbound8080_web" {
  count = "${local.az_count}"
  network_acl_id = "${aws_network_acl.app.id}"
  rule_number    = "${302 + count.index}"
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  from_port      = 8080
  to_port        = 8080
  cidr_block     = "${element(aws_subnet.web.*.cidr_block, count.index)}"
}

resource "aws_network_acl" "db" {
  vpc_id = "${aws_vpc.3_tier.id}"
  subnet_ids = ["${aws_subnet.db.*.id}"]
  tags = {
    Name = "db_acl"
  }
}

resource "aws_network_acl_rule" "db_allow_allInbound3306_fromApp" {
  count = "${local.az_count}"
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 950
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  from_port      = 3306
  to_port        = 3306
  cidr_block     = "${element(aws_subnet.app.*.cidr_block, count.index)}"
}

resource "aws_network_acl_rule" "db_allow_allInbound3306_fromtools" {
  count = "${local.az_count}"
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 970
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  from_port      = 3306
  to_port        = 3306
  cidr_block     = "${element(aws_subnet.tools.*.cidr_block, count.index)}"
}
resource "aws_network_acl_rule" "db_allow_allInbound1433_fromApp" {
  count = "${local.az_count}"
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 951
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  from_port      = 1433
  to_port        = 1433
  cidr_block     = "${element(aws_subnet.app.*.cidr_block, count.index)}"
}

resource "aws_network_acl_rule" "db_allow_allInbound1433_fromtools" {
  count = "${local.az_count}"
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 971
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  from_port      = 1433
  to_port        = 1433
  cidr_block     = "${element(aws_subnet.tools.*.cidr_block, count.index)}"
}
resource "aws_network_acl_rule" "db_allow_allInbound5432_fromApp" {
  count = "${local.az_count}"
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 952
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  from_port      = 5432
  to_port        = 5432
  cidr_block     = "${element(aws_subnet.app.*.cidr_block, count.index)}"
}

resource "aws_network_acl_rule" "db_allow_allInbound5432_fromtools" {
  count = "${local.az_count}"
  network_acl_id = "${aws_network_acl.db.id}"
  rule_number    = 972
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  from_port      = 5432
  to_port        = 5432
  cidr_block     = "${element(aws_subnet.tools.*.cidr_block, count.index)}"
}

resource "aws_network_acl" "tools" {
  vpc_id = "${aws_vpc.3_tier.id}"
  subnet_ids = ["${aws_subnet.tools.*.id}"]
  tags = {
    Name = "tools_acl"
  }
}

resource "aws_network_acl_rule" "tools_allow_allInbound_local_all" {
  network_acl_id = "${aws_network_acl.tools.id}"
  rule_number    = 500
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${aws_vpc.3_tier.cidr_block}"
  to_port        = 0
}
#=================
# Security Groups
#=================

resource "aws_security_group" "web_80" {
  name        = "allow web network"
  description = "Allow web inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web80_sg"
  }
}
resource "aws_security_group" "web_433" {
  name        = "allow web network"
  description = "Allow web inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"

  ingress {
    from_port   = 433
    to_port     = 433
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web433_sg"
  }
}

resource "aws_security_group" "app_80" {
  name        = "allow traffic from web subnet network"
  description = "Allow web inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "-1"
    cidr_blocks = ["${aws_subnet.web.*.cidr_block}"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.PublicIP}/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app80_sg"
  }
}
resource "aws_security_group" "app_433" {
  name        = "allow traffic from web subnet network"
  description = "Allow web inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"
  
  ingress {
    from_port   = 433
    to_port     = 433
    protocol    = "-1"
    cidr_blocks = ["${aws_subnet.web.*.cidr_block}"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.PublicIP}/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app433_sg"
  }
}

resource "aws_security_group" "db_3306" {
  name        = "db ingress for 3306"
  description = "Allow web inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = ["${aws_subnet.app.*.cidr_block}","${aws_subnet.tools.*.cidr_block}","${var.PublicIP}/32"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db3306_sg"
  }
}
resource "aws_security_group" "db_1433" {
  name        = "db ingress for 1433"
  description = "Allow web inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"
  
  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "TCP"
    cidr_blocks = ["${aws_subnet.app.*.cidr_block}","${aws_subnet.tools.*.cidr_block}","${var.PublicIP}/32"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db1433_sg"
  }
}
resource "aws_security_group" "db_5432" {
  name        = "db ingress for 5432"
  description = "Allow web inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "TCP"
    cidr_blocks = ["${aws_subnet.app.*.cidr_block}","${aws_subnet.tools.*.cidr_block}","${var.PublicIP}/32"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db5432_sg"
  }
}

resource "aws_security_group" "tools" {
  name        = "allow tools network"
  description = "Allow tools inbound traffic"
  vpc_id      = "${aws_vpc.3_tier.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/16","${var.PublicIP}/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tools_sg"
  }
}