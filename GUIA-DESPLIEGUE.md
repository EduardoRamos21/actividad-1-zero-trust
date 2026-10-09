# Guía de despliegue — Actividad 1 Zero Trust

Haz toda la parte de AWS en **una sola sesión** del Learner Lab. Las instancias se apagan a las 4 horas y, si el laboratorio se reinicia, la Elastic IP cambia y el certificado deja de coincidir.

Usuarios de la práctica (están en `backend/src/services/authService.js`):

| Usuario | Contraseña   | Rol           |
|---------|--------------|---------------|
| admin   | Admin123!    | administrator |
| auditor | Auditor123!  | auditor       |

## 1. Probar en tu computadora

En una terminal, dentro de `backend`:

```powershell
npm install
npm test
npm start
```

En otra terminal, dentro de `frontend`:

```powershell
npm run dev
```

Abre http://localhost:5173, entra con `admin` / `Admin123!` y confirma que aparece el dashboard. Para el build que subirás a AWS:

```powershell
cd frontend
npm run build
```

Ese build llama a `/api` en el mismo dominio. No pongas la IP privada del backend en el frontend: el navegador de quien visita la página no puede entrar a la VPC.

## 2. Antes de Terraform

1. Entra a AWS Academy y pulsa **Start Lab**. Espera a que el semáforo quede verde.
2. Abre **AWS Details** y copia las credenciales temporales (Access Key, Secret Key y **Session Token**).
3. Anota la **región** del laboratorio. Tiene que ser la misma en las credenciales y en Terraform.
4. En la consola EC2, región del lab, revisa **Key pairs**. En Learner Lab el par suele llamarse `vockey`. Descarga el `.pem` si aún no lo tienes. No lo subas a git.
5. Abre https://ifconfig.me y copia tu IPv4.

En PowerShell, en la carpeta `terraform` (pega tus valores reales):

```powershell
$env:AWS_ACCESS_KEY_ID = "ASIA..."
$env:AWS_SECRET_ACCESS_KEY = "..."
$env:AWS_SESSION_TOKEN = "..."
$env:AWS_DEFAULT_REGION = "us-east-1"
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars`:

```hcl
aws_region    = "us-east-1"
project_name  = "zerotrust-webapp"
key_pair_name = "vockey"
admin_ip      = "TU.IP.PUBLICA/32"
```

`admin_ip` lleva `/32`. Si tu IP cambia de red (datos móviles, otro Wi-Fi), actualiza la variable y vuelve a aplicar, o perderás el SSH.

## 3. Crear la infraestructura

Instala Terraform si no lo tienes: https://developer.hashicorp.com/terraform/install

```powershell
terraform init
terraform plan
terraform apply
```

Confirma con `yes`. Al terminar, `terraform output` muestra la Elastic IP, la IP privada del backend y los comandos SSH. Guarda ese output: es una evidencia.

El backend **no tiene Internet**. No intentes `apt-get` ahí. Node.js se instala en el frontend y se copia por el peering. Un NAT Gateway queda fuera del presupuesto de 50 USD y, además, el peering de AWS no deja salir a Internet “atravesando” la otra VPC.

## 4. Dominio

Let's Encrypt solo emite el certificado si un nombre DNS apunta a la Elastic IP.

1. Crea un host gratis en https://www.duckdns.org (por ejemplo `tunombre.duckdns.org`).
2. En el registro A pon la Elastic IP del output.
3. Espera un minuto y comprueba:

```powershell
nslookup tunombre.duckdns.org
```

Tiene que devolver la Elastic IP.

## 5. Entrar al Frontend y preparar el servidor

Desde la carpeta del proyecto, con OpenSSH de Windows (ajusta la ruta del `.pem` y la IP):

```powershell
icacls .\vockey.pem /inheritance:r
icacls .\vockey.pem /grant:r "$($env:USERNAME):(R)"

scp -i .\vockey.pem -r .\scripts ubuntu@ELASTIC_IP:~/scripts
ssh -i .\vockey.pem ubuntu@ELASTIC_IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
scp -i .\vockey.pem .\vockey.pem ubuntu@ELASTIC_IP:~/.ssh/lab-key.pem

# No copies backend\.env: es el secreto de tu PC. El script del servidor genera el de producción.
ssh -i .\vockey.pem ubuntu@ELASTIC_IP "rm -rf ~/zerotrust-backend && mkdir -p ~/zerotrust-backend"
scp -i .\vockey.pem -r .\backend\src .\backend\package.json .\backend\package-lock.json ubuntu@ELASTIC_IP:~/zerotrust-backend/
```

Si `package-lock.json` todavía no existe, ejecuta antes `npm install` dentro de `backend`.

En la instancia:

```bash
ssh -i vockey.pem ubuntu@ELASTIC_IP
chmod 400 ~/.ssh/lab-key.pem
chmod +x ~/scripts/*.sh
sudo ~/scripts/setup-frontend.sh tunombre.duckdns.org IP_PRIVADA_BACKEND TU_IP_SIN_MASCARA
```

El tercer argumento es tu IP **sin** `/32`. Fail2Ban la ignora para que las pruebas no te dejen fuera del SSH. Al final del script debe verse el filtro de ejemplo con **1 matched**. Si dice 0 matched, no sigas: el jail no va a detectar los 401.

Sube el frontend ya construido (en tu PC, después de `npm run build`):

```powershell
ssh -i .\vockey.pem ubuntu@ELASTIC_IP "rm -rf ~/frontend-dist"
scp -i .\vockey.pem -r .\frontend\dist ubuntu@ELASTIC_IP:~/frontend-dist
```

En el servidor:

```bash
sudo rm -rf /var/www/tunombre.duckdns.org/html/*
sudo cp -a ~/frontend-dist/. /var/www/tunombre.duckdns.org/html/
sudo chown -R www-data:www-data /var/www/tunombre.duckdns.org/html
```

## 6. Backend por la red privada

Sigue en el Frontend, como usuario `ubuntu`:

```bash
~/scripts/deploy-backend.sh IP_PRIVADA_BACKEND ~/.ssh/lab-key.pem https://tunombre.duckdns.org
```

El script instala las dependencias en el Frontend, genera `JWT_SECRET`, copia Node y la API, y levanta `zerotrust-api`. La última línea tiene que ser el JSON de `/api/health`.

Comprueba el peering desde el Frontend:

```bash
ping -c 4 IP_PRIVADA_BACKEND
curl -sS http://IP_PRIVADA_BACKEND:3000/api/health
ip route
```

`ip route` debe mostrar `10.1.0.0/16` vía la interfaz local (el peering). En el backend, `ip route` debe mostrar `10.0.0.0/16` y **no** debe haber `default via`.

Para entrar al backend y sacar esa captura:

```bash
ssh -i ~/.ssh/lab-key.pem ubuntu@IP_PRIVADA_BACKEND
ip route
curl -sS http://127.0.0.1:3000/api/health
systemctl status zerotrust-api --no-pager
exit
```

## 7. HTTPS

Cuando `nslookup` ya devuelva la Elastic IP:

```bash
sudo ~/scripts/enable-https.sh tunombre.duckdns.org
```

Abre `https://tunombre.duckdns.org`. El candado tiene que ser de Let's Encrypt. Inicia sesión y entra al dashboard.

En el servidor:

```bash
curl -sI https://tunombre.duckdns.org
sudo certbot certificates
```

## 8. Fail2Ban

Haz esta prueba **desde otra red** (datos móviles), porque tu IP de casa está en `ignoreip`.

Tres veces:

```bash
curl -sk -o /dev/null -w "%{http_code}\n" -X POST https://tunombre.duckdns.org/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"mala\"}"
```

Tienes que ver `401` tres veces. Espera unos 10 segundos y, en el servidor:

```bash
sudo fail2ban-client status nginx-login-abuse
sudo tail -n 20 /var/log/nginx/access.log
```

La IP de prueba debe aparecer en `Banned IP list`. Un cuarto `curl` desde esa misma red no debe conectar. Para desbloquear:

```bash
sudo fail2ban-client set nginx-login-abuse unbanip LA.IP.BANEADA
```

El jail de Nginx solo cierra 80 y 443. El SSH (puerto 22) sigue abierto para tu IP. El jail `sshd` es aparte: no hagas pruebas de fuerza bruta contra el 22.

## 9. SecurityHeaders

Con el sitio ya en HTTPS, abre:

https://securityheaders.com/?q=https://tunombre.duckdns.org&followRedirects=on

Guarda la captura de la calificación y de la lista de encabezados. Los que envía Nginx están en `/etc/nginx/snippets/zerotrust-headers.conf`.

## 10. Qué capturar para el reporte

Cada captura lleva una frase: qué demuestra, qué configuraste y qué resultado obtuviste. No captures el `.pem`, las claves del Learner Lab ni el `JWT_SECRET`.

| # | Qué se ve | Dónde |
|---|-----------|--------|
| 1 | Dos VPC con `10.0.0.0/16` y `10.1.0.0/16` | Consola VPC |
| 2 | Subred pública del frontend y subred privada del backend, sin IP pública automática | Consola Subnets |
| 3 | Peering en estado Active | Consola Peering connections |
| 4 | Ruta `0.0.0.0/0` al Internet Gateway y `10.1.0.0/16` al peering | Route table del frontend |
| 5 | Solo la ruta `10.0.0.0/16` al peering, sin ruta por defecto | Route table del backend |
| 6 | Puertos 80 y 443 abiertos a Internet y 22 solo a tu `/32` | Security group frontend |
| 7 | Puertos 3000, 22 e ICMP solo desde `10.0.0.0/16` | Security group backend |
| 8 | Frontend con Elastic IP y backend solo con IP privada | Consola EC2 |
| 9 | `terraform output` con IDs, IPs y peering | Tu terminal |
| 10 | `ping` y `curl` de health desde el frontend hacia la IP privada del backend | SSH del frontend |
| 11 | `ip route` del backend sin puerta de enlace por defecto | SSH del backend |
| 12 | `systemctl status zerotrust-api` en active | SSH del backend |
| 13 | Árbol de `backend/src` (rutas, controladores, servicios, middleware) | Tu editor |
| 14 | Árbol de `frontend/src` (Login, Dashboard, ProtectedRoute, AuthContext) | Tu editor |
| 15 | Pantalla de login en `https://tu-dominio` con candado | Navegador |
| 16 | Certificado de Let's Encrypt (candado, detalle del certificado) | Navegador |
| 17 | `sudo certbot certificates` | SSH del frontend |
| 18 | Pestaña Red: `POST /api/auth/login` por HTTPS y respuesta con `token` | DevTools del navegador |
| 19 | Petición fallida con contraseña incorrecta, estado 401 | DevTools |
| 20 | `localStorage` con la clave `token` | DevTools, Application |
| 21 | Dashboard ya autenticado | Navegador |
| 22 | `GET /api/dashboard` con encabezado `Authorization: Bearer` | DevTools |
| 23 | `curl` a `/api/dashboard` sin token, respuesta 401 | SSH del frontend |
| 24 | `curl -sI https://tu-dominio` mostrando CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy y Permissions-Policy | SSH del frontend |
| 25 | Resultado de SecurityHeaders.com | El sitio |
| 26 | Tres líneas 401 en `/var/log/nginx/access.log` | SSH del frontend |
| 27 | `fail2ban-client status nginx-login-abuse` con la IP en la lista de baneados | SSH del frontend |
| 28 | Cuarto intento desde la IP baneada, sin respuesta | La otra red |
| 29 | Diagrama de `diagrama-arquitectura.md` exportado a imagen | Mermaid Live |
| 30 | URLs de los repositorios git del frontend y del backend | GitHub o el hosting que pida la actividad |

Para el punto 23, desde el frontend:

```bash
curl -si https://tunombre.duckdns.org/api/dashboard | head -n 20
```

Tiene que responder 401. Con un token válido (cópialo de DevTools) el mismo `curl` con `-H "Authorization: Bearer TOKEN"` responde 200.

## 11. Repositorios que pide la entrega

La actividad pide una URL de git del frontend y otra del backend. No subas `node_modules`, `.env`, `terraform.tfvars` ni el `.pem`.

El `.gitignore` del backend ya excluye `.env`. El de Terraform excluye `terraform.tfvars`.

## 12. Apagar y no gastar el crédito

Cuando termines las capturas:

```powershell
cd terraform
terraform destroy
```

Si el lab se corta antes, los recursos se borran solos, pero `terraform destroy` mientras la sesión sigue viva evita dejar instancias encendidas.
