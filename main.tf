provider "aws" {
  region = "us-west-2"
}

variable "server_port" {
  description = "HTTP server port"
}

# Create VPC
resource "aws_vpc" "TerraVPC" {
  cidr_block = "172.16.0.0/16"
  enable_dns_hostnames = "true"

  tags {
    Name = "tfTest"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "TerraInternetGateway" {
  vpc_id = "${aws_vpc.TerraVPC.id}"


  tags = {
    Name = "tfTest"
  }
}

# Get the route table that was created on VPC creation
data "aws_route_table" "var_route_table" {
  vpc_id = "${aws_vpc.TerraVPC.id}"
}


# # Uncomment to see the output with the route table id
# output "route_table_id" {
#   value = "${data.aws_route_table.var_route_table.id}"
# }

resource "aws_subnet" "TerraSubnet" {
  vpc_id                  = "${aws_vpc.TerraVPC.id}"
  cidr_block              = "172.16.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = "true"                   #For testing purpose

  tags {
    Name = "tfTest"
  }
}

resource "aws_route" "TerraInternetRoute" {
  route_table_id         = "${aws_vpc.TerraVPC.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.TerraInternetGateway.id}"
}

resource "aws_route_table_association" "TerraRouteTableAssoc" {
  subnet_id      = "${aws_subnet.TerraSubnet.id}"
  route_table_id = "${aws_vpc.TerraVPC.main_route_table_id}"
}

resource "aws_security_group" "TerraSG" {
  name   = "terraform-security-group"
  vpc_id = "${aws_vpc.TerraVPC.id}"

  # HTTP
  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "tfTest"
  }
}

resource "aws_network_interface" "TerraNI" {
  subnet_id   = "${aws_subnet.TerraSubnet.id}"
  private_ips = ["172.16.1.100", "172.16.1.101"]

  security_groups = [
    "${aws_security_group.TerraSG.id}",
  ]

  tags {
    Name = "tfTest"
  }
}

resource "aws_instance" "TerraInstance" {
  ami           = "ami-0bbe6b35405ecebdb"
  instance_type = "t2.micro"
  key_name      = "bhavesh_ec2"

  network_interface {
    network_interface_id = "${aws_network_interface.TerraNI.id}"
    device_index         = 0
  }

  tags {
    Name = "tfTest"
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "Success!" > index.html
    nohup busybox httpd -f -p "${var.server_port}" &
    EOF
}
