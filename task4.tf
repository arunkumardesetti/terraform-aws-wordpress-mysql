provider "aws" {
  region = "ap-south-1"
  profile = "default"
}

#VPC
resource "aws_vpc" "myvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "myvpc"
  }
}

#Enabling Elastic IP
resource "aws_eip" "eip"{
  vpc = true
  tags = {
    Name = "eip"
  }
}


#Public_Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  depends_on = [
    aws_vpc.myvpc,
  ]

  tags = {
    Name = "public_subnet"
  }
}

#Private_Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  depends_on = [
    aws_vpc.myvpc
  ]

  tags = {
    Name = "private_subnet"
  }
}

#Internet_Gateway
resource "aws_internet_gateway" "mygw" {
  vpc_id = aws_vpc.myvpc.id
  depends_on = [
    aws_vpc.myvpc
  ]

  tags = {
    Name = "mygw"
  }
}

#Public_Route_Table
resource "aws_route_table" "my_rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mygw.id
  }

  depends_on = [
    aws_vpc.myvpc
  ]

  tags = {
    Name = "my_rt"
  }
}

#Public_Subnet_Association
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.my_rt.id
}

#NAT_Gateway
resource "aws_nat_gateway" "mynat" {
  allocation_id = "${aws_eip.eip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"
  tags = {
    Name = "mynat"
  }
}

#NAT_Route_Table
resource "aws_route_table" "my_rt_nat" {
  vpc_id = "${aws_vpc.myvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.mynat.id}"
  }

  tags = {
    Name = "my_rt_nat"
  }
}

#Private_Subnet_Association
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.my_rt_nat.id
}

#Wordpress_SG
resource "aws_security_group" "wordpress_sg" {
  name        = "wordpress_sg"
  description = "allows ssh and http"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    from_port = -1
    to_port	= -1
    protocol	= "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_vpc.myvpc
  ]

  tags = {
    Name = "wordpress_sg"
  }
}

#SQL_SG
resource "aws_security_group" "sql_sg" {
  name        = "sql_sg"
  description = "allows wordpress SG"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.public_subnet.cidr_block}"]
  }

    ingress {
    description = "MYSQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.public_subnet.cidr_block}"]
  }


  ingress {
    description = "ICMP - IPv4"
    from_port = -1
    to_port	= -1
    protocol	= "icmp"
    cidr_blocks = ["${aws_subnet.public_subnet.cidr_block}"]
  }
  
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }  

  depends_on = [
    aws_vpc.myvpc,
    aws_security_group.wordpress_sg,
  ]

  tags = {
    Name = "sql_sg"
  }
}

#Wordpress_Instance
resource "aws_instance" "WordPress" {
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  key_name      = "arunawskey"
  subnet_id     = "${aws_subnet.public_subnet.id}" 
  vpc_security_group_ids = ["${aws_security_group.wordpress_sg.id}"]

  tags = {
    Name = "WordPress"
  }
}

#SQL_Instance
resource "aws_instance" "MySql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = "arunawskey"
  subnet_id     = "${aws_subnet.private_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sql_sg.id}"]

  tags = {
    Name = "MySql"
  }
}