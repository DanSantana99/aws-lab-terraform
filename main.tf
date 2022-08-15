resource "aws_vpc" "awslab-vpc" {                                       # Create VPC
    cidr_block       = "172.16.0.0/16"                                  # Define CIDR Block for VPC

    tags = {
        Name = "awslab-vpc"                                             # Set vpc name
    }
 }

resource "aws_subnet" "awslab-subnet-public" {                          # Create Public Subnet
  vpc_id     = aws_vpc.awslab-vpc.id                                    # Attach subnet to vpc
  cidr_block = "172.16.1.0/24"                                          # Define CIDR Block for subnet
  map_public_ip_on_launch = true

  tags = {
    Name = "awslab-subnet-public"                                       # Set subnet name
  }
}

resource "aws_subnet" "awslab-subnet-private" {                         # Create Public Subnet
  vpc_id     = aws_vpc.awslab-vpc.id                                    # Attach subnet to vpc                        
  cidr_block = "172.16.2.0/24"                                          # Define CIDR Block for subnet

  tags = {
    Name = "awslab-subnet-private"                                      # Set subnet name
  }
}

resource "aws_internet_gateway" "awslab-internet-gateway" {             # Create Internet Gateway
  vpc_id = aws_vpc.awslab-vpc.id                                        # Attach gateway to vpc

  tags = {
    Name = "awslab-internet-gateway"                                    # Set gateway name
  }
}

resource "aws_route_table" "awslab-rt-internet" {                       # Create Route Table
  vpc_id = aws_vpc.awslab-vpc.id                                        # Attach route table to vpc

  route {
    cidr_block = "0.0.0.0/0"                                            # Define CIDR Block for subnet (internet access)
    gateway_id = aws_internet_gateway.awslab-internet-gateway.id        # Attach gateway to route table
  }

  tags = {
    Name = "awslab-rt-internet"                                         # Set route table name
  }
}

resource "aws_route_table_association" "awslab-route-association" {     # Create Route Table Association
  subnet_id      = aws_subnet.awslab-subnet-public.id                   # Associate public subnet to -->      
  route_table_id = aws_route_table.awslab-rt-internet.id                #                         --> route table
}

resource "aws_security_group" "awslab-public-security-groups" {         # Create public Security Groups
  name        = "awslab-public-security-groups"
  description = "awslab-public-security-groups"
  vpc_id      = aws_vpc.awslab-vpc.id                                   # Associate VPC to security groups

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP"
    from_port   = 1
    to_port     = 8
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "awslab-public-security-groups"
  }
}

resource "aws_security_group" "awslab-private-security-groups" {         # Create private Security Groups
  name        = "awslab-private-security-groups"
  description = "awslab-priavte-security-groups"
  vpc_id      = aws_vpc.awslab-vpc.id                                   # Associate VPC to security groups

  ingress {
    description = "CUSTOM"
    from_port   = 3110
    to_port     = 3110
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24"]
  }

  ingress {
    description = "ICMP"
    from_port   = 1
    to_port     = 8
    protocol    = "icmp"
    cidr_blocks = ["172.16.1.0/24"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "awslab-private-security-groups"
  }
}

data "aws_ami" "amazon-linux-2" {   # Create AMI
 most_recent = true

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "webserver_private_key" {  # Create key for SSH
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "private_key" {
  content = tls_private_key.webserver_private_key.private_key_pem
  filename = "webserver_key.pem"
  file_permission = 400
}

resource "aws_key_pair" "webserver_key" {
  key_name = "webserver"
  public_key = tls_private_key.webserver_private_key.public_key_openssh
}

resource "aws_instance" "aws-lab-public-ec2" {  # Create public instance
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.webserver_key.key_name
  subnet_id = aws_subnet.awslab-subnet-public.id
  vpc_security_group_ids = [aws_security_group.awslab-public-security-groups.id]
  associate_public_ip_address = "true"
  user_data = "${file("install.sh")}"

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 8
  }

  tags = {
    Name = "aws-lab-public-ec2"
  }
}

resource "aws_instance" "aws-lab-private-ec2" { # Create private instance
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.webserver_key.key_name
  subnet_id = aws_subnet.awslab-subnet-private.id
  vpc_security_group_ids = [aws_security_group.awslab-private-security-groups.id]

  ebs_block_device {
    device_name = "/dev/sda2"
    volume_size = 8
  }

  tags = {
    Name = "aws-lab-private-ec2"
  }
}