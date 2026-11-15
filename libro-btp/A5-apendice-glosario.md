# E. Glosario

| Término                 | Definición                                                                                                   | Capítulo |
|-------------------------|--------------------------------------------------------------------------------------------------------------|----------|
| Approuter               | App Node.js de SAP que hace de puerta de entrada: login con XSUAA, sesión, reenvío a `srv` y a las UIs       | 11       |
| Binding                 | Enlace entre una app de CF y una instancia de servicio. Inyecta las credenciales en `VCAP_SERVICES`          | 6        |
| Booster                 | Asistente del cockpit que automatiza varios pasos de configuración                                           | 5        |
| Buildpack               | Receta que Cloud Foundry usa para convertir código en un contenedor ejecutable (`nodejs_buildpack`)          | 4        |
| `btp` CLI               | Línea de comandos para cuentas, entitlements y seguridad de BTP                                              | 14, C    |
| CAP                     | SAP Cloud Application Programming Model: framework para servicios de negocio con CDS + Node.js/Java          | 10       |
| CDS                     | Core Data Services: lenguaje declarativo de CAP para modelos y servicios                                     | 10       |
| `cf` CLI                | Línea de comandos de Cloud Foundry                                                                           | 4, A     |
| Cloud Connector         | Agente instalado en la red de la empresa que abre un túnel saliente hacia una subcuenta                      | 9        |
| Cloud Foundry (CF)      | PaaS de código abierto; el runtime estándar de BTP para CAP                                                  | 4        |
| Cockpit                 | Consola web de administración de BTP                                                                         | 1        |
| Contenedor HDI          | Dos esquemas + usuarios técnicos dentro de una HANA, con mecanismo de despliegue, para una app               | 7        |
| cTMS                    | Cloud Transport Management: mueve MTAs entre subcuentas con aprobación                                       | 14       |
| Cuenta global           | El contrato con SAP; raíz del árbol de cuentas                                                               | 2        |
| Cuota (quota)           | Cuánto de un entitlement; también límites de la org de CF (memoria, instancias)                              | 3        |
| `db-deployer`           | App efímera (módulo `hdb`) que pasa los artefactos HDI a la base de datos y termina                          | 7, 11    |
| Destination             | Conexión con nombre a un sistema externo (URL + autenticación), gestionada en la subcuenta                   | 9        |
| Directorio              | Carpeta para agrupar subcuentas dentro de la cuenta global                                                   | 2        |
| Droplet                 | Resultado del staging: la imagen ejecutable de la app                                                        | 4        |
| Entitlement             | Derecho a usar un servicio con un plan en una subcuenta                                                      | 3        |
| HANA Cloud Central      | Aplicación (suscripción) para administrar instancias de SAP HANA Cloud                                       | 7        |
| HDI                     | HANA Deployment Infrastructure: esquemas aislados + despliegue declarativo de artefactos                     | 7        |
| Hyperscaler             | Proveedor de infraestructura bajo BTP: AWS, Azure, GCP, Alibaba                                              | 1        |
| IAS                     | SAP Cloud Identity Services, Identity Authentication: IdP corporativo que las empresas conectan a BTP        | 8        |
| IdP                     | Proveedor de identidad: responde "¿quién eres?"                                                              | 8        |
| Instance mapping        | Hace visible una instancia de HANA Cloud a una org/space de CF para que se creen contenedores               | 7        |
| Instancia (de app)      | Una copia de la app corriendo en CF (`cf scale -i`)                                                          | 4        |
| Instancia (de servicio) | Recurso creado a partir de un servicio y un plan del catálogo                                                | 5        |
| Instancia HANA Cloud    | El servidor de base de datos entero, uno por subcuenta                                                       | 7        |
| JWT                     | Token firmado que XSUAA emite; lleva usuario, tenant (`zid`) y scopes                                        | 6, 8     |
| Landscape               | Instalación concreta de CF en una región (`us10-001`)                                                        | 3        |
| Modo híbrido            | Ejecutar CAP en el portátil con servicios reales de BTP vía `cds bind`                                       | 12       |
| MTA / `.mtar`           | Multi-Target Application: `mta.yaml` describe apps y servicios; `.mtar` los empaqueta para `cf deploy`       | 11       |
| `.mtaext`               | Extension descriptor: sobrescribe parámetros del `mta.yaml` por entorno                                      | 14       |
| `mbt`                   | Cloud MTA Build Tool: construye el `.mtar`                                                                   | 11       |
| Org                     | Contenedor de CF; una por subcuenta                                                                          | 2        |
| Perfil (CAP)            | Conjunto de configuración por entorno: `development`, `hybrid`, `production`                                 | 10       |
| Plan                    | Variante de un servicio: `lite`, `application`, `hdi-shared`                                                 | 5        |
| Región                  | Centro de datos + proveedor donde vive una subcuenta (`eu10`, `us10`)                                        | 3        |
| Role collection         | Conjunto de roles que se asigna a usuarios o grupos. La unidad de asignación                                 | 8        |
| Role template / Role    | Declarado en `xs-security.json`; se convierte en rol al desplegar la instancia XSUAA                         | 8        |
| Route                   | URL pública asignada a una app de CF                                                                         | 4        |
| Scope                   | Permiso atómico definido por la app en `xs-security.json`; viaja en el JWT                                   | 8        |
| Service broker          | Componente que crea y gestiona instancias de un servicio                                                     | 5        |
| Service key             | Credenciales de una instancia para usarla fuera de CF                                                        | 6        |
| Space                   | Subdivisión de la org donde viven apps e instancias                                                          | 2        |
| Space Developer         | Rol de CF necesario para desplegar en un space                                                               | 4, 8     |
| Staging                 | Fase en que el buildpack construye el droplet                                                                | 4        |
| Subcuenta               | Unidad de aislamiento de BTP: región, usuarios, roles, servicios, entornos                                   | 2        |
| Subdominio              | Identificador de la subcuenta que aparece en URLs y tokens (`7b6c2113trial`)                                 | 3        |
| Suscripción             | Acceso a una aplicación SaaS de SAP para personas; se controla con role collections                          | 5        |
| Tenant                  | Inquilino de un servicio multi-tenant; en BTP, normalmente la subcuenta                                      | 1, 6     |
| Twelve-factor           | Reglas (config en entorno, logs a stdout, sin estado en disco) que CF asume y CAP cumple                     | 1        |
| `VCAP_SERVICES`         | Variable de entorno con las credenciales de todos los servicios ligados a una app                            | 6        |
| XSUAA                   | Servicio de autorización OAuth2 de BTP: emite y valida JWT con scopes                                        | 8        |
| `xs-app.json`           | Configuración de rutas del approuter                                                                         | 11       |
| `xs-security.json`      | Scopes, role templates y role collections de la app; parámetros de la instancia XSUAA                        | 8        |
