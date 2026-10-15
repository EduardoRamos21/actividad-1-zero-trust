# Diagrama de arquitectura — Zero Trust

Abrir este archivo en [Mermaid Live](https://mermaid.live) o en un visor de Markdown que renderice Mermaid, y exportar PNG o SVG para el reporte.

El sitio público ya no entra por la Elastic IP. Entra por el Application Load Balancer, con AWS WAF delante. CloudFront no está en el diagrama porque el Learner Lab niega `cloudfront:CreateDistribution`.

## 1. Infraestructura AWS, red y controles Zero Trust

```mermaid
flowchart TB
  subgraph Internet["Internet"]
    User["Usuario del navegador<br/>jorgeramos1.duckdns.org"]
    Admin["Administrador<br/>SSH solo desde 177.229.207.54/32"]
  end

  WAF["AWS WAF regional zerotrust-webapp-waf<br/>SQLi, Common Rule Set XSS, rate limit 100 por 5 min<br/>accion Block"]

  subgraph VPCF["VPC Frontend 10.0.0.0/16"]
    IGW["Internet Gateway"]
    ALB["ALB zerotrust-webapp-alb<br/>80 redirige a 443<br/>443 con certificado Let's Encrypt importado en ACM<br/>IPs 54.210.212.141 y 54.145.14.252"]
    SGALB["Security Group del ALB<br/>80 y 443 desde 0.0.0.0/0"]
    subgraph SubA["Subred publica 10.0.1.0/24"]
      EIP["Elastic IP 13.223.24.247<br/>solo administracion"]
      EC2F["EC2 Frontend Ubuntu 22.04 t2.micro<br/>IP privada 10.0.1.14<br/>Nginx, React, Certbot, UFW, Fail2Ban"]
    end
    subgraph SubB["Subred publica 10.0.2.0/24"]
      AZB["Segunda zona del ALB<br/>sin instancia"]
    end
    RTF["Tabla de rutas Frontend<br/>0.0.0.0/0 hacia IGW<br/>10.1.0.0/16 hacia Peering"]
    SGF["Security Group Frontend<br/>80 y 443 solo desde el SG del ALB<br/>22 solo desde 177.229.207.54/32<br/>ICMP desde 10.1.0.0/16"]
  end

  Peer["VPC Peering activo<br/>DNS remoto habilitado<br/>sin Transit Gateway y sin NAT Gateway"]

  subgraph VPCB["VPC Backend 10.1.0.0/16 sin Internet Gateway"]
    subgraph SubPriv["Subred privada 10.1.1.0/24 sin IP publica"]
      EC2B["EC2 Backend Ubuntu 22.04 t2.micro<br/>IP privada 10.1.1.249<br/>API Node.js puerto 3000, JWT, UFW"]
    end
    RTB["Tabla de rutas Backend<br/>10.0.0.0/16 hacia Peering<br/>sin ruta 0.0.0.0/0"]
    SGB["Security Group Backend<br/>3000, 22 e ICMP solo desde 10.0.0.0/16<br/>egress solo hacia 10.0.0.0/16"]
  end

  User -->|"HTTPS 443 y HTTP 80"| WAF
  WAF --> ALB
  ALB --- SGALB
  ALB --- SubA
  ALB --- SubB
  ALB -->|"HTTP 80 y HTTPS 443"| EC2F
  Admin -->|"SSH 22"| EIP
  EIP --- EC2F
  EC2F --- SGF
  EC2F --- RTF
  RTF --> IGW
  RTF --> Peer
  Peer --> RTB
  RTB --- EC2B
  EC2B --- SGB
  EC2F -->|"Trafico privado por peering<br/>proxy /api hacia el puerto 3000 y SSH bastion"| EC2B
```

## 2. Software en cada instancia y flujo de autenticación

```mermaid
flowchart LR
  WAF2["AWS WAF en el ALB"]
  subgraph FrontSW["Frontend"]
    UFWF["UFW<br/>80 y 443 publicos<br/>SSH solo desde la IP admin"]
    Nginx["Nginx<br/>Certbot TLS<br/>CSP, HSTS, X-Frame-Options,<br/>X-Content-Type-Options, Referrer-Policy"]
    F2B["Fail2Ban<br/>3 intentos fallidos de login"]
    React["React Vite<br/>Login, Dashboard, ProtectedRoute"]
  end

  subgraph BackSW["Backend, sin salida a Internet"]
    UFWB["UFW<br/>3000 y 22 solo desde 10.0.0.0/16<br/>salida denegada salvo hacia el Frontend"]
    Routes["Rutas Express"]
    MW["Middleware JWT, rate limit, Helmet, CORS"]
    Svc["Servicios de auth y dashboard"]
  end

  WAF2 --> UFWF --> Nginx
  React --> Nginx
  Nginx --- F2B
  Nginx -->|"HTTP privado solo por peering"| UFWB --> Routes --> MW --> Svc
```

```mermaid
sequenceDiagram
  actor U as Navegador
  participant W as AWS WAF
  participant A as ALB HTTPS
  participant N as Nginx
  participant F as React
  participant B as API Node
  participant J as Fail2Ban

  U->>W: GET / por TLS
  alt Payload de XSS o SQLi
    W-->>U: 403 Block
  else Trafico normal
    W->>A: permite
    A->>N: reenvia a la instancia por 443
    N->>F: index.html y assets con encabezados
    U->>F: usuario y contrasena
    F->>N: POST /api/auth/login
    N->>B: proxy por 10.1.1.249
    alt Credenciales invalidas
      B-->>N: 401
      N-->>U: 401
      J->>J: cuenta el 401 en access.log
      Note over J: Al tercer 401 bloquea la IP en 80 y 443
    else Credenciales validas
      B-->>N: 200 y JWT firmado
      N-->>F: token
      F->>F: guarda el JWT y abre el Dashboard
      F->>N: GET /api/dashboard con Authorization Bearer
      N->>B: proxy
      B->>B: verifica firma y expiracion
      B-->>F: datos del dashboard
    end
  end
```

## Decisiones que el diagrama debe dejar claras en el reporte

- El punto de entrada público es el ALB. AWS WAF está asociado a ese balanceador, en alcance regional y en modo Block.
- DuckDNS solo admite un registro A. El dominio apunta a `54.210.212.141`, una IP del ALB. La otra IP del balanceador es `54.145.14.252`.
- La Elastic IP `13.223.24.247` no publica la web. Sirve para SSH del administrador. Los puertos 80 y 443 de la instancia solo aceptan el security group del ALB.
- El certificado lo emitió Certbot en Nginx. El ALB presenta ese mismo certificado, importado en ACM, porque DuckDNS no permite el CNAME de validación de un certificado nuevo de ACM.
- El Backend no tiene IP pública ni ruta a Internet. La API solo acepta el CIDR `10.0.0.0/16` por el peering, en el security group y en UFW.
- El navegador nunca habla con el puerto 3000. Habla con el ALB en el 443, Nginx reenvía `/api` por la red privada y el Backend responde solo hacia el Frontend.
- UFW está activo en los dos servidores y coincide con los security groups. En el Backend la salida también está denegada, salvo hacia la VPC del Frontend.
- El JWT se valida en cada petición del dashboard. Fail2Ban observa el log de Nginx.
