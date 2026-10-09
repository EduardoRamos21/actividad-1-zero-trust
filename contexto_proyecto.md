# Contexto Global del Proyecto: Gestión de Servidores y Ciberseguridad

## 1. Restricciones de Infraestructura (AWS Learner Lab)
*   **Presupuesto estricto:** Límite de $50 USD. NO utilizar NAT Gateways, Transit Gateways, ni balanceadores de carga (ALB/ELB) costosos.
*   **Persistencia:** Las instancias EC2 se apagan automáticamente después de 4 horas. Para evitar que el cambio de IP rompa la configuración de Certbot, asignar una Elastic IP a la instancia del Frontend.
*   **Aprovisionamiento:** Utilizar Terraform como Infraestructura como Código (IaC).

## 2. Arquitectura de Red (AWS)
*   Implementar dos VPC independientes, una destinada al Frontend y otra al Backend.
*   La comunicación entre ambas VPC deberá establecerse mediante VPC Peering, configurando las tablas de rutas y los mecanismos de seguridad necesarios.
*   Configurar los mecanismos de seguridad de AWS bajo el principio de mínimo privilegio[cite: 1].
*   Permitir únicamente los puertos, protocolos, orígenes y destinos necesarios para el funcionamiento de la aplicación[cite: 1].
*   El Backend no deberá exponerse públicamente cuando la comunicación privada mediante VPC Peering sea suficiente[cite: 1]. 

## 3. Desarrollo de la Aplicación
*   **Frontend (React/Vite):** Aplicar una arquitectura moderna basada en componentes reutilizables, separación de responsabilidades y organización modular[cite: 1]. El Frontend deberá contener una pantalla de inicio de sesión y un Dashboard protegido para usuarios autenticados[cite: 1].
*   **Backend (Node.js/Express):** Separar el dominio y la lógica de negocio de los mecanismos externos de comunicación, persistencia y autenticación[cite: 1]. La arquitectura deberá permitir mantener desacoplada la lógica de negocio[cite: 1].

## 4. Seguridad y Zero Trust
*   La solución deberá implementar los principios de Zero Trust, considerando que ningún usuario, dispositivo o servicio es confiable automáticamente[cite: 1].
*   Implementar un mecanismo de autenticación mediante usuario y contraseña utilizando JWT (JSON Web Tokens)[cite: 1].
*   El Backend deberá validar el token antes de permitir el acceso a los recursos protegidos[cite: 1].
*   El Frontend deberá utilizar la información de autenticación para permitir el acceso al Dashboard[cite: 1].
*   Configurar un dominio y establecer comunicación segura mediante HTTPS, utilizando Certbot para la instalación y administración del certificado digital[cite: 1].
*   Implementar Fail2Ban para identificar intentos repetidos de autenticación fallida y establecer un mecanismo de bloqueo temporal de la dirección IP[cite: 1].
*   Configurar los encabezados de seguridad (ej. usando Helmet) necesarios para alcanzar una valoración favorable en SecurityHeaders.com[cite: 1].