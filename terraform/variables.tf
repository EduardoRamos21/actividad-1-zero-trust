# ============================================================================
# variables.tf - Variables de configuración para la infraestructura Zero Trust
# ============================================================================
# Proyecto: Gestión de Servidores y Ciberseguridad - Actividad 1
# Arquitectura: Dos VPCs (Frontend/Backend) con VPC Peering
# Restricciones: AWS Learner Lab ($50 USD) - Sin NAT GW, Transit GW ni ALB
# ============================================================================

# ------------------------------
# Región y Proveedor
# ------------------------------
variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

# ------------------------------
# Nombre del Proyecto
# ------------------------------
variable "project_name" {
  description = "Nombre del proyecto para etiquetar los recursos"
  type        = string
  default     = "zerotrust-webapp"
}

# ------------------------------
# Red - VPC Frontend
# ------------------------------
variable "frontend_vpc_cidr" {
  description = "Bloque CIDR para la VPC del Frontend"
  type        = string
  default     = "10.0.0.0/16"
}

variable "frontend_public_subnet_cidr" {
  description = "Bloque CIDR para la subred pública del Frontend"
  type        = string
  default     = "10.0.1.0/24"
}

variable "frontend_az" {
  description = "Zona de disponibilidad del Frontend. Null = la primera AZ disponible de la región."
  type        = string
  default     = null
}

# ------------------------------
# Red - VPC Backend
# ------------------------------
variable "backend_vpc_cidr" {
  description = "Bloque CIDR para la VPC del Backend"
  type        = string
  default     = "10.1.0.0/16"
}

variable "backend_private_subnet_cidr" {
  description = "Bloque CIDR para la subred privada del Backend"
  type        = string
  default     = "10.1.1.0/24"
}

variable "backend_az" {
  description = "Zona de disponibilidad del Backend. Null = la misma AZ que el Frontend."
  type        = string
  default     = null
}

# ------------------------------
# Instancias EC2
# ------------------------------
variable "instance_type" {
  description = "Tipo de instancia EC2 (t2.micro elegible para capa gratuita)"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI de Ubuntu 22.04. Vacío = la más reciente publicada por Canonical en la región."
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "Nombre del Key Pair ya creado en AWS (en Learner Lab suele ser vockey)"
  type        = string

  validation {
    condition     = length(var.key_pair_name) > 0 && var.key_pair_name != "mi-keypair"
    error_message = "Define key_pair_name en terraform.tfvars. En AWS Academy Learner Lab el par suele llamarse vockey."
  }
}

# ------------------------------
# Seguridad - IP del Administrador
# ------------------------------
variable "admin_ip" {
  description = "Tu IP pública para SSH al Frontend, en formato x.x.x.x/32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_ip)) && var.admin_ip != "0.0.0.0/0"
    error_message = "admin_ip debe ser tu IP pública con máscara /32, por ejemplo 189.203.10.4/32. No uses 0.0.0.0/0. Consúltala en https://ifconfig.me"
  }
}

# ------------------------------
# Puerto de la API del Backend
# ------------------------------
variable "backend_api_port" {
  description = "Puerto en el que escucha la API del Backend (Node.js)"
  type        = number
  default     = 3000
}
