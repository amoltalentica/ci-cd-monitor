# Lookup latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "demo-vpc" }
}

# Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "public-subnet" }
}

data "aws_availability_zones" "available" {}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "demo-igw" }
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group
resource "aws_security_group" "ec2_sg" {
  name        = "allow_http_ssh"
  description = "Allow HTTP & SSH"
  vpc_id      = aws_vpc.main.id

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
    cidr_blocks = ["0.0.0.0/0"] # restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-sg" }
}

# Optional key pair (if you supply ssh_public_key)
resource "aws_key_pair" "deployer" {
  count      = length(trimspace(var.ssh_public_key)) > 0 ? 1 : 0
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

# Create an ECR repository
resource "aws_ecr_repository" "ci_cd_monitor" {
  name = "ci-cd-monitor"
}

# Output the ECR URI
output "ecr_repo_url" {
  value = aws_ecr_repository.ci_cd_monitor.repository_url
}

# EC2 instance with user_data installing Docker and running the container
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  key_name = length(aws_key_pair.deployer.*.key_name) > 0 ? aws_key_pair.deployer[0].key_name : null

    user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl enable docker
              systemctl start docker
              usermod -a -G docker ec2-user

              # Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install

              # Authenticate Docker to ECR
              REGION=${var.aws_region}
              REPO_URI=${aws_ecr_repository.ci_cd_monitor.repository_url}
              $(aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO_URI)

              # Pull & run latest image
              docker pull $REPO_URI:latest
              docker run -d -p 80:80 --restart unless-stopped $REPO_URI:latest
              EOF

  tags = {
    Name = "app-instance"
  }
}

# Output public IP / DNS
output "instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "instance_public_dns" {
  value = aws_instance.app.public_dns
}
