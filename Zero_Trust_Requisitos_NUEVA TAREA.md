# Guía maestra para Antigravity — Proyecto Arquitectura Zero Trust
**Base:** `Proyecto Arquitectura Zero Trust Ap.txt` + aclaraciones del profesor en el chat de clase.  
**Propósito:** usar este documento como especificación de requisitos para planificar, implementar, probar y documentar el proyecto. No dar por cumplido ningún control sin una prueba verificable.

---

## 1. Instrucción principal para Antigravity

Actúa como asistente técnico de implementación para el proyecto académico **“Arquitectura Zero Trust aplicada en Laboratorio Learning Lab”**. Primero inspecciona el código y la infraestructura existente; después presenta un plan de trabajo por fases y realiza los cambios de forma incremental. No inventes evidencias, resultados de pruebas, direcciones IP, URLs de repositorios, nombres de recursos AWS ni configuraciones que no hayan sido confirmadas.

- Conserva los requisitos de este documento como criterios de aceptación.
- Prioriza configuraciones seguras y el principio de mínimo privilegio.
- Explica qué debe configurarse manualmente en AWS Console y qué puede automatizarse.
- Antes de ejecutar cambios destructivos, reemplazar recursos o modificar reglas que puedan bloquear el acceso, explica el impacto y solicita confirmación.
- No publiques secretos, claves privadas, tokens JWT, contraseñas, archivos `.env` ni credenciales AWS en el repositorio.
- Usa variables de entorno para secretos y proporciona `.env.example` sin valores reales.
- Documenta los comandos, archivos modificados, pruebas ejecutadas y resultados reales.
- Si un dato imprescindible falta —por ejemplo, la IP pública del equipo que hará la presentación, región AWS, dominio o CIDR elegido—, solicita ese dato o deja un marcador claramente identificado. No lo adivines.
- No afirmes que la arquitectura es Zero Trust solo por tener JWT o un firewall: demuestra autenticación/autorización, segmentación y reglas restrictivas.

## 2. Objetivo del proyecto

Diseñar e implementar una aplicación web distribuida basada en los principios de **Zero Trust** y **Defensa en Profundidad**, utilizando AWS y Linux. La solución debe incorporar segmentación de red, autenticación JWT, protección perimetral, hardening de servidores, monitoreo y auditoría.

La arquitectura requiere **dos VPC independientes conectadas mediante VPC Peering**:
1. VPC Frontend.
2. VPC Backend.

La aplicación debe demostrar que la comunicación Frontend–Backend es privada y que los servicios del Backend no están expuestos directamente a Internet.

## 3. Aclaraciones del profesor: interpretación obligatoria

Las siguientes aclaraciones del chat de clase actualizan o precisan el documento original:

1. **Se omite MFA (autenticación multifactor).** No implementar MFA ni presentarlo como requisito pendiente. Se mantienen JWT y los demás controles de autenticación indicados en el documento.
2. **AWS WAF corresponde al Frontend.** Configurarlo para proteger el punto de entrada web público del Frontend. No es requisito instalar WAF en el Backend.
3. **UFW debe configurarse en el Frontend y en el Backend.** El documento original menciona UFW en ambos servidores; la aclaración del profesor no elimina ese requisito.
4. **Para la presentación final, UFW debe restringir el acceso de administración al equipo del estudiante.** La IP pública desde la que se presentará debe autorizarse explícitamente para los puertos administrativos necesarios, normalmente SSH (TCP 22), y no debe abrirse SSH a todo Internet (`0.0.0.0/0`). Confirmar y registrar la IP pública real antes de aplicar la regla.
5. La restricción de UFW para el equipo del estudiante **no significa** permitir que ese equipo acceda directamente a todos los puertos del Backend. La API del Backend debe aceptar tráfico de aplicación únicamente desde el origen privado autorizado del Frontend y por el puerto de API requerido. El acceso administrativo se limita a la IP autorizada del estudiante.
6. **No se elimina ningún otro requisito del documento original** salvo la omisión explícita de MFA. Mantener JWT, WAF en Frontend, UFW en ambos servidores, Fail2Ban, HTTPS, Security Headers, VPC Peering, Security Groups y pruebas.

### Ambigüedad de monitoreo que debe resolverse de forma conservadora

El documento original dice en “Monitoreo y Auditoría seleccionar una”: **CloudWatch o CloudTrail**. Sin embargo, en los entregables pide evidencias de **CloudWatch** y también de **CloudTrail**. Para reducir el riesgo de incumplir la lista de entregables, la recomendación de esta especificación es habilitar y documentar **ambos**, si el alcance y los permisos de la cuenta AWS lo permiten. Si el profesor confirma que basta con uno, documentar expresamente cuál se eligió y por qué; no afirmar que se entregó evidencia de un servicio que no se configuró.

## 4. Arquitectura y requisitos de red

### 4.1 VPC Frontend
Debe alojar:
- Aplicación web **React + Vite**.
- **Nginx** como servidor web / proxy inverso, según el diseño.
- **HTTPS mediante Certbot**.
- Security Headers.
- **UFW**.
- **Fail2Ban**.
- **AWS WAF** asociado al punto de entrada web público apropiado (por ejemplo, una distribución CloudFront o un Application Load Balancer compatible, según la arquitectura elegida y el alcance disponible).

El Frontend puede tener un punto de entrada público para que el usuario acceda a la web. Solo se expondrán los puertos web necesarios. La administración SSH estará restringida a la IP pública autorizada del estudiante.

### 4.2 VPC Backend
Debe alojar:
- API REST en **Node.js**.
- **Autenticación JWT**.
- Dashboard protegido.
- **UFW**.
- Servicios accesibles únicamente por la red privada autorizada.

El Backend no debe tener exposición pública directa. El documento pide verificar que el Backend no tenga acceso público a Internet y menciona como comprobación `ping 8.8.8.8`. Ejecutar y documentar esta prueba, pero no basar la conclusión únicamente en ICMP: comprobar también rutas, tablas de rutas, gateways, IP pública, Security Groups y reglas de salida. La conectividad de administración o instalación temporal debe diseñarse sin convertir el Backend en un servicio público; si se requiere salida para instalar paquetes, documentar el mecanismo aprobado y el estado final.

### 4.3 VPC Peering y direccionamiento
- Crear dos VPC distintas con bloques CIDR **no superpuestos**.
- Crear y aceptar el VPC Peering entre ellas.
- Configurar rutas en las tablas de rutas de ambas VPC para los CIDR remotos correspondientes.
- Restringir las reglas de Security Groups al mínimo necesario.
- Verificar que el Frontend llegue a la API por la **IP privada** del Backend, nunca por una IP pública.
- El Backend debe permitir el puerto de la API únicamente desde el Security Group o CIDR privado autorizado del Frontend, según las posibilidades reales de la configuración.
- No inventar CIDR, IP, región, IDs ni puertos definitivos: definirlos en un inventario de despliegue y confirmar que no se solapen con redes existentes.

### 4.4 Matriz de acceso de referencia
Ajustar los puertos al despliegue real y registrar la justificación de cada regla.

| Componente | Puerto/protocolo | Origen permitido | Criterio |
|---|---|---|---|
| Frontend web | TCP 443 | Internet, según el punto de entrada público | HTTPS público protegido por WAF |
| Frontend HTTP | TCP 80 | Internet solo si se necesita redirección HTTP→HTTPS o validación de Certbot | No servir contenido sensible por HTTP |
| SSH Frontend | TCP 22 | IP pública del estudiante `/32` y solo administradores autorizados | Nunca abrir a todo Internet |
| SSH Backend | TCP 22 | IP pública del estudiante `/32` solo si la ruta de administración está diseñada y autorizada; preferir acceso privado seguro | No abrir a todo Internet |
| API Backend | Puerto real de la API | Origen privado autorizado del Frontend | Sin exposición pública directa |
| Base de datos, si existe | Puerto real del motor | Solo el servicio Backend autorizado | No exponer públicamente |
| Otros puertos | Según necesidad demostrada | Solo origen requerido | Denegar lo innecesario |

**Importante:** las reglas de AWS Security Groups y las de UFW deben ser coherentes. Configurar solo UFW no sustituye los Security Groups de AWS, ni viceversa.

## 5. Controles Zero Trust y seguridad de aplicación

### 5.1 JWT y autorización
- Implementar autenticación mediante JWT para las rutas protegidas de la API.
- Validar el token en cada solicitud protegida: firma, expiración y claims necesarios.
- Rechazar tokens ausentes, malformados, expirados o inválidos con códigos HTTP apropiados.
- Separar autenticación de autorización: el usuario autenticado solo puede realizar acciones permitidas.
- Aplicar mínimo privilegio en rutas, roles y acceso al Dashboard.
- No guardar secretos JWT en el código fuente. Usar una variable de entorno fuerte y documentar cómo configurarla.
- No registrar tokens ni credenciales en logs.
- Incluir pruebas de acceso permitido y denegado al Dashboard y a los endpoints protegidos.
- No implementar MFA: el profesor indicó que se omite.

### 5.2 AWS WAF — solo Frontend
- Asociar AWS WAF al punto de entrada web público compatible elegido.
- Habilitar AWS Managed Rules apropiadas para amenazas web comunes.
- Incluir protección/pruebas frente a intentos de SQL Injection y XSS mediante las reglas administradas disponibles.
- Configurar Rate Limiting mediante una regla basada en tasa, con umbral justificado y adecuado al laboratorio.
- Probar de forma controlada solicitudes normales y solicitudes de prueba que deban activar reglas. No lanzar ataques contra sistemas ajenos ni realizar pruebas destructivas.
- Registrar el recurso protegido, reglas habilitadas, modo de acción (por ejemplo, Count o Block), logs/métricas disponibles y evidencia de la prueba.
- Si se usa inicialmente modo Count para validar falsos positivos, documentar el cambio a Block cuando corresponda. No declarar bloqueos exitosos si no se observan en resultados reales.
- WAF no reemplaza la validación de entrada en la API ni la autenticación.

### 5.3 UFW — Frontend y Backend
- Habilitar UFW en ambos servidores Linux.
- Definir políticas predeterminadas restrictivas, de acuerdo con la distribución y el acceso de administración requerido.
- Permitir solo los puertos necesarios.
- Autorizar SSH desde la IP pública del equipo del estudiante en formato CIDR `/32`, después de confirmar la IP.
- En el Backend, permitir el puerto de API únicamente desde el origen privado del Frontend.
- Evitar bloquear la sesión administrativa activa: verificar las reglas y disponer de un método de recuperación antes de aplicar cambios remotos.
- Documentar `ufw status verbose`, reglas numeradas y pruebas de conexión desde orígenes permitidos y no permitidos.

### 5.4 Fail2Ban
- Instalar y habilitar Fail2Ban en el Frontend para proteger el proceso de autenticación web indicado en el documento.
- Configurar una jail/filtro que corresponda a los logs reales de autenticación web de la aplicación o del servicio elegido. No asumir que Fail2Ban protege automáticamente una ruta de login de Node.js si no existe un filtro/log adecuado.
- Si se requiere una integración personalizada, implementarla y documentar el formato de log, filtro, jail, umbral, ventana de tiempo y duración del bloqueo.
- Realizar una prueba controlada con intentos fallidos y demostrar el evento de bloqueo en el estado/log de Fail2Ban.
- Evitar bloquear accidentalmente la IP de administración o la del evaluador; documentar una forma segura de desbaneo.

### 5.5 HTTPS y Security Headers
- Configurar Nginx con HTTPS usando Certbot y un dominio válido que el estudiante controle, si el método de validación lo requiere.
- Redirigir HTTP a HTTPS cuando HTTP esté habilitado.
- Implementar y verificar:
  - HSTS (`Strict-Transport-Security`).
  - CSP (`Content-Security-Policy`), ajustada a los recursos reales de React/Vite; no usar una política permisiva sin justificación.
  - `X-Frame-Options`.
  - `X-Content-Type-Options`.
  - `Referrer-Policy`.
- Comprobar los encabezados con herramientas de línea de comandos o el navegador y conservar la salida como evidencia.
- No afirmar que HTTPS funciona hasta comprobar el certificado, la cadena y el acceso real.

## 6. Monitoreo y auditoría

**Objetivo recomendado para cubrir todos los entregables:** configurar ambos servicios si es viable.

### CloudWatch
- Habilitar métricas y/o logs útiles para los recursos desplegados, de acuerdo con lo que soporte la arquitectura.
- Si se envían logs de Linux/Nginx/aplicación, documentar el agente y las fuentes de log realmente configuradas.
- Capturar una evidencia del panel, grupo de logs, métricas o alarma pertinente.
- No afirmar que se están enviando logs del sistema si no se configuró el agente o mecanismo correspondiente.

### CloudTrail
- Verificar que exista un trail o mecanismo de historial de eventos que permita evidenciar operaciones relevantes de la cuenta.
- Capturar una evidencia de eventos relacionados con la configuración del proyecto, sin revelar datos sensibles.
- Documentar alcance, región y destino de logs si se configura un trail.

Si por limitaciones de cuenta, costo o instrucciones confirmadas solo se configura uno, dejar registrada la limitación y no presentar el otro como completado.

## 7. Entregables obligatorios del documento del profesor

Preparar una carpeta `docs/evidencias/` con nombres descriptivos. Las capturas deben ser auténticas, legibles y mostrar el recurso o comando relevante. Ocultar credenciales, tokens, información privada y datos no necesarios.

1. URL del repositorio Git Frontend.
2. URL del repositorio Git Backend.
3. Diagrama actualizado de arquitectura.
4. Evidencias de configuración de las VPC y VPC Peering.
5. Evidencias de Security Groups.
6. Evidencias de UFW.
7. Evidencias de JWT y Dashboard protegido.
8. Evidencias de HTTPS y Certbot.
9. Evidencias de Security Headers.
10. Evidencias del funcionamiento de Fail2Ban.
11. Evidencias de implementación y pruebas de AWS WAF.
12. Evidencias de CloudWatch.
13. Evidencias de CloudTrail.
14. Evidencias de pruebas funcionales y de seguridad.
15. Reporte técnico.
16. Fuentes de información.
17. Conclusión.

### Estructura de documentación sugerida

```text
docs/
├── arquitectura.md
├── reporte-tecnico.md
├── pruebas.md
├── fuentes.md
└── evidencias/
    ├── 01-vpcs-peering/
    ├── 02-security-groups/
    ├── 03-ufw/
    ├── 04-jwt-dashboard/
    ├── 05-https-certbot/
    ├── 06-security-headers/
    ├── 07-fail2ban/
    ├── 08-aws-waf/
    ├── 09-cloudwatch/
    ├── 10-cloudtrail/
    └── 11-pruebas-funcionales-seguridad/
```

No crear capturas ficticias. Si una evidencia todavía no existe, dejarla como pendiente con la descripción exacta de cómo obtenerla.

## 8. Plan de implementación sugerido

1. **Inventario y revisión:** inspeccionar repositorios, stack, región, CIDR, dominio, sistema operativo, puertos y estado de AWS.
2. **Diseño de red:** proponer diagrama, CIDR no superpuestos, tablas de rutas, peering y matriz de acceso.
3. **VPC y conectividad:** configurar las dos VPC, peering, rutas y Security Groups; comprobar rutas privadas.
4. **Backend:** desplegar API Node.js, JWT, autorización, Dashboard protegido y variables de entorno.
5. **Frontend:** desplegar React + Vite y Nginx; configurar la llamada a la API mediante dirección privada y HTTPS público.
6. **Firewall del host:** configurar UFW en ambos servidores, restringiendo SSH a la IP autorizada del estudiante y API a Frontend.
7. **HTTPS y headers:** emitir/configurar certificado con Certbot y verificar todos los headers solicitados.
8. **Fail2Ban:** configurar la protección de autenticación y comprobar un bloqueo controlado.
9. **AWS WAF:** asociar al Frontend, configurar reglas administradas y rate limiting; ejecutar pruebas seguras.
10. **Monitoreo y auditoría:** configurar CloudWatch y CloudTrail cuando sea posible y reunir evidencia.
11. **Pruebas integrales:** verificar comportamiento funcional, autenticación, red privada, controles perimetrales y accesos denegados.
12. **Documentación final:** actualizar diagrama, repositorios, reporte técnico, fuentes, conclusión y carpeta de evidencias.

No asumir que este orden es una autorización para crear recursos facturables. Antes de desplegar recursos de AWS con costo, indicar cuáles son, por qué se necesitan y qué costos pueden generar; pedir confirmación cuando corresponda.

## 9. Matriz de pruebas y criterios de aceptación

Marcar cada prueba como `PENDIENTE`, `APROBADA` o `FALLIDA`, e incluir fecha, método, resultado observado y evidencia.

| ID | Prueba | Resultado esperado |
|---|---|---|
| NET-01 | Revisar que las dos VPC existan y tengan CIDR no superpuestos | Dos VPC independientes y rangos no solapados |
| NET-02 | Revisar estado del VPC Peering y tablas de rutas | Peering activo y rutas correctas en ambos sentidos |
| NET-03 | Intentar acceso al Backend desde Internet | Backend no expuesto públicamente |
| NET-04 | Solicitar la API desde el Frontend | Comunicación mediante IP/ruta privada |
| NET-05 | Probar `ping 8.8.8.8` desde Backend y revisar rutas/salida | Registrar el resultado real; demostrar el aislamiento de Internet con más de una comprobación |
| SG-01 | Revisar Security Groups de ambas instancias/recursos | Solo puertos y orígenes justificados |
| UFW-01 | Revisar UFW en Frontend y Backend | Activo y con reglas restrictivas |
| UFW-02 | Acceso SSH desde IP autorizada y desde otra IP no autorizada | Permitido solo desde el origen autorizado, según la ruta de administración |
| UFW-03 | Acceso al puerto de API desde Frontend y desde un origen no autorizado | Solo Frontend autorizado puede acceder |
| AUTH-01 | Solicitar endpoint protegido sin JWT | Acceso rechazado |
| AUTH-02 | Usar JWT inválido o expirado | Acceso rechazado |
| AUTH-03 | Usar JWT válido con permisos insuficientes | Acción no autorizada rechazada |
| AUTH-04 | Acceder al Dashboard sin autenticación/autorización | Acceso rechazado |
| TLS-01 | Abrir la web por HTTPS y comprobar certificado | Certificado válido para el dominio configurado |
| TLS-02 | Revisar redirección HTTP→HTTPS, si HTTP está habilitado | Redirección correcta |
| HDR-01 | Revisar respuesta HTTP de la web | HSTS, CSP, X-Frame-Options, X-Content-Type-Options y Referrer-Policy presentes y adecuados |
| F2B-01 | Generar intentos fallidos controlados | Fail2Ban registra el evento y aplica el bloqueo configurado |
| WAF-01 | Probar una solicitud normal | Tráfico legítimo funciona |
| WAF-02 | Ejecutar pruebas seguras de reglas para SQLi/XSS | Regla correspondiente detecta/contabiliza/bloquea según configuración real |
| WAF-03 | Superar el umbral de tasa de forma controlada | Rate limiting se activa según la regla |
| MON-01 | Verificar métricas/logs configurados en CloudWatch | Evidencia observable del dato configurado |
| AUD-01 | Consultar evento pertinente en CloudTrail | Evento verificable y evidencia capturada |
| APP-01 | Flujo funcional del Frontend y API | Funcionalidad principal opera correctamente |
| DOC-01 | Revisar entregables y evidencias | Los 17 entregables están cubiertos o las limitaciones están explícitamente declaradas |

Las pruebas WAF deben realizarse únicamente sobre la aplicación y los recursos propios/autorizados del laboratorio.

## 10. Reporte técnico: contenido mínimo

El reporte final debe incluir:
1. Portada/datos de la práctica según el formato académico disponible.
2. Objetivo.
3. Descripción de la arquitectura y diagrama actualizado.
4. Tecnologías y servicios usados.
5. Configuración de VPC, peering, rutas y Security Groups.
6. Configuración de UFW y restricción de la IP administrativa.
7. Diseño de autenticación JWT y protección del Dashboard.
8. Configuración de HTTPS, Certbot y Security Headers.
9. Configuración y pruebas de Fail2Ban.
10. Configuración de AWS WAF, reglas y pruebas.
11. Monitoreo/auditoría (CloudWatch y CloudTrail, si ambos se implementan).
12. Pruebas funcionales y de seguridad, con resultados reales.
13. Limitaciones encontradas y cómo se resolvieron.
14. Fuentes de información/documentación consultada.
15. Conclusión sobre los controles logrados y las evidencias que los demuestran.

## 11. Reglas de calidad y seguridad

- No incluir MFA como requisito: está expresamente omitido por el profesor.
- No omitir UFW de ninguno de los dos servidores.
- No instalar AWS WAF en el Backend como requisito.
- No abrir SSH a `0.0.0.0/0`.
- No exponer públicamente el Backend ni su API.
- No usar credenciales, tokens o claves reales en el repositorio, capturas o reporte.
- No inventar pruebas, resultados, capturas, fuentes, URLs ni recursos.
- No marcar un requisito como terminado hasta que exista una comprobación reproducible.
- Mantener una lista de pendientes y distinguir claramente entre “configurado”, “probado” y “documentado”.
- No añadir tecnologías o servicios extra que compliquen el proyecto sin explicar su necesidad y pedir aprobación cuando afecten costo o alcance.

## 12. Datos que deben confirmarse antes del despliegue

Antigravity debe solicitar o registrar estos datos si aún no están disponibles:
- Región AWS.
- CIDR de VPC Frontend y VPC Backend.
- Sistema operativo/versión de las instancias.
- Dominio controlado por el estudiante y método de DNS/Certbot.
- IP pública del equipo desde el que se hará la presentación, en formato `/32`.
- Puertos reales de Nginx, API y cualquier base de datos.
- Repositorios Git Frontend y Backend.
- Servicio de entrada pública elegido y compatibilidad/asociación con AWS WAF.
- Permisos y presupuesto disponibles para CloudWatch, CloudTrail, WAF y otros recursos AWS.

**Fin de la especificación.** La prioridad es cumplir los requisitos originales y las aclaraciones explícitas del profesor, sin inventar datos ni rebajar controles de seguridad.
