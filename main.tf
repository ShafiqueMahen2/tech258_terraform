# Create a service on the cloud - launch an EC2 instance on AWS
# HCL syntax: key = value
# MUST NOT HARDCODE ACCESS/SECRET KEYS
# MUST NOT PUSH ANYTHING TO GITHUB UNTIL WE HAVE CREATED A .gitignore FILE TOGETHER

provider "aws" {
  region = var.aws_region
}

provider "github" {
  token = var.GITHUB_TOKEN
}

resource "github_repository" "automated_repo" {
  name = var.repo_name
  description = "Automatically generated repo with Terraform"
  visibility = "public"
}

# Create VPC
resource "aws_vpc" "shafique_tech258_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = var.vpc_name
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "shafique_tech258_igw" {
  vpc_id = aws_vpc.shafique_tech258_vpc.id

  tags = {
    Name = var.vpc_igw_name
  }
}

# Create Public Subnet (10.0.12.0/24)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.shafique_tech258_vpc.id
  cidr_block              = var.vpc_public_subnet_cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = var.vpc_public_subnet_name
  }
}

# Create Private Subnet (10.0.22.0/24)
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.shafique_tech258_vpc.id
  cidr_block = var.vpc_private_subnet_cidr_block

  tags = {
    Name = var.vpc_private_subnet_name
  }
}

# Create Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.shafique_tech258_vpc.id

  route {
    cidr_block = var.vpc_public_route_table_cidr_block
    gateway_id = aws_internet_gateway.shafique_tech258_igw.id
  }

  tags = {
    Name = var.vpc_public_route_table_name
  }
}

# Associate Public Route Table with Public Subnet
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for EC2 instance
resource "aws_security_group" "shafique_tech258_sg" {
  name = var.sg_name
  vpc_id = aws_vpc.shafique_tech258_vpc.id

  dynamic "ingress" {
    for_each = var.sg_ingress_rules

    content {
      from_port = ingress.value["from_port"]
      to_port = ingress.value["to_port"]
      protocol = ingress.value["protocol"]
      cidr_blocks = ingress.value["cidr_blocks"]
    }
    
  }

  egress {
    from_port   = var.sg_egress_rule.from_port
    to_port     = var.sg_egress_rule.to_port
    protocol    = var.sg_egress_rule.protocol
    cidr_blocks = var.sg_egress_rule.cidr_blocks
  }

  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 3000
  #   to_port     = 3000
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags = {
    Name = var.sg_name
  }
}

# Create App EC2 Instance
resource "aws_instance" "app_instance" {
  ami                    = var.app_ami_id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  key_name               = var.app_key_name
  vpc_security_group_ids = [aws_security_group.shafique_tech258_sg.id]

  tags = {
    Name = var.app_instance_name
  }

  depends_on = [
    aws_security_group.shafique_tech258_sg
  ]
}


