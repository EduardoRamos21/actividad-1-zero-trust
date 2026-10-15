# ============================================================================
# outputs.tf - Outputs de la infraestructura desplegada
# ============================================================================
# Muestra los valores clave tras el despliegue para configuración posterior
# ============================================================================

# --- VPC Frontend ---
output "frontend_vpc_id" {
  description = "ID de la VPC del Frontend"
  value       = aws_vpc.frontend.id
}

output "frontend_vpc_cidr" {
  description = "CIDR de la VPC del Frontend"
  value       = aws_vpc.frontend.cidr_block
}

output "frontend_subnet_id" {
  description = "ID de la subred pública del Frontend"
  value       = aws_subnet.frontend_public.id
}

# --- VPC Backend ---
output "backend_vpc_id" {
  description = "ID de la VPC del Backend"
  value       = aws_vpc.backend.id
}

output "backend_vpc_cidr" {
  description = "CIDR de la VPC del Backend"
  value       = aws_vpc.backend.cidr_block
}

output "backend_subnet_id" {
  description = "ID de la subred privada del Backend"
  value       = aws_subnet.backend_private.id
}

# --- VPC Peering ---
output "vpc_peering_id" {
  description = "ID de la conexión VPC Peering"
  value       = aws_vpc_peering_connection.frontend_to_backend.id
}

output "vpc_peering_status" {
  description = "Estado de la conexión VPC Peering"
  value       = aws_vpc_peering_connection.frontend_to_backend.accept_status
}

# --- Instancia EC2 Frontend ---
output "frontend_instance_id" {
  description = "ID de la instancia EC2 del Frontend"
  value       = aws_instance.frontend.id
}

output "frontend_elastic_ip" {
  description = "Elastic IP del Frontend (usar para dominio y Certbot)"
  value       = aws_eip.frontend_eip.public_ip
}

output "frontend_private_ip" {
  description = "IP privada de la instancia Frontend"
  value       = aws_instance.frontend.private_ip
}

# --- Instancia EC2 Backend ---
output "backend_instance_id" {
  description = "ID de la instancia EC2 del Backend"
  value       = aws_instance.backend.id
}

output "backend_private_ip" {
  description = "IP privada de la instancia Backend (usada para proxy inverso)"
  value       = aws_instance.backend.private_ip
}

# --- Security Groups ---
output "frontend_sg_id" {
  description = "ID del Security Group del Frontend"
  value       = aws_security_group.frontend_sg.id
}

output "backend_sg_id" {
  description = "ID del Security Group del Backend"
  value       = aws_security_group.backend_sg.id
}

# --- ALB + WAF ---
output "alb_dns_name" {
  description = "DNS del Application Load Balancer, punto de entrada protegido por WAF"
  value       = aws_lb.frontend.dns_name
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.frontend.arn
}

output "waf_acl_id" {
  description = "ID del Web ACL de WAF"
  value       = aws_wafv2_web_acl.frontend_waf.id
}

output "waf_acl_arn" {
  description = "ARN del Web ACL de WAF"
  value       = aws_wafv2_web_acl.frontend_waf.arn
}

# --- Resumen de Conexión ---
output "resumen_conexion" {
  description = "Resumen de las conexiones de la arquitectura"
  value = <<-EOT

  ╔══════════════════════════════════════════════════════════════╗
  ║              INFRAESTRUCTURA ZERO TRUST DESPLEGADA          ║
  ╠══════════════════════════════════════════════════════════════╣
  ║                                                              ║
  ║  Frontend (Público):                                         ║
  ║    Elastic IP:  ${aws_eip.frontend_eip.public_ip}
  ║    IP Privada:  ${aws_instance.frontend.private_ip}
  ║    VPC CIDR:    ${var.frontend_vpc_cidr}
  ║                                                              ║
  ║  Backend (Privado):                                          ║
  ║    IP Privada:  ${aws_instance.backend.private_ip}
  ║    VPC CIDR:    ${var.backend_vpc_cidr}
  ║    Puerto API:  ${var.backend_api_port}
  ║                                                              ║
  ║  VPC Peering:   ${aws_vpc_peering_connection.frontend_to_backend.id}
  ║                                                              ║
  ║  ALB:           ${aws_lb.frontend.dns_name}
  ║  WAF ACL:       ${aws_wafv2_web_acl.frontend_waf.name}
  ║                                                              ║
  ║  SSH al Frontend:                                            ║
  ║    ssh -i <key>.pem ubuntu@${aws_eip.frontend_eip.public_ip}
  ║                                                              ║
  ║  SSH al Backend (via Frontend como bastion):                 ║
  ║    ssh -J ubuntu@${aws_eip.frontend_eip.public_ip} ubuntu@${aws_instance.backend.private_ip}
  ║                                                              ║
  ║  DuckDNS: apunta el dominio a una IP publica del ALB, no a la EIP.
  ║  La EIP ${aws_eip.frontend_eip.public_ip} queda solo para SSH.
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝

  EOT
}

