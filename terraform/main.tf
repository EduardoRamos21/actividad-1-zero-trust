# ============================================================================
# main.tf - Infraestructura Zero Trust en AWS con Terraform
# ============================================================================
# Proyecto: Gestión de Servidores y Ciberseguridad - Actividad 1
# Arquitectura: 2 VPCs (Frontend público + Backend privado) + VPC Peering
# Enfoque: Zero Trust - Mínimo privilegio, segmentación, validación continua
# Restricciones: AWS Learner Lab ($50 USD) - Sin NAT GW, Transit GW ni ALB
# ============================================================================

# ------------------------------
# Proveedor AWS
# ------------------------------
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "development"
      ManagedBy   = "terraform"
      ZeroTrust   = "true"
    }
  }
}

# AMI oficial de Ubuntu 22.04 (Canonical). Se puede forzar con var.ami_id.
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu_2204.id
  az     = coalesce(var.frontend_az, data.aws_availability_zones.available.names[0])
}

# ============================================================================
# 1. VPC DEL FRONTEND (Pública - Accesible desde Internet)
# ============================================================================

resource "aws_vpc" "frontend" {
  cidr_block           = var.frontend_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-frontend-vpc"
    Tier = "frontend"
  }
}

# Subred Pública del Frontend
resource "aws_subnet" "frontend_public" {
  vpc_id                  = aws_vpc.frontend.id
  cidr_block              = var.frontend_public_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-frontend-public-subnet"
    Tier = "public"
  }
}

# Internet Gateway para el Frontend (acceso público)
resource "aws_internet_gateway" "frontend_igw" {
  vpc_id = aws_vpc.frontend.id

  tags = {
    Name = "${var.project_name}-frontend-igw"
  }
}

# Tabla de Rutas del Frontend
resource "aws_route_table" "frontend_public_rt" {
  vpc_id = aws_vpc.frontend.id

  # Ruta hacia Internet a través del IGW
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.frontend_igw.id
  }

  # Ruta hacia la VPC del Backend a través del VPC Peering
  route {
    cidr_block                = var.backend_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.frontend_to_backend.id
  }

  tags = {
    Name = "${var.project_name}-frontend-public-rt"
  }
}

# Asociación de la tabla de rutas con la subred del Frontend
resource "aws_route_table_association" "frontend_public_rta" {
  subnet_id      = aws_subnet.frontend_public.id
  route_table_id = aws_route_table.frontend_public_rt.id
}

# ============================================================================
# 2. VPC DEL BACKEND (Privada - Sin acceso público directo)
# ============================================================================

resource "aws_vpc" "backend" {
  cidr_block           = var.backend_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-backend-vpc"
    Tier = "backend"
  }
}

# Subred Privada del Backend
resource "aws_subnet" "backend_private" {
  vpc_id            = aws_vpc.backend.id
  cidr_block        = var.backend_private_subnet_cidr
  availability_zone = coalesce(var.backend_az, local.az)

  # NO asignar IP pública automáticamente (subred privada)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-backend-private-subnet"
    Tier = "private"
  }
}

# Tabla de Rutas del Backend (solo peering, SIN ruta a Internet)
resource "aws_route_table" "backend_private_rt" {
  vpc_id = aws_vpc.backend.id

  # Ruta hacia la VPC del Frontend a través del VPC Peering
  route {
    cidr_block                = var.frontend_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.frontend_to_backend.id
  }

  # NO hay ruta 0.0.0.0/0 -> Sin acceso a Internet (Zero Trust)
  # El Backend solo se comunica con el Frontend via peering

  tags = {
    Name = "${var.project_name}-backend-private-rt"
  }
}

# Asociación de la tabla de rutas con la subred del Backend
resource "aws_route_table_association" "backend_private_rta" {
  subnet_id      = aws_subnet.backend_private.id
  route_table_id = aws_route_table.backend_private_rt.id
}

# ============================================================================
# 3. VPC PEERING (Comunicación privada Frontend <-> Backend)
# ============================================================================

resource "aws_vpc_peering_connection" "frontend_to_backend" {
  vpc_id      = aws_vpc.frontend.id       # VPC solicitante (Frontend)
  peer_vpc_id = aws_vpc.backend.id        # VPC aceptante (Backend)
  auto_accept = true # Misma cuenta y región: se acepta al crearse

  tags = {
    Name = "${var.project_name}-peering-frontend-to-backend"
  }
}

# Las opciones DNS se aplican cuando el peering ya está activo.
resource "aws_vpc_peering_connection_options" "dns" {
  vpc_peering_connection_id = aws_vpc_peering_connection.frontend_to_backend.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

# ============================================================================
# 4. SECURITY GROUPS (Principio de Mínimo Privilegio - Zero Trust)
# ============================================================================

# --- Security Group del Frontend ---
# Permite: HTTP(80), HTTPS(443) desde Internet + SSH(22) solo desde admin_ip
resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-frontend-sg"
  description = "SG Frontend: HTTP/HTTPS publico, SSH restringido a IP admin"
  vpc_id      = aws_vpc.frontend.id

  # HTTP - Acceso público (Nginx sirve la app React)
  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS - Acceso público (Certbot / Let's Encrypt)
  ingress {
    description = "HTTPS desde Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - SOLO desde la IP del administrador (Zero Trust)
  ingress {
    description = "SSH restringido a IP del administrador"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # ICMP - para evidenciar conectividad privada (ping desde el Backend)
  ingress {
    description = "ICMP desde VPC Backend"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.backend_vpc_cidr]
  }

  # Egress - Permitir todo el tráfico saliente
  egress {
    description = "Todo trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-frontend-sg"
  }
}

# --- Security Group del Backend ---
# Permite: API(3000) y SSH(22) SOLO desde el CIDR del Frontend
# CERO acceso desde Internet (Zero Trust + segmentación)
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg"
  description = "SG Backend: API y SSH solo desde VPC Frontend via peering"
  vpc_id      = aws_vpc.backend.id

  # API (Node.js) - SOLO desde la VPC del Frontend
  ingress {
    description = "API Backend desde VPC Frontend unicamente"
    from_port   = var.backend_api_port
    to_port     = var.backend_api_port
    protocol    = "tcp"
    cidr_blocks = [var.frontend_vpc_cidr]
  }

  # SSH - SOLO desde la VPC del Frontend (acceso via salto desde Frontend)
  ingress {
    description = "SSH desde VPC Frontend unicamente (bastion)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.frontend_vpc_cidr]
  }

  # ICMP - evidencia de peering (ping desde el Frontend)
  ingress {
    description = "ICMP desde VPC Frontend"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.frontend_vpc_cidr]
  }

  # Egress - Permitir tráfico saliente hacia la VPC del Frontend
  egress {
    description = "Trafico saliente hacia VPC Frontend"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.frontend_vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

# ============================================================================
# 5. INSTANCIAS EC2 (Ubuntu 22.04 LTS)
# ============================================================================

# --- Instancia EC2 del Frontend ---
resource "aws_instance" "frontend" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.frontend_public.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name               = var.key_pair_name

  # Sin apt en el arranque: el script setup-frontend.sh instala todo.
  # Así cloud-init no bloquea el SSH ni choca con dpkg.
  user_data = <<-EOF
    #!/bin/bash
    echo "frontend-listo $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /home/ubuntu/init_status.txt
    chown ubuntu:ubuntu /home/ubuntu/init_status.txt
  EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 20   # GB
    volume_type = "gp3"
    encrypted   = true # Cifrado en reposo
  }

  tags = {
    Name = "${var.project_name}-frontend-ec2"
    Role = "frontend-webserver"
  }
}

# --- Elastic IP para el Frontend ---
# Necesaria para persistencia de IP ante reinicios del Learner Lab
resource "aws_eip" "frontend_eip" {
  domain   = "vpc"
  instance = aws_instance.frontend.id

  tags = {
    Name = "${var.project_name}-frontend-eip"
  }

  # Asegurar que el IGW exista antes de asociar la EIP
  depends_on = [aws_internet_gateway.frontend_igw]
}

# --- Instancia EC2 del Backend ---
resource "aws_instance" "backend" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.backend_private.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.key_pair_name

  # Esta instancia NO tiene ruta a Internet (sin IGW ni NAT Gateway).
  # apt-get aquí se quedaría colgado. Node.js se copia desde el Frontend.
  user_data = <<-EOF
    #!/bin/bash
    echo "backend-listo-sin-internet $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /home/ubuntu/init_status.txt
    chown ubuntu:ubuntu /home/ubuntu/init_status.txt
  EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-backend-ec2"
    Role = "backend-api"
  }
}
