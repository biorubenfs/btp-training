# D. Recetario: tarea → cockpit → CLI

Las tareas más frecuentes, con su ruta en el cockpit y el comando
equivalente. Para consultar, no para leer de principio a fin.

## D.1 Orientarse

| Quiero…                                  | Cockpit                                                        | CLI                                                      |
|------------------------------------------|----------------------------------------------------------------|----------------------------------------------------------|
| Saber dónde estoy                        | Ruta de navegación superior                                    | `cf target` · `btp --info`                               |
| Ver el API endpoint                      | Subcuenta › Visión general                                     | `cf api`                                                 |
| Ver la región y el subdominio            | Subcuenta › Visión general                                     | `btp get accounts/subaccount <id>`                       |
| Ver los spaces                           | Subcuenta › Cloud Foundry › Espacios                           | `cf spaces`                                              |
| Cambiar de space                         | Cloud Foundry › Espacios › (clic)                              | `cf target -s <space>`                                   |
| Ver qué servicios puedo usar             | Subcuenta › Derechos                                           | `cf marketplace` · `btp list accounts/entitlement`       |

## D.2 Servicios

| Quiero…                                  | Cockpit                                                        | CLI                                                      |
|------------------------------------------|----------------------------------------------------------------|----------------------------------------------------------|
| Ver instancias y suscripciones           | Subcuenta › Servicios › Instancias y suscripciones             | `cf services` (solo instancias del space)                |
| Crear una instancia                      | Servicios › Marketplace › (servicio) › Crear                   | `cf create-service <svc> <plan> <nombre> [-c params.json]` |
| Ver el estado de una instancia           | Instancias y suscripciones › (instancia)                       | `cf service <nombre>`                                    |
| Crear una service key                    | (instancia) › ⋮ › Crear clave de servicio                      | `cf create-service-key <inst> <key>`                     |
| Ver las credenciales                     | (instancia) › Claves › (key) › Ver                             | `cf service-key <inst> <key>`                            |
| Borrar una key                           | (key) › ⋮ › Eliminar                                           | `cf delete-service-key <inst> <key> -f`                  |
| Ligar instancia a app                    | Aplicaciones › (app) › Enlaces de servicio › Enlazar           | `cf bind-service <app> <inst>` + `cf restage <app>`      |
| Borrar una instancia                     | (instancia) › ⋮ › Eliminar (tras keys y bindings)              | `cf delete-service <inst> -f`                            |
| Abrir una app suscrita                   | Instancias y suscripciones › (suscripción) › Ir a la aplicación | —                                                       |

## D.3 Aplicaciones

| Quiero…                                  | Cockpit                                                        | CLI                                                      |
|------------------------------------------|----------------------------------------------------------------|----------------------------------------------------------|
| Ver las apps y su estado                 | Cloud Foundry › Espacios › dev › Aplicaciones                  | `cf apps`                                                |
| Ver detalle de una app                   | Aplicaciones › (app) › Visión general                          | `cf app <app>`                                           |
| Ver la URL                               | (app) › Rutas                                                  | `cf app <app>` (campo routes) · `cf routes`              |
| Ver logs                                 | (app) › Registros                                              | `cf logs <app> --recent` · `cf logs <app>`               |
| Ver variables de entorno                 | (app) › Variables de entorno                                   | `cf env <app>`                                           |
| Ver bindings                             | (app) › Enlaces de servicio                                    | `cf app <app>` · `cf services` (columna bound apps)      |
| Parar / arrancar / reiniciar             | (app) › botones                                                | `cf stop|start|restart <app>`                            |
| Escalar                                  | (app) › Visión general › Instancias / Memoria                  | `cf scale <app> -i N -m 512M`                            |
| Ver quién hizo qué                       | (app) › Eventos                                                | `cf events <app>`                                        |
| Entrar en el contenedor                  | —                                                              | `cf ssh <app>`                                           |
| Desplegar una MTA                        | —                                                              | `mbt build && cf deploy mta_archives/*.mtar` · `cds up`  |
| Ver MTAs desplegadas                     | —                                                              | `cf mtas` · `cf mta <id>`                                |
| Ver logs de un deploy fallido            | —                                                              | `cf mta-ops` · `cf dmol -i <op>`                         |
| Desinstalar una MTA                      | —                                                              | `cf undeploy <id> [--delete-services] -f`                |

## D.4 SAP HANA Cloud

| Quiero…                                  | Cockpit                                                        | CLI                                                      |
|------------------------------------------|----------------------------------------------------------------|----------------------------------------------------------|
| Abrir HANA Cloud Central                 | Instancias y suscripciones › SAP HANA Cloud › Ir a la aplicación | —                                                      |
| Arrancar / parar la instancia            | HANA Cloud Central › (instancia) › ⋮ › Start / Stop            | — (hay API REST, fuera de alcance)                       |
| Ver / cambiar el instance mapping        | HANA Cloud Central › (instancia) › ⋮ › Manage Configuration    | —                                                        |
| Cambiar IPs permitidas                   | HANA Cloud Central › (instancia) › ⋮ › Manage Configuration › Connections | —                                             |
| Abrir el Database Explorer               | HANA Cloud Central › (instancia) › ⋮ › Open in SAP HANA Database Explorer | —                                             |
| Ver los contenedores HDI de una app      | Instancias y suscripciones (servicio `hana`, plan `hdi-shared`) | `cf services`                                           |
| Conectar al contenedor desde fuera       | (instancia hdi) › Crear clave › usar en Database Explorer      | `cf create-service-key bookshop-db k` · `cds bind -2 bookshop-db` |
| Desplegar el esquema sin redesplegar srv | —                                                              | `cds deploy --to hana:bookshop-db`                       |

## D.5 Seguridad

| Quiero…                                  | Cockpit                                                        | CLI                                                      |
|------------------------------------------|----------------------------------------------------------------|----------------------------------------------------------|
| Ver los roles de mi app                  | Subcuenta › Seguridad › Roles (filtrar por app)                | `btp list security/role`                                 |
| Crear una role collection                | Seguridad › Colecciones de roles › Crear                       | `btp create security/role-collection <nombre>`           |
| Añadir un rol a la colección             | (colección) › Editar › Añadir rol                              | `btp add security/role <rol> --to-role-collection <rc> --of-app <app> --of-role-template <tpl>` |
| Asignar la colección a un usuario        | Seguridad › Usuarios › (usuario) › Asignar colección de roles  | `btp assign security/role-collection <rc> --to-user <mail> --of-idp sap.default` |
| Ver qué colecciones tengo                | Seguridad › Usuarios › (yo)                                    | `btp get security/user <mail> --of-idp sap.default`      |
| Ver los IdPs                             | Seguridad › Configuración de confianza                         | `btp list security/trust`                                |
| Dar permiso de despliegue a alguien      | Cloud Foundry › Espacios › dev › Miembros › Añadir             | `cf set-space-role <mail> <org> dev SpaceDeveloper`      |
| Ver quién puede desplegar                | Espacios › dev › Miembros                                      | `cf space-users <org> dev`                               |

## D.6 Conectividad

| Quiero…                                  | Cockpit                                                        | CLI / API                                                |
|------------------------------------------|----------------------------------------------------------------|----------------------------------------------------------|
| Crear una destination                    | Subcuenta › Conectividad › Destinos › Nuevo destino            | API REST del Destination Service (POST `/subaccountDestinations`) |
| Ver una destination resuelta             | Destinos › (destination)                                       | `curl -H "Authorization: Bearer $T" $URI/destination-configuration/v1/destinations/<NOMBRE>` |
| Probar la red hasta el host              | Destinos › (destination) › Comprobar conexión                  | —                                                        |
| Ver el Cloud Connector                   | Subcuenta › Conectividad › Cloud Connectors                    | —                                                        |

## D.7 Desarrollo CAP

| Quiero…                                  | Comando                                                        |
|------------------------------------------|----------------------------------------------------------------|
| Proyecto nuevo                           | `cds init <nombre> --add nodejs,tiny-sample && cd <nombre> && npm i` |
| Arrancar en local                        | `cds watch`                                                    |
| Base local persistente (SQLite en fichero) | `[development]` → `db.sqlite` en `cds.requires` + `cds deploy --to sqlite:db.sqlite` (10.6) |
| Preparar para BTP                        | `cds add hana,xsuaa,approuter,mta && npm i`                    |
| Ver configuración efectiva en producción | `cds env requires --profile production`                        |
| Construir                                | `mbt build`                                                    |
| Desplegar                                | `cf deploy mta_archives/<id>_<ver>.mtar` · `cds up`            |
| Modo híbrido                             | `cds bind -2 <db>,<auth> && cds watch --profile hybrid`        |
| Tests contra la HANA de dev              | `cds bind --exec -- npm test`                                  |
| Importar un servicio externo             | `cds import <metadata.xml> --as cds`                           |
| Ver el SQL que iría a HANA               | `cds compile db --to hana`                                     |

## D.8 Cada mañana en el trial

```bash
# 1. ¿Está la HANA arrancada?  → HANA Cloud Central (no hay CLI)
# 2. Sesión
cf login -a https://api.cf.us10-001.hana.ondemand.com   # si caducó
cf target
# 3. Estado
cf apps && cf services
```
