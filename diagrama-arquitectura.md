# Diagrama de arquitectura — Actividad 1 Zero Trust

Abrir este archivo en [Mermaid Live](https://mermaid.live) o en un visor de Markdown que renderice Mermaid, y exportar PNG o SVG para el reporte.

## 1. Infraestructura AWS, red y controles Zero Trust

```mermaid
flowchart TB
  subgraph Internet["Internet"]
    User["Usuario del navegador"]
    Admin["Administrador SSH solo desde su IP /32"]
    LE["Let's Encrypt"]
  end

  subgraph VPCF["VPC Frontend 10.0.0.0/16"]
    IGW["Internet Gateway"]
    subgraph SubF["Subred publica 10.0.1.0/24"]
      EIP["Elastic IP"]
      EC2F["EC2 Frontend Ubuntu 22.04 t2.micro<br/>IP privada 10.0.1.x"]
    end
    RTF["Tabla de rutas Frontend<br/>0.0.0.0/0 hacia IGW<br/>10.1.0.0/16 hacia Peering"]
    SGF["Security Group Frontend<br/>80 y 443 desde 0.0.0.0/0<br/>22 solo desde IP admin<br/>ICMP desde 10.1.0.0/16"]
  end

  Peer["VPC Peering activo<br/>DNS remoto habilitado<br/>sin Transit Gateway"]

  subgraph VPCB["VPC Backend 10.1.0.0/16 sin Internet Gateway"]
    subgraph SubB["Subred privada 10.1.1.0/24 sin IP publica"]
      EC2B["EC2 Backend Ubuntu 22.04 t2.micro<br/>solo IP privada 10.1.1.x<br/>API Node.js puerto 3000"]
    end
    RTB["Tabla de rutas Backend<br/>10.0.0.0/16 hacia Peering<br/>sin ruta 0.0.0.0/0"]
    SGB["Security Group Backend<br/>3000 y 22 y ICMP solo desde 10.0.0.0/16<br/>egress solo hacia 10.0.0.0/16"]
  end

  User -->|"HTTPS 443"| EIP
  LE -->|"HTTP-01 puerto 80"| EIP
  Admin -->|"SSH 22"| EIP
  EIP --- EC2F
  EC2F --- SGF
  EC2F --- RTF
  RTF --> IGW
  RTF --> Peer
  Peer --> RTB
  RTB --- EC2B
  EC2B --- SGB
  EC2F -->|"trafico privado peering<br/>proxy /api hacia :3000 y SSH bastion"| EC2B
```

## 2. Software en cada instancia y flujo de autenticación

```mermaid
flowchart LR
  subgraph FrontSW["Frontend: componentes React y Nginx"]
    Nginx["Nginx proxy inverso<br/>Certbot TLS<br/>encabezados CSP HSTS X-Frame-Options<br/>Fail2Ban 3 intentos"]
    React["React Vite<br/>Login, Dashboard, ProtectedRoute<br/>AuthContext y api.js"]
  end

  subgraph BackSW["Backend: arquitectura limpia"]
    Routes["Rutas Express"]
    MW["Middleware JWT, rate limit, Helmet, CORS"]
    Ctrl["Controladores"]
    Svc["Servicios de negocio<br/>auth y dashboard"]
  end

  React --> Nginx
  Nginx -->|"HTTP privado solo por peering"| Routes
  Routes --> MW --> Ctrl --> Svc
```

```mermaid
sequenceDiagram
  actor U as Navegador
  participant N as Nginx HTTPS
  participant F as React
  participant B as API Node
  participant J as Fail2Ban

  U->>N: GET / por TLS
  N->>F: index.html y assets con encabezados de seguridad
  U->>F: usuario y contrasena
  F->>N: POST /api/auth/login
  N->>B: proxy por IP privada
  alt Credenciales invalidas
    B-->>N: 401
    N-->>U: 401
    J->>J: cuenta el 401 en access.log
    Note over J: Al tercer 401 bloquea la IP en 80 y 443
  else Credenciales validas
    B-->>N: 200 y JWT firmado
    N-->>F: token
    F->>F: guarda el JWT y ProtectedRoute deja ver el Dashboard
    F->>N: GET /api/dashboard con Authorization Bearer
    N->>B: proxy
    B->>B: middleware verifica firma, emisor, audiencia y expiracion
    B-->>F: datos del dashboard
  end
```

## Decisiones que el diagrama debe dejar claras en el reporte

- El Backend no tiene IP pública ni ruta a Internet. La única entrada es el CIDR `10.0.0.0/16` por el peering.
- El navegador nunca habla con el puerto 3000. Habla con Nginx en el 443, y Nginx reenvía `/api` por la red privada.
- El JWT se valida en cada petición del dashboard. No basta con que el usuario haya iniciado sesión antes.
- Fail2Ban observa el log de Nginx, no confía en la IP que declara el cliente dentro de la aplicación.
- La interfaz es de componentes reutilizables. La API separa rutas, controladores y lógica de negocio.
