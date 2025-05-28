resource "aws_vpc" "terraform_vpc" {
  cidr_block         = "10.100.100.0/24"
  enable_dns_support = true
  
  tags = {
    Name = "terraform_vpc"
  }
}

resource "aws_subnet" "terraform_subnet" {
  availability_zone = var.az
  cidr_block        = aws_vpc.terraform_vpc.cidr_block
  vpc_id            = aws_vpc.terraform_vpc.id
  map_public_ip_on_launch = true
  depends_on        = [aws_vpc.terraform_vpc]

  tags = {
    Name = "Subnet in ${var.az} for ${lookup(aws_vpc.terraform_vpc.tags, "Name")}"
  }
}

resource "aws_internet_gateway" "terraform_gw" {
  vpc_id = aws_vpc.terraform_vpc.id
  depends_on = [aws_vpc.terraform_vpc]

  tags = {
    Name = "terraform_gw"
  }
}

resource "aws_route_table" "terraform_routes"{
  vpc_id = aws_vpc.terraform_vpc.id
  depends_on = [aws_vpc.terraform_vpc]
  
  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   gateway_id = aws_internet_gateway.terraform_gw.id
  # }
  tags = {
    Name = "terraform_routes"
  }
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.terraform_routes.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.terraform_gw.id
  depends_on = [aws_route_table.terraform_routes, aws_internet_gateway.terraform_gw]
}

resource "aws_route_table_association" "subnet_assoc" {
  subnet_id      = aws_subnet.terraform_subnet.id
  route_table_id = aws_route_table.terraform_routes.id
  depends_on = [aws_subnet.terraform_subnet, aws_route_table.terraform_routes]
}

resource "aws_security_group" "terraform_sg" {
  name = "First sg"
  description = "Allow me"
  vpc_id      = aws_vpc.terraform_vpc.id

  ingress {
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    cidr_blocks              = ["109.120.150.3/32", "46.138.35.15/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_network_interface" "enis" {
  for_each = var.host_config
  subnet_id       = aws_subnet.terraform_subnet.id
  security_groups = [aws_security_group.terraform_sg.id]
  private_ips       = [each.value.ip]
  description       = each.key
  ipv6_address_count = 0
  tags = {
    Name        = each.key
  }

  depends_on = [ aws_subnet.terraform_subnet, aws_security_group.terraform_sg ]
}

resource "aws_eip" "terraform_eips" {
  for_each = var.host_config
  vpc = true
  tags = {
    Name = each.key
  }
}

resource "aws_eip_association" "attach_eips" {
  for_each = var.host_config
  allocation_id        = aws_eip.terraform_eips[each.key].id
  network_interface_id = aws_network_interface.enis[each.key].id
  depends_on = [ aws_network_interface.enis, aws_eip.terraform_eips ]
}

resource "aws_ebs_volume" "data_disks" {
  for_each = var.host_config

  availability_zone = var.az
  size              = each.value.data_size
  type              = "st2"

  tags = {
    Name = each.value.data_disk
  }
}

resource "aws_volume_attachment" "attach_data" {
  for_each = var.host_config

  volume_id   = aws_ebs_volume.data_disks[each.key].id
  instance_id = aws_instance.vms[each.key].id

  force_detach = true
  depends_on = [aws_instance.vms]
}

resource "aws_instance" "vms" {
  for_each = var.host_config

  ami                    = var.ami_id
  instance_type          = var.instance_type
  availability_zone      = var.az
  key_name               = var.public_key
  network_interface {
    network_interface_id = aws_network_interface.enis[each.key].id
    device_index         = 0
  }

  root_block_device {
    volume_type = "st2"
    volume_size = 32
    delete_on_termination = true
  }

  tags = {
    Name = each.key
  }
}
