module "vpc-ha2z" {
  source = "../modules/vpc"

  name = "${var.name}-ha2z"

  cidr_block              = var.ha2z_cidr
  public_mgmt_prefix_list = var.pl-mgmt-mgmt_ips
}


resource "aws_subnet" "ha2z_a" {
  for_each          = var.subnets
  vpc_id            = module.vpc-ha2z.vpc.id
  cidr_block        = cidrsubnet(module.vpc-ha2z.vpc.cidr_block, 4, 0 + each.value.index * 2)
  availability_zone = var.availability_zones[0]
  tags = {
    Name = "${var.name}-ha2z_a-${each.key}"
  }
}
resource "aws_subnet" "ha2z_b" {
  for_each          = var.subnets
  vpc_id            = module.vpc-ha2z.vpc.id
  cidr_block        = cidrsubnet(module.vpc-ha2z.vpc.cidr_block, 4, 1 + each.value.index * 2)
  availability_zone = var.availability_zones[1]
  tags = {
    Name = "${var.name}-ha2z_b-${each.key}"
  }
}


resource "aws_instance" "ha2z_host" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  subnet_id     = aws_subnet.ha2z_a["client"].id
  vpc_security_group_ids = [
    module.vpc-ha2z.sg_public_id,
    module.vpc-ha2z.sg_private_id,
  ]
  key_name   = var.key_pair
  private_ip = cidrhost(aws_subnet.ha2z_a["client"].cidr_block, 10)
  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
  tags = {
    Name = "${var.name}-ha2z_host"
  }
}
resource "aws_eip" "ha2z_host" {
  instance = aws_instance.ha2z_host.id
  tags = {
    Name = "${var.name}-ha2z_host"
  }
}
output "ha2z_host" {
  value = aws_eip.ha2z_host.public_ip
}



module "fw-ha2z_a" {
  source = "../modules/vmseries"

  name             = "${var.name}-ha2z_a"
  fw_instance_type = "m5.xlarge"

  iam_instance_profile = data.terraform_remote_state.mgmt.outputs.instance_profile-pan_ha-name
  key_pair             = var.key_pair

  bootstrap_options = merge(
    var.bootstrap_options["common"],
    var.bootstrap_options["ha2z_a"],
  )

  interfaces = {
    mgmt = {
      device_index = 0
      public_ip    = true
      subnet_id    = aws_subnet.ha2z_a["mgmt"].id
      security_group_ids = [
        module.vpc-ha2z.sg_public_id,
        module.vpc-ha2z.sg_private_id,
      ]
      private_ips = [cidrhost(aws_subnet.ha2z_a["mgmt"].cidr_block, 5)]
    }
    ha2 = {
      device_index = 1
      subnet_id    = aws_subnet.ha2z_a["ha2"].id
      private_ips  = [cidrhost(aws_subnet.ha2z_a["ha2"].cidr_block, 5)]
      security_group_ids = [
        module.vpc-ha2z.sg_private_id,
      ]
    }
    internet = {
      device_index = 2
      public_ip    = true
      subnet_id    = aws_subnet.ha2z_a["internet"].id
      private_ips  = [cidrhost(aws_subnet.ha2z_a["internet"].cidr_block, 5)]
      security_group_ids = [
        module.vpc-ha2z.sg_open_id,
      ]
    }
    prv = {
      device_index = 3
      subnet_id    = aws_subnet.ha2z_a["prv"].id
      private_ips  = [cidrhost(aws_subnet.ha2z_a["prv"].cidr_block, 5)]
      security_group_ids = [
        module.vpc-ha2z.sg_open_id,
      ]
    }
  }
}

module "fw-ha2z_b" {
  source = "../modules/vmseries"

  name             = "${var.name}-ha2z_b"
  fw_instance_type = "m5.xlarge"

  iam_instance_profile = data.terraform_remote_state.mgmt.outputs.instance_profile-pan_ha-name
  key_pair             = var.key_pair

  bootstrap_options = merge(
    var.bootstrap_options["common"],
    var.bootstrap_options["ha2z_b"],
  )

  interfaces = {
    mgmt = {
      device_index = 0
      public_ip    = true
      subnet_id    = aws_subnet.ha2z_b["mgmt"].id
      security_group_ids = [
        module.vpc-ha2z.sg_public_id,
        module.vpc-ha2z.sg_private_id,
      ]
      private_ips = [cidrhost(aws_subnet.ha2z_b["mgmt"].cidr_block, 6)]
    }
    ha2 = {
      device_index = 1
      subnet_id    = aws_subnet.ha2z_b["ha2"].id
      private_ips  = [cidrhost(aws_subnet.ha2z_b["ha2"].cidr_block, 6)]
      security_group_ids = [
        module.vpc-ha2z.sg_private_id,
      ]
    }
    internet = {
      device_index = 2
      public_ip    = false
      subnet_id    = aws_subnet.ha2z_b["internet"].id
      private_ips  = [cidrhost(aws_subnet.ha2z_b["internet"].cidr_block, 6)]
      security_group_ids = [
        module.vpc-ha2z.sg_open_id,
      ]
    }
    prv = {
      device_index = 3
      subnet_id    = aws_subnet.ha2z_b["prv"].id
      private_ips  = [cidrhost(aws_subnet.ha2z_b["prv"].cidr_block, 6)]
      security_group_ids = [
        module.vpc-ha2z.sg_open_id,
      ]
    }
  }
}

output "ha2z_a" {
  value = module.fw-ha2z_a.public_ips
}

output "ha2z_b" {
  value = module.fw-ha2z_b.public_ips
}


resource "aws_route_table" "ha2z-client" {
  vpc_id = module.vpc-ha2z.vpc.id
  tags = {
    Name = "${var.name}-ha2z-client"
  }
}
resource "aws_route_table_association" "ha2z-client" {
  subnet_id      = aws_subnet.ha2z_a["client"].id
  route_table_id = aws_route_table.ha2z-client.id
}
resource "aws_route" "ha2z-dg" {
  route_table_id         = aws_route_table.ha2z-client.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id    = module.vpc-ha2z.internet_gateway_id
}
resource "aws_route" "ha2z-ipsec" {
  route_table_id         = aws_route_table.ha2z-client.id
  destination_cidr_block = aws_subnet.ha1z_a["client"].cidr_block
  network_interface_id   = module.fw-ha2z_a.eni["prv"]
}


resource "aws_route_table_association" "ha2z_a-mgmt" {
  subnet_id      = aws_subnet.ha2z_a["mgmt"].id
  route_table_id = module.vpc-ha2z.route_tables["via_igw"]
}
resource "aws_route_table_association" "ha2z_b-mgmt" {
  subnet_id      = aws_subnet.ha2z_b["mgmt"].id
  route_table_id = module.vpc-ha2z.route_tables["via_igw"]
}
resource "aws_route_table_association" "ha2z_a-internet" {
  subnet_id      = aws_subnet.ha2z_a["internet"].id
  route_table_id = module.vpc-ha2z.route_tables["via_igw"]
}
resource "aws_route_table_association" "ha2z_b-internet" {
  subnet_id      = aws_subnet.ha2z_b["internet"].id
  route_table_id = module.vpc-ha2z.route_tables["via_igw"]
}

