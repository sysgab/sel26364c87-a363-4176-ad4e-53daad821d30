# Create KMS Key for the project
data "aws_caller_identity" "current" {}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Create frontend subnets in three different availability zones
resource "aws_subnet" "frontend_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "frontend-subnet-a"
  }
}

resource "aws_subnet" "frontend_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "frontend-subnet-b"
  }
}

resource "aws_subnet" "frontend_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}c"
  map_public_ip_on_launch = false

  tags = {
    Name = "frontend-subnet-c"
  }
}

# Create backend subnets in three different availability zones
resource "aws_subnet" "backend_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "backend-subnet-a"
  }
}

resource "aws_subnet" "backend_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "backend-subnet-b"
  }
}

resource "aws_subnet" "backend_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "${var.region}c"

  tags = {
    Name = "backend-subnet-c"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create a public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the route table with the frontend subnets
resource "aws_route_table_association" "frontend_a" {
  subnet_id      = aws_subnet.frontend_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "frontend_b" {
  subnet_id      = aws_subnet.frontend_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "frontend_c" {
  subnet_id      = aws_subnet.frontend_c.id
  route_table_id = aws_route_table.public.id
}

# private route tables
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-a.id
  }

  tags = {
    Name = "private-route-table-a"
  }
}
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-b.id
  }

  tags = {
    Name = "private-route-table-b"
  }
}
resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-c.id
  }

  tags = {
    Name = "private-route-table-c"
  }
}

# Associate the private route table with the backend subnets
resource "aws_route_table_association" "backend_a" {
  subnet_id      = aws_subnet.backend_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "backend_b" {
  subnet_id      = aws_subnet.backend_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_route_table_association" "backend_c" {
  subnet_id      = aws_subnet.backend_c.id
  route_table_id = aws_route_table.private_c.id
}

resource "aws_security_group" "secretsmanager_vpce" {
  name = "secretsmanager_vpce"
  description = "secretsmanager vpce security group"
  vpc_id      = aws_vpc.main.id
}

# elastic ips for nat gateways
resource "aws_eip" "natgw-a" {
  domain   = "vpc"
  public_ipv4_pool = "amazon"
}
resource "aws_eip" "natgw-b" {
  domain   = "vpc"
  public_ipv4_pool = "amazon"
}
resource "aws_eip" "natgw-c" {
  domain   = "vpc"
  public_ipv4_pool = "amazon"
}

# nat gateways
resource "aws_nat_gateway" "nat-gw-a" {
  allocation_id     = aws_eip.natgw-a.allocation_id
  connectivity_type = "public"
  subnet_id         = aws_subnet.frontend_a.id

  tags = {
    Name  = "nat-gw-a"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat-gw-b" {
  allocation_id     = aws_eip.natgw-b.allocation_id
  connectivity_type = "public"
  subnet_id         = aws_subnet.frontend_b.id

  tags = {
    Name  = "nat-gw-b"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat-gw-c" {
  allocation_id     = aws_eip.natgw-c.allocation_id
  connectivity_type = "public"
  subnet_id         = aws_subnet.frontend_c.id

  tags = {
    Name  = "nat-gw-c"
  }

  depends_on = [aws_internet_gateway.igw]
}

# vpc endpoint for secrets manager
resource "aws_security_group_rule" "secretsmanager_vpce_ingress_https" {
  security_group_id = aws_security_group.secretsmanager_vpce.id
  description       = "Allows HTTPS from vpc cidr block"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.main.cidr_block]
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type = "Interface"

  subnet_ids         = local.frontend_subnets
  security_group_ids = [aws_security_group.secretsmanager_vpce.id]

  private_dns_enabled = true
}