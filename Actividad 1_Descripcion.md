Actividad 1. Implementación de una aplicación web segura bajo un enfoque Zero Trust en AWS


El estudiante deberá desarrollar de manera individual una solución web distribuida en AWS, integrando arquitectura de software, infraestructura, seguridad de redes y mecanismos de protección. La actividad deberá contemplar los siguientes elementos:

Implementar dos VPC independientes, una destinada al Frontend y otra al Backend, utilizando el direccionamiento IP proporcionado para la práctica. La comunicación entre ambas VPC deberá establecerse mediante , configurando las tablas de rutas y los mecanismos de seguridad necesarios. El estudiante deberá demostrar mediante evidencias que existe conectividad privada entre ambas redes.

Desarrollar el Frontend utilizando , aplicando una arquitectura moderna basada en componentes reutilizables, separación de responsabilidades y organización modular de la interfaz. El Frontend deberá contener una pantalla de inicio de sesión y un Dashboard protegido para usuarios autenticados.

Desarrollar el Backend utilizando , separando el dominio y la lógica de negocio de los mecanismos externos de comunicación, persistencia y autenticación. La arquitectura deberá permitir mantener desacoplada la lógica de negocio respecto de la infraestructura.

Implementar un mecanismo de autenticación mediante usuario y contraseña utilizando . El Backend deberá validar el token antes de permitir el acceso a los recursos protegidos y el Frontend deberá utilizar la información de autenticación para permitir el acceso al Dashboard.

La solución deberá implementar los principios de , considerando que ningún usuario, dispositivo, servicio o comunicación deberá considerarse confiable automáticamente. Se deberá aplicar el principio , así como autenticación, autorización, mínimo privilegio, segmentación y validación de las solicitudes.

Configurar los mecanismos de seguridad de AWS bajo el principio de , permitiendo únicamente los puertos, protocolos, orígenes y destinos necesarios para el funcionamiento de la aplicación. El Backend no deberá exponerse públicamente cuando la comunicación privada mediante VPC Peering sea suficiente.

Configurar un dominio y establecer comunicación segura mediante , utilizando Certbot para la instalación y administración del certificado digital. El estudiante deberá demostrar que la aplicación funciona correctamente mediante HTTPS y que la comunicación de las credenciales y tokens se encuentra cifrada.

Implementar para identificar intentos repetidos de autenticación fallida y establecer un mecanismo de bloqueo temporal de la dirección IP cuando se supere el número de intentos definido. El estudiante deberá demostrar mediante evidencias el funcionamiento del mecanismo.

Realizar un análisis de seguridad de la aplicación mediante y configurar los encabezados de seguridad necesarios para mejorar la protección de la aplicación. El estudiante deberá documentar el resultado obtenido y las configuraciones realizadas para alcanzar una valoración favorable.

Realizar pruebas que permitan comprobar la comunicación entre las VPC, el acceso al Frontend, la comunicación Frontend–Backend, la autenticación JWT, el acceso al Dashboard, la utilización de HTTPS y el funcionamiento de Fail2Ban.

Elaborar un diagrama de arquitectura que represente la infraestructura completa implementada, incluyendo las VPC, subredes, instancias EC2, direccionamiento IP, tablas de rutas, VPC Peering, Security Groups, Frontend, Backend, flujo de autenticación JWT, HTTPS y mecanismos de seguridad Zero Trust.
El diagrama deberá representar también las arquitecturas de software utilizadas: y .

El estudiante deberá generar un expediente de evidencias mediante capturas de pantalla de las configuraciones y pruebas realizadas. Cada evidencia deberá incluir una breve descripción que explique qué se está demostrando, qué configuración se realizó y cuál fue el resultado obtenido.

Entregar un reporte técnico que describa la solución implementada, las decisiones de arquitectura, los mecanismos de seguridad utilizados, la aplicación de los principios Zero Trust, las pruebas realizadas y los resultados obtenidos.

El estudiante deberá entregar:
Anexar el url de git Código fuente del Frontend.
Anexar e url de git Código fuente del Backend.
Diagrama de arquitectura.
Evidencias de implementación.
Evidencias de pruebas.
Reporte técnico.
Evidencia del resultado de SecurityHeaders.com.
Evidencia del funcionamiento de HTTPS, JWT y Fail2Ban.