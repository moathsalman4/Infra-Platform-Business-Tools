resource "aws_vpc" "main_vpc" {
  cidr_block           = var.cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.env_name}-vpc"
  }
}

# 1. Fetch available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# 2. Create 3 Public Subnets
resource "aws_subnet" "public_subnet" {
  count  = var.subnet_count
  vpc_id = aws_vpc.main_vpc.id

  # Dynamically calculate CIDR (e.g., 10.0.1.0/24, 10.0.2.0/24, etc.)
  cidr_block = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, count.index + 1)

  # Distribute across first 3 available AZs
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env_name}-public-subnet-${count.index + 1}"

    "kubernetes.io/role/elb" = "1"
    # kubernetes.io/cluster/<cluster-name>=shared
  }
}

resource "aws_subnet" "private_subnet" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, count.index + 10) # 10.0.10.0/24, 10.0.11.0/24, etc.
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                              = "${var.env_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
    # kubernetes.io/cluster/<cluster-name>=shared
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.env_name}-igw"
  }
  depends_on = [aws_vpc.main_vpc]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.env_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  # No 0.0.0.0/0 route — keeps private subnets isolated from internet
  # Local VPC routing happens automatically

  tags = {
    Name = "${var.env_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}