# Apéndices

# A. Referencia de la CLI de Cloud Foundry (`cf`)

Comandos de `cf` CLI 8.19 agrupados por tarea. Los marcados con ★ son los
que se usan a diario. Los del plugin `multiapps` van al final.

## A.1 Sesión y destino

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| `cf api <url>`                               | Fija el API endpoint sin hacer login                           |
| ★ `cf login -a <url>`                        | Login con usuario y contraseña; pregunta org y space si hay varios |
| `cf login -a <url> --sso`                    | Login por navegador (single sign-on). Habitual en empresas     |
| `cf login -a <url> -u <user> -p <pass> -o <org> -s <space>` | No interactivo, para scripts                      |
| `cf logout`                                  | Cierra la sesión (borra el token de `~/.cf/config.json`)       |
| ★ `cf target`                                | Muestra endpoint, usuario, org y space actuales                |
| ★ `cf target -o <org> -s <space>`            | Cambia de org y/o space                                        |
| `cf orgs` / `cf spaces`                      | Lista orgs visibles / spaces de la org actual                  |
| `cf org <org>` / `cf space <space>`          | Detalle: dominios, cuota, spaces, apps                         |
| `cf org-quota <nombre>`                      | Límites de la org: memoria total, instancias, routes           |

## A.2 Aplicaciones

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| ★ `cf apps`                                  | Lista apps del space con estado, instancias y routes           |
| ★ `cf app <app>`                             | Detalle: estado por instancia, CPU, memoria, disco, buildpack  |
| `cf push <app> [-p <ruta>] [-m 256M] [-i 1]` | Despliega una app suelta (sin MTA)                             |
| ★ `cf start` / `cf stop` / `cf restart <app>`| Ciclo de vida. `restart` recoge variables de entorno nuevas    |
| ★ `cf restage <app>`                         | Vuelve a pasar el buildpack. **Necesario tras cambiar bindings** |
| `cf scale <app> -i 2 -m 512M -k 1G`          | Instancias, memoria, disco                                     |
| `cf delete <app> [-r]`                       | Borra la app (`-r` borra también sus routes)                   |
| `cf rename <app> <nuevo>`                    | Renombra                                                       |
| `cf restart-app-instance <app> <índice>`     | Reinicia una sola instancia                                    |
| `cf run-task <app> --command "<cmd>"`        | Ejecuta un comando puntual en un contenedor de la app          |
| `cf tasks <app>`                             | Lista tareas ejecutadas                                        |
| `cf revisions <app>` / `cf rollback <app> --version N` | Versiones desplegadas y vuelta atrás               |
| `cf get-health-check <app>` / `cf set-health-check <app> http --endpoint /health` | Tipo de health check   |

## A.3 Logs, entorno y acceso

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| ★ `cf logs <app> --recent`                   | Últimos logs guardados                                         |
| ★ `cf logs <app>`                            | Logs en vivo (Ctrl+C para salir)                               |
| ★ `cf env <app>`                             | `VCAP_SERVICES`, `VCAP_APPLICATION` y variables de usuario     |
| `cf set-env <app> <VAR> <valor>`             | Variable de usuario. Después, `cf restart`                     |
| `cf unset-env <app> <VAR>`                   | Quita la variable                                              |
| ★ `cf events <app>`                          | Quién hizo qué y cuándo                                        |
| `cf ssh <app>`                               | Shell en el contenedor                                         |
| `cf ssh <app> -c "<cmd>"`                    | Ejecuta un comando dentro y sale                               |
| `cf ssh <app> -L 30015:<host-hana>:443`      | Túnel local hacia la HANA a través de la app                   |
| `cf ssh-enabled <app>` / `cf enable-ssh <app>` | Estado y activación de SSH en la app                         |
| `cf space-ssh-allowed <space>`               | Si el space permite SSH                                        |

## A.4 Servicios

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| `cf marketplace`                             | Servicios y planes disponibles en el space (según entitlements)|
| `cf marketplace -e <servicio>`               | Planes de un servicio con descripción                          |
| ★ `cf services`                              | Instancias del space con plan, apps ligadas y estado           |
| ★ `cf service <instancia>`                   | Detalle: broker, estado de la última operación, bindings       |
| `cf create-service <servicio> <plan> <nombre> [-c params.json]` | Crea una instancia                          |
| `cf update-service <instancia> -c params.json` | Actualiza parámetros (p. ej. `xs-security.json`)             |
| `cf delete-service <instancia> -f`           | Borra (tras quitar keys y bindings)                            |
| ★ `cf create-service-key <instancia> <key>`  | Crea una service key                                           |
| `cf service-keys <instancia>`                | Lista keys                                                     |
| ★ `cf service-key <instancia> <key>`         | Muestra el JSON de credenciales                                |
| `cf delete-service-key <instancia> <key> -f` | Borra la key                                                   |
| `cf bind-service <app> <instancia>`          | Liga. Después, `cf restage`                                    |
| `cf unbind-service <app> <instancia>`        | Desliga. Después, `cf restage`                                 |
| `cf create-user-provided-service <nombre> -p '{"url":"..."}'` | Instancia "manual" con credenciales propias   |
| `cf share-service <instancia> -s <otro-space>` | Comparte una instancia con otro space                        |

## A.5 Routes y red

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| `cf routes`                                  | Routes del space y a qué app van                               |
| `cf domains`                                 | Dominios disponibles (`cfapps.us10-001…`, `apps.internal`)     |
| `cf map-route <app> <dominio> --hostname <host>` | Añade una route a una app                                  |
| `cf unmap-route <app> <dominio> --hostname <host>` | Quita la route (la app deja de ser pública)              |
| `cf delete-orphaned-routes`                  | Limpia routes sin app                                          |
| `cf add-network-policy <origen> <destino> --port 8080 --protocol tcp` | Permite tráfico interno app → app     |
| `cf network-policies`                        | Lista políticas                                                |

## A.6 Usuarios y roles de CF

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| `cf org-users <org>`                         | Usuarios por rol en la org                                     |
| `cf space-users <org> <space>`               | Usuarios por rol en el space                                   |
| `cf set-space-role <user> <org> <space> SpaceDeveloper` | Da un rol (SpaceManager, SpaceDeveloper, SpaceAuditor) |
| `cf unset-space-role <user> <org> <space> <rol>` | Lo quita                                                   |
| `cf set-org-role <user> <org> OrgManager`    | Rol de org (OrgManager, OrgAuditor)                            |

## A.7 Spaces

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| `cf create-space <nombre>`                   | Crea un space (y te hace Manager y Developer en él)            |
| `cf delete-space <nombre> -f`                | **Borra el space con todo lo que contiene**                    |
| `cf rename-space <viejo> <nuevo>`            | Renombra                                                       |

## A.8 Plugin `multiapps` (MTA)

| Comando                                      | Qué hace                                                       |
|----------------------------------------------|----------------------------------------------------------------|
| `cf install-plugin multiapps -f`             | Instala el plugin desde el repositorio CF-Community            |
| `cf plugins`                                 | Plugins instalados                                             |
| ★ `cf deploy <fichero.mtar>`                 | Despliega una MTA: instancias, apps, bindings, deployer, routes|
| `cf deploy <mtar> -e <fichero.mtaext>`       | Con extension descriptor                                       |
| `cf deploy <mtar> --version-rule ALL`        | Acepta versión igual o menor                                   |
| `cf deploy <mtar> -f`                        | Sin confirmaciones (aborta operaciones en conflicto)           |
| `cf deploy <mtar> --strategy blue-green`     | Despliegue sin corte                                           |
| `cf deploy -i <op-id> -a abort|retry|resume|monitor` | Actuar sobre una operación en curso                    |
| ★ `cf mtas`                                  | MTAs desplegadas con versión                                   |
| ★ `cf mta <id>`                              | Apps y servicios de una MTA                                    |
| `cf mta-ops`                                 | Operaciones de deploy, con ID y estado                         |
| ★ `cf dmol -i <op-id>`                       | Descarga los logs de una operación                             |
| `cf undeploy <id> [--delete-services] [--delete-service-keys] -f` | Desinstala la MTA. Con `--delete-services`, **borra datos** |
| `cf bg-deploy <mtar>`                        | Despliegue blue-green (forma antigua de `--strategy`)          |

## A.9 Trucos

```bash
cf help -a                     # todos los comandos
cf <comando> --help            # ayuda de uno
cf curl /v3/apps               # llamar a la API REST directamente
cf curl "/v3/apps?names=bookshop-srv" | jq .resources[0].guid
CF_TRACE=true cf apps          # ver las llamadas HTTP que hace la CLI
cf config --locale es-ES       # mensajes en castellano
```

El fichero `~/.cf/config.json` guarda endpoint, token y org/space actuales.
Borrarlo equivale a `cf logout` y a olvidar el target.
