# B. Referencia de la CLI de CAP (`cds`)

Comandos de `@sap/cds-dk` 10.2.1. Cada uno acepta `--help`.

## B.1 Crear y hacer crecer el proyecto

| Comando                                           | Qué hace                                                            |
|---------------------------------------------------|---------------------------------------------------------------------|
| `cds init <nombre> --add nodejs,tiny-sample`      | Proyecto Node.js con un modelo mínimo. **Sin `nodejs` no hay runtime** (cds-dk 10) |
| `cds init <nombre> --add nodejs,sample`           | Con modelo bookshop completo y UI Fiori                             |
| `cds add hana`                                    | `@cap-js/hana` y base de datos HANA en producción                   |
| `cds add xsuaa`                                   | `xs-security.json`, `@sap/xssec`, `auth: xsuaa` en producción       |
| `cds add approuter`                               | `.deploy/app-router/` con `xs-app.json` y módulo en `mta.yaml`      |
| `cds add mta`                                     | `mta.yaml` con módulos y recursos según lo que haya                 |
| `cds add destination` / `cds add connectivity`    | Servicios de destino / conectividad en `mta.yaml` y `package.json`  |
| `cds add application-logging`                     | Instancia de logs ligada a `srv`                                    |
| `cds add html5-repo` / `cds add workzone-standard`| Repositorio HTML5 / launchpad Work Zone                             |
| `cds add multitenancy`                            | Soporte multi-tenant (mtx sidecar)                                  |
| `cds add test`                                    | Carpeta `test/` con ejemplo y dependencias                          |
| `cds add data`                                    | Cabeceras CSV para todas las entidades                              |
| `cds add http`                                    | Ficheros `.http` para probar los servicios desde VS Code            |
| `cds add lint`                                    | Configura `cds lint`                                                |
| `cds add pipeline` / `cds add github-actions`     | Esqueleto de CI/CD                                                  |
| `cds add typer` / `cds add typescript`            | Tipos generados / proyecto TypeScript                               |

Varios a la vez: `cds add hana,xsuaa,approuter,mta`. Los `cds add` modifican
`package.json` y `mta.yaml` de forma idempotente; se pueden repetir.

## B.2 Ejecutar en local

| Comando                                           | Qué hace                                                            |
|---------------------------------------------------|---------------------------------------------------------------------|
| ★ `cds watch`                                     | Arranca en `:4004` con SQLite en memoria y auth mocked; reinicia al guardar |
| `cds watch --profile hybrid`                      | Con los bindings de `cds bind`                                      |
| `cds watch --port 4005`                           | Otro puerto                                                         |
| `cds watch --debug`                               | Con el inspector de Node                                            |
| `cds serve all`                                   | Como `watch`, sin recarga                                           |
| `cds serve CatalogService --port 4004`            | Solo un servicio                                                    |
| `cds mock Northwind`                              | Arranca solo un servicio externo simulado                           |
| `cds repl`                                        | REPL con `cds` cargado, para probar queries (`await SELECT.from(Books)`) |

## B.3 Modelo y compilación

| Comando                                           | Qué hace                                                            |
|---------------------------------------------------|---------------------------------------------------------------------|
| `cds compile db/schema.cds`                       | CSN (JSON) del modelo                                               |
| `cds compile srv --to edmx`                       | Metadata OData                                                      |
| `cds compile db --to sql`                         | DDL para SQLite                                                     |
| `cds compile db --to hana`                        | Artefactos `.hdbtable`                                              |
| `cds compile srv --to openapi`                    | Especificación OpenAPI                                              |
| `cds import <metadata.xml|.edmx|.json> --as cds`  | Importa un servicio externo a `srv/external/`                       |
| `cds lint`                                        | Linter del modelo                                                   |
| `cds parse <expr>`                                | Depurar expresiones CDS/CQL                                         |

## B.4 Configuración

| Comando                                           | Qué hace                                                            |
|---------------------------------------------------|---------------------------------------------------------------------|
| ★ `cds env`                                       | Configuración efectiva completa                                     |
| ★ `cds env requires.db`                           | Una clave                                                           |
| `cds env requires --profile production`           | Para un perfil                                                      |
| `cds env requires.db --profile hybrid --resolve-bindings` | Con credenciales resueltas de `cds bind`                    |
| `cds env --sources`                               | De qué ficheros sale cada valor                                     |
| `cds version`                                     | Versiones de cds, cds-dk, compiler y plugins                        |

## B.5 Build y despliegue

| Comando                                           | Qué hace                                                            |
|---------------------------------------------------|---------------------------------------------------------------------|
| `cds build --production`                          | Genera `gen/db` (HDI) y `gen/srv` (Node). Lo ejecuta `mbt build`    |
| `cds build --for hana`                            | Solo los artefactos HDI                                             |
| `cds deploy`                                      | Despliega el modelo a la base de datos configurada (SQLite por defecto) |
| `cds deploy --to sqlite:db.sqlite`                | Crea un fichero SQLite persistente para desarrollo                  |
| `cds deploy --to hana:<instancia>`                | Despliega el esquema a un contenedor HDI desde el portátil          |
| `cds deploy --to hana --dry`                      | Solo muestra qué haría                                              |
| `cds deploy --to hana:<inst> --auto-undeploy`     | Borra en HANA lo que ya no está en el modelo                        |
| ★ `cds up`                                        | `mbt build` + `cf deploy` en un paso                                |
| `cds up --overlay .deploy/prod.mtaext`            | Con extension descriptor                                            |
| `cds up --to k8s`                                 | A Kyma/Kubernetes                                                   |

## B.6 Bindings híbridos

| Comando                                           | Qué hace                                                            |
|---------------------------------------------------|---------------------------------------------------------------------|
| ★ `cds bind -2 <instancia>`                       | Liga el servicio que corresponda (por `kind`) a esa instancia del space actual, creando una key si no hay |
| `cds bind -2 <inst1>,<inst2>`                     | Varias                                                              |
| `cds bind db -2 <instancia>:<key>`                | Servicio y key concretos                                            |
| `cds bind -2 <instancia> --for test`              | En otro perfil                                                      |
| `cds bind -a <app>`                               | Liga a todos los servicios que tenga ligados una app desplegada     |
| ★ `cds bind --exec -- npm test`                   | Ejecuta un comando con `VCAP_SERVICES` de los bindings híbridos     |
| `cds bind --exec --profile test -- npx mocha`     | Con otro perfil                                                     |
| `cds bind --no-create-service-key -2 <inst>:<key>`| Sin crear key, usando una existente                                 |

## B.7 Multi-tenant (referencia)

`cds subscribe`, `cds unsubscribe`, `cds login`, `cds pull`, `cds push`:
operaciones sobre apps SaaS multi-tenant y sus extensiones. Fuera del alcance
de este libro.

## B.8 Trucos

```bash
cds help <comando>
cds completion                       # autocompletado en bash/zsh
cds w                                # abreviaturas: w=watch, b=build, d=deploy, y=bind, e=env
DEBUG=cds cds watch                  # logs internos de CAP
DEBUG=hana cds watch --profile hybrid  # SQL enviado a HANA
```
