# ========PROVIDERS========

provider "aws" {
	region = "eu-west-1"
}

provider "github" {
  token = var.GITHUB_TOKEN
}

# ========GITHUB REPOSITORY========

resource "github_repository" "automated_repo" {
  name        = var.repo_name
  description = "Automatically generated repo with Terraform"
  visibility  = "public"
}

# ========S3 REMOTE BACKEND========

terraform {
  backend "s3" {
    bucket = "tech258-shafique-terraform-bucket"
    key = "dev/terraform.tfstate"
    region = "eu-west-1"
    
  }
}

# ========AWS ORCHESTRATION========

## ========VPC========
resource "aws_vpc" "app-vpc" {
    cidr_block = var.vpc_cidr_block

    tags = {
    Name = var.vpc_name
  }
}

## ========INTERNET GATEWAY========
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.app-vpc.id
}

## ========ROUTE TABLE========
resource "aws_route_table" "app-route-table" {
    vpc_id = aws_vpc.app-vpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = var.route_table_name
    }
}



## ========APP SUBNET========
resource "aws_subnet" "app-subnet" {
    vpc_id = aws_vpc.app-vpc.id
    cidr_block = var.app_subnet_cidr_block
    availability_zone = var.availability_zone
    tags = {
        Name = var.app_subnet_name
    }
}

## ========DB SUBNET========
resource "aws_subnet" "db-subnet" {
    vpc_id = aws_vpc.app-vpc.id
    cidr_block = var.db_subnet_cidr_block
    availability_zone = "eu-west-1a"

    tags = {
        Name = var.db_subnet_name
    }
}


## ========ASSOCIATE SUBNET WITH ROUTE TABLE========
resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.app-subnet.id
    route_table_id = aws_route_table.app-route-table.id
}

## ========APP SECURITY GROUP========
resource "aws_security_group" "tech258-shafique-allow-web" {
    name = "allow_web_traffic"
    description = "Allow TLS inbound traffic"
    vpc_id = aws_vpc.app-vpc.id
    
    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]        
    }
    ingress {
        description = "Node"
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "tech258-shafique-allow-web"
    }
}

## ========DB SECURITY GROUP========
resource "aws_security_group" "tech258-shafique-allow-db" {
    name = "allow_db_traffic"
    description = "Allow TLS inbound traffic"
    vpc_id = aws_vpc.app-vpc.id
    
    ingress {
        description = "mongo"
        from_port = 27017
        to_port = 27017
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]        
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "tech258-shafique-allow-db"
    }
}




## ========CREATE DB========
resource "aws_instance" "db" {
    depends_on = [ aws_security_group.tech258-shafique-allow-db ]
    ami = var.db_ami_id
    instance_type = var.ec2_instance_type
    availability_zone = var.availability_zone
    
    key_name = var.key_name
    vpc_security_group_ids = [aws_security_group.tech258-shafique-allow-db.id]

    subnet_id = aws_subnet.db-subnet.id

    associate_public_ip_address = true

    user_data = "${file("user-data-mongo.sh")}"

    tags = {
        Name = "tech258-shafique-db"
    }

}



## ========CREATE APP========
resource "aws_instance" "app" {
    depends_on = [ aws_instance.db ]
    ami = var.ami_id
    instance_type = var.ec2_instance_type
    availability_zone = var.availability_zone
    
    key_name = var.key_name
    vpc_security_group_ids = [aws_security_group.tech258-shafique-allow-web.id]
    
    subnet_id = aws_subnet.app-subnet.id

    associate_public_ip_address = true

    user_data = templatefile("${path.module}/user-data-node.tftpl", {
    db_host = aws_instance.db.private_ip
  })

    tags = {
        Name = "tech258-shafique-app"
    }
}