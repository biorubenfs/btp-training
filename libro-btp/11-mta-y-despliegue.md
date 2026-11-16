# 11. MTA y el despliegue en Cloud Foundry

**Objetivo del capítulo.** Entender el `mta.yaml` línea a línea, construir el
`.mtar`, desplegarlo y saber qué ha pasado en cada paso. Al terminar, bookshop
está corriendo en el space `dev` con HANA y XSUAA.

## 11.1 Qué es una MTA

Una **Multi-Target Application** (MTA) es un paquete que describe **varias
apps y los servicios que necesitan** para desplegarse juntos y en orden. El
descriptor es `mta.yaml`; el paquete construido es un `.mtar` (un zip). Lo
despliega el *deploy service* de Cloud Foundry, al que se habla con el plugin
`multiapps` (`cf deploy`).

```
  mta.yaml ──mbt build──▶ mta_archives/bookshop_1.0.0.mtar ──cf deploy──▶ deploy service
                                                                              │
                                              ┌───────────────────────────────┤
                                              ▼                               ▼
                                     resources → instancias          modules → apps
                                     bookshop-db  (hana)              bookshop-srv
                                     bookshop-auth (xsuaa)            bookshop-db-deployer
                                                                      bookshop (approuter)
                                              └───────── requires = bindings ─┘
```

> **Analogía.** `mta.yaml` es un `docker-compose.yml` o una plantilla de
> CloudFormation: declara servicios, apps y dependencias, y una herramienta
> hace que la realidad coincida con lo declarado. `cf push` sería `docker run`
> a mano, app por app.

### Anatomía de un `mta.yaml`

Cualquier `mta.yaml`, sea de CAP, de Java o de una UI5, tiene la misma
forma: una cabecera, una lista de **módulos** y una lista de **recursos**.
Todo lo demás son detalles dentro de esas tres partes.

```yaml
_schema-version: 3.3.0        # versión del formato del fichero
ID: mi-app                    # identificador de la MTA en el space
version: 1.0.0                # versión de la MTA (semver)
description: "..."
parameters:                   # ajustes globales para el deploy service
  enable-parallel-deployments: true
build-parameters:             # qué ejecuta mbt build antes de empaquetar
  before-all: [...]
modules:                      # lo que se despliega como apps
  - name: ...
resources:                    # lo que se crea como instancias de servicio
  - name: ...
```

| Sección            | Qué define                                                                  | Quién lo lee                      |
|--------------------|-----------------------------------------------------------------------------|-----------------------------------|
| Cabecera (`ID`, `version`) | La identidad de la MTA. Con `ID` el deploy service sabe si es un despliegue nuevo o una actualización | `cf deploy`             |
| `parameters`       | Opciones globales del despliegue (paralelismo, borrado de servicios...)     | `cf deploy`                       |
| `build-parameters` | Comandos previos al empaquetado                                             | `mbt build`                       |
| `modules`          | Una entrada por app. Cada una: de dónde sale el código, cómo se construye, con qué se liga, qué ofrece | `mbt build` (empaqueta) y `cf deploy` (crea la app) |
| `resources`        | Una entrada por instancia de servicio o por cosa externa que las apps necesitan | `cf deploy`                   |

**Un módulo** tiene siempre estas claves, y conviene distinguir dos que se
confunden: `parameters` son instrucciones para Cloud Foundry (memoria, rutas,
buildpack), `properties` son variables de entorno para la app.

```yaml
modules:
  - name: mi-srv
    type: nodejs                   # cómo desplegarlo: nodejs, java, hdb, approuter.nodejs, html5...
    path: gen/srv                  # qué carpeta se sube
    build-parameters:
      builder: npm-ci              # cómo construir esa carpeta antes de subirla
      ignore: ["node_modules/"]
    parameters:                    # → cf push
      memory: 256M
      disk-quota: 512M
      instances: 1
      buildpack: nodejs_buildpack
      routes:
        - route: mi-srv.cfapps.us10-001.hana.ondemand.com
    properties:                    # → variables de entorno de la app
      LOG_LEVEL: info
    requires:                      # → bindings (si apuntan a un recurso)
      - name: mi-db                #   o datos de otro módulo (si apuntan a un provides)
    provides:                      # → datos que otros módulos pueden pedir
      - name: srv-api
        properties:
          srv-url: ${default-url}
```

| `type` del módulo  | Qué es                                                                                         |
|--------------------|------------------------------------------------------------------------------------------------|
| `nodejs`           | App Node con el buildpack de Node. CAP, Express, lo que sea                                     |
| `java`             | App Java (Spring Boot, CAP Java) con el buildpack de Java                                       |
| `hdb`              | App de un solo uso que ejecuta `@sap/hdi-deploy` contra un contenedor HDI y se para            |
| `approuter.nodejs` | App Node preconfigurada como approuter                                                         |
| `html5`            | Una app UI5/Fiori. Normalmente no se despliega como app sino que se sube al HTML5 Application Repository mediante un módulo `com.sap.application.content` |

**Un recurso** se describe con un `type` y unos `parameters` que son los
mismos que le darías a `cf create-service`:

```yaml
resources:
  - name: mi-db
    type: com.sap.xs.hdi-container       # atajo para hana / hdi-shared
  - name: mi-auth
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: ./xs-security.json           # parámetros de creación desde fichero
  - name: mi-dest
    type: org.cloudfoundry.managed-service
    parameters:
      service: destination
      service-plan: lite
      config:                            # parámetros de creación en línea
        init_data:
          subaccount:
            existing_destinations_policy: ignore
  - name: dest-ya-creada
    type: org.cloudfoundry.existing-service   # NO la crea: liga una que ya existe
    parameters:
      service-name: dest-dev
```

| `type` del recurso                   | Qué hace el deploy service                                                        |
|--------------------------------------|-----------------------------------------------------------------------------------|
| `org.cloudfoundry.managed-service`   | `cf create-service <service> <plan>` con los `parameters`. Si ya existe, la actualiza |
| `org.cloudfoundry.existing-service`  | No crea nada; solo permite hacer `requires` sobre una instancia creada a mano (la `dest-dev` del capítulo 6, por ejemplo) |
| `com.sap.xs.hdi-container`           | Azúcar para `managed-service` con `hana` / `hdi-shared`                           |
| `org.cloudfoundry.user-provided-service` | `cf create-user-provided-service`: credenciales que pones tú, para sistemas fuera de BTP |
| `configuration`                      | Lee datos publicados por **otra MTA** del mismo space (`provides` con `public: true`) |

**Dos tipos de marcador** aparecen por todo el fichero y son la parte que
más cuesta leer:

| Marcador           | Quién lo resuelve                 | Ejemplo                                                        |
|--------------------|-----------------------------------|----------------------------------------------------------------|
| `${...}`           | El deploy service, con datos del entorno | `${org}`, `${space}`, `${default-url}` (la URL que CF asigna a la app), `${default-uri}`, `${protocol}` |
| `~{...}`           | El deploy service, con datos de **otro módulo o recurso** que esté en `requires` | `~{srv-url}` toma la propiedad `srv-url` del `provides` llamado `srv-api` |

Y un `requires` puede llevar `group` y `properties`: entonces no es un
binding sino una **variable de entorno compuesta**. Es como el approuter
recibe la URL de `srv`:

```yaml
    requires:
      - name: srv-api
        group: destinations          # todas las entradas con este group van a una
        properties:                  # única variable de entorno llamada destinations
          name: srv-api
          url: ~{srv-url}
          forwardAuthToken: true
```

Resultado en la app: `destinations=[{"name":"srv-api","url":"https://...","forwardAuthToken":true}]`.

> **Analogía.** `modules` son los `services` de un `docker-compose.yml`
> que tienen `build:`; `resources` son los que tienen `image:` de algo
> externo (postgres, keycloak) y los volúmenes; `requires` son los
> `depends_on` más las `environment` que les pasas; `${}` y `~{}` son la
> interpolación de variables. La diferencia es que aquí el "compose" lo
> ejecuta un servicio de la plataforma, no tu máquina.

Lo que cambia entre entornos (memoria en prod, otra ruta, otro plan) no se
toca en el `mta.yaml`: se pone en un `.mtaext`, un fichero de extensión que
se aplica encima con `cf deploy -e`. Lo verás en el capítulo 14.

## 11.2 Preparar el proyecto: `cds add`

Antes de que exista un `mta.yaml` hay que decirle a cds-dk qué servicios va
a usar la app en BTP. Se hace con un solo comando, que añade cuatro *facets*
al proyecto del capítulo 10:

```bash
cd ~/projects/btp-training-projects/bookshop-cap
cds add hana,xsuaa,approuter,mta
git status
```

```
Adding facet: mta
Adding facet: xsuaa
Adding facet: hana
Adding facet: approuter

Successfully added features to your project
```

```
Changes not staged for commit:
        modified:   package.json

Untracked files:
        .deploy/
        mta.yaml
        xs-security.json
```

El orden en que las aplica no es el que escribes: `mta` va primero porque las
otras tres añaden sus módulos y recursos al `mta.yaml`. Cada facet deja algo
concreto en el proyecto:

| Facet       | Qué toca                                                                 | Qué representa                                                                    | Para qué sirve                                                                 |
|-------------|--------------------------------------------------------------------------|-----------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `hana`      | `@cap-js/hana` en `dependencies`                                         | El *driver* de HANA para CAP. En local sigue mandando `@cap-js/sqlite`            | Con el perfil `production`, `cds build` genera `gen/db` (artefactos HDI) y `srv` se conecta a HANA leyendo `VCAP_SERVICES` |
| `xsuaa`     | `@sap/xssec` en `dependencies`; `xs-security.json`; `cds.requires.[production].auth: xsuaa` en `package.json` | El contrato con el servicio de autenticación: scopes, atributos y plantillas de rol | En producción CAP valida el JWT que le llega con `xssec`; en local sigue `mocked`. El capítulo 8 rellena el fichero |
| `approuter` | `.deploy/app-router/` con `package.json`, `xs-app.json` y `default-env.json` | Una app Node aparte, la puerta de entrada (11.4)                                  | Hace el login contra XSUAA y reenvía al `srv` con el token                     |
| `mta`       | `mta.yaml`; `@sap/cds-dk` en `devDependencies`                           | El descriptor de despliegue: qué apps, qué instancias, qué bindings               | Es lo que `mbt build` empaqueta y `cf deploy` ejecuta. `cds-dk` va como dependencia porque el `before-all` del `mta.yaml` lanza `npx cds build` tras un `npm ci` limpio |

El `diff` del `package.json` resume lo que ha cambiado:

```diff
   "dependencies": {
-    "@sap/cds": "^10"
+    "@cap-js/hana": "^3",
+    "@sap/cds": "^10",
+    "@sap/xssec": "^4"
   },
   "devDependencies": {
     ...
+    "@sap/cds-dk": "^10",
     ...
   },
+  "cds": {
+    "requires": {
+      "[production]": {
+        "auth": "xsuaa"
+      }
+    }
+  }
```

La entrada `cds.requires.[production]` es la pieza que une los dos mundos:
el mismo código arranca con SQLite y auth `mocked` en tu máquina y con HANA y
XSUAA en BTP. El perfil `production` se activa con `NODE_ENV=production`,
que el buildpack de Node pone por defecto. Para la base de datos no hace
falta entrada: `@cap-js/hana` se registra solo para ese perfil al estar
instalado.

`xs-security.json` nace vacío. Es el fichero que el recurso `bookshop-auth`
del `mta.yaml` pasa a XSUAA al crear la instancia:

```json
{
  "scopes": [],
  "attributes": [],
  "role-templates": []
}
```

> **Trampa.** `cds add` escribe el `package.json` pero **no instala nada**:
> tras el comando, `node_modules/@cap-js/` sigue sin `hana`. Hay que lanzar
> `npm install` antes de construir. Sin él, `cds build --production` no
> genera el bloque `for: 'hana'` y `gen/db` sale vacío, y además el
> `package-lock.json` no coincide con el `package.json`, con lo que el
> `npm ci` del `before-all` falla.

> **Trampa.** Si en el capítulo 10 pusiste `default-env.json` en el
> `.gitignore`, esa entrada vale a cualquier profundidad y oculta también
> `.deploy/app-router/default-env.json`. Está bien así: ese fichero solo sirve
> para probar el approuter en local contra `cds watch`; en BTP la destination
> `srv-api` la inyecta el `mta.yaml`. El resto de `.deploy/` sí va a git.

Con eso el proyecto tiene todo lo que el `mta.yaml` referencia. Un commit por
el paso:

```bash
npm install
git add package.json package-lock.json mta.yaml xs-security.json .deploy
git commit -m "cds add hana,xsuaa,approuter,mta: descriptor MTA, approuter y auth xsuaa en producción"
```

## 11.3 El `mta.yaml` de bookshop, línea a línea

Es el que acaba de generar `cds add` con cds-dk 10.2.1, sin tocar (el real
lleva además dos comentarios junto a `srv-api`, omitidos aquí):

### Quién es quién

Antes de las claves, las piezas. El fichero declara cinco cosas: tres
**módulos**, que acabarán siendo apps de Cloud Foundry (cada una un proceso
con su `cf push` implícito), y dos **recursos**, que acabarán siendo
instancias de servicio (lo que hasta ahora creabas con `cf create-service`).
Los nombres son los que cds-dk deriva del `ID` de la MTA.

| Nombre                 | Qué es        | Qué hay dentro                                                                                   | Qué hace en producción                                                                                     | Después del deploy se ve en          |
|------------------------|---------------|--------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|--------------------------------------|
| `bookshop-srv`         | Módulo (app)  | `gen/srv`: tu servicio CAP compilado, `csn.json`, `package.json` con las dependencias de runtime | El servidor Node que has estado viendo con `cds-tsx watch`, pero con HANA detrás y validando JWT. Expone `/odata/v4/catalog`. Corre siempre | `cf apps`, *started*                 |
| `bookshop-db-deployer` | Módulo (app)  | `gen/db`: los `.hdbtable`, los CSV y un `package.json` con `@sap/hdi-deploy`                     | Arranca, conecta al contenedor HDI, crea o actualiza las tablas, carga los CSV y **termina**. Es el equivalente a ejecutar las migraciones | `cf apps`, *stopped*, 0/1 instancias |
| `bookshop`             | Módulo (app)  | `.deploy/app-router`: el approuter de SAP, `xs-app.json` con las rutas                          | La puerta de entrada: redirige al login de XSUAA, guarda la sesión y reenvía cada petición a `srv` con el token. Es la única URL que das a un usuario | `cf apps`, *started*, con route      |
| `bookshop-auth`        | Recurso (instancia) | Una instancia de `xsuaa`, plan `application`, creada con `xs-security.json`                | El servidor de identidad de la app: emite los JWT y conoce sus scopes y roles. No ejecuta tu código; es un servicio gestionado por SAP | `cf services`, *Instancias y suscripciones* |
| `bookshop-db`          | Recurso (instancia) | Una instancia de `hana`, plan `hdi-shared`: un contenedor HDI como `test-hdi` del capítulo 7 | El esquema de bookshop dentro de `hana-trial`, con sus usuarios técnicos. Tampoco ejecuta código: es un sitio donde guardar tablas | `cf services`, Database Explorer     |

En ejecución quedan así. El deployer ya ha terminado y no está; lo que corre
son dos apps y lo que las sostiene son dos servicios:

```
  navegador ──▶ bookshop (approuter) ──▶ bookshop-srv ──▶ bookshop-db (HDI en hana-trial)
                     │                        │
                     └──── login / JWT ───────┴──────▶ bookshop-auth (XSUAA)

  bookshop-db-deployer ──▶ bookshop-db      (una sola vez, al desplegar; luego stopped)
```

> **Analogía.** En un `docker-compose.yml`: `srv` y el approuter son dos
> `services` con imagen propia que se quedan corriendo; el deployer es un
> contenedor de migraciones con `restart: "no"`; `bookshop-db` es el volumen
> más la base de datos; `bookshop-auth` sería un Keycloak que no gestionas
> tú. En AWS: dos tareas ECS, un job de una ejecución, una base RDS y un
> Cognito.

Lo que une cada pieza con las demás son los `requires`: `srv` requiere la
base y la XSUAA (dos bindings), el deployer solo la base, el approuter la
XSUAA y la URL de `srv`. En tu proyecto real que usaba destinations, aquella
instancia `destination` era un recurso más y el `requires` en `srv` el
binding que la hacía aparecer en `VCAP_SERVICES`.


```yaml
_schema-version: 3.3.0
ID: bookshop
version: 1.0.0
description: "A simple CAP project."
parameters:
  enable-parallel-deployments: true
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm ci
        - npx cds build --production
```

| Clave                         | Significado                                                                                   |
|-------------------------------|-----------------------------------------------------------------------------------------------|
| `ID`                          | Identificador de la MTA en el space. `cf mtas` lo lista. Dos MTAs con el mismo ID se pisan     |
| `version`                     | Por defecto, `cf deploy` solo acepta versiones iguales o mayores a la desplegada              |
| `enable-parallel-deployments` | Despliega módulos en paralelo cuando no dependen entre sí                                     |
| `build-parameters.before-all` | Lo que `mbt build` ejecuta antes de empaquetar: instalar y `cds build --production`, que llena `gen/` |

```yaml
modules:
  - name: bookshop-srv
    type: nodejs
    path: gen/srv
    parameters:
      instances: 1
      buildpack: nodejs_buildpack
    build-parameters:
      builder: npm-ci
    provides:
      - name: srv-api
        properties:
          srv-url: ${default-url}
    requires:
      - name: bookshop-auth
      - name: bookshop-db
```

| Clave        | Significado                                                                                      |
|--------------|--------------------------------------------------------------------------------------------------|
| `type: nodejs` | Se desplegará como app Node con el buildpack indicado                                         |
| `path: gen/srv` | Lo que se sube es la salida de `cds build`, no `srv/`                                         |
| `instances`, `memory` | Parámetros de `cf push`. Aquí se ajusta la memoria (añade `memory: 256M` si la cuota aprieta) |
| `provides: srv-api` | Publica su URL con el nombre `srv-api` para que otros módulos la usen                      |
| `requires`   | **Bindings.** Se ligará a las instancias `bookshop-auth` y `bookshop-db`                         |

```yaml
  - name: bookshop-db-deployer
    type: hdb
    path: gen/db
    parameters:
      buildpack: nodejs_buildpack
    requires:
      - name: bookshop-db
```

El deployer: `type: hdb` le dice al deploy service "arranca esta app, espera
a que termine y no la mantengas corriendo". Solo necesita el contenedor HDI.
Es la app que verás en *stopped* (capítulo 7).

```yaml
  - name: bookshop
    type: approuter.nodejs
    path: .deploy/app-router
    parameters:
      keep-existing-routes: true
      disk-quota: 256M
      memory: 256M
    requires:
      - name: srv-api
        group: destinations
        properties:
          name: srv-api
          url: ~{srv-url}
          forwardAuthToken: true
      - name: bookshop-auth
    provides:
      - name: app-api
        properties:
          app-protocol: ${protocol}
          app-uri: ${default-uri}
```

El approuter: la puerta de entrada. Requiere `srv-api` (la URL de `srv`, que
inyecta como destination de entorno con `forwardAuthToken`) y la XSUAA (para
el login). Publica su propia URL como `app-api` para que la XSUAA la acepte
como redirect.

```yaml
resources:
  - name: bookshop-auth
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: ./xs-security.json
      config:
        xsappname: bookshop-${org}-${space}
        tenant-mode: dedicated
        oauth2-configuration:
          credential-types:
            - "binding-secret"
            - "x509"
          redirect-uris:
            - https://*~{app-api/app-uri}/**
    requires:
      - name: app-api
  - name: bookshop-db
    type: com.sap.xs.hdi-container
    parameters:
      service: hana
      service-plan: hdi-shared
```

| Clave                      | Significado                                                                                     |
|----------------------------|-------------------------------------------------------------------------------------------------|
| `type: org.cloudfoundry.managed-service` | Una instancia de servicio normal. `service` y `service-plan` son los de `cf marketplace` |
| `path: ./xs-security.json` | Parámetros de creación: el fichero de seguridad del capítulo 8                                 |
| `xsappname: bookshop-${org}-${space}` | Nombre único de la app en XSUAA. Por eso en Seguridad › Roles aparece `bookshop-7b6c2113trial-dev` |
| `redirect-uris`            | Solo acepta volver a la URL del approuter tras el login. Evita *open redirects*                 |
| `type: com.sap.xs.hdi-container` | Azúcar para `hana` / `hdi-shared`: el contenedor HDI                                     |

> **Idea clave.** `modules` → apps. `resources` → instancias. `requires` →
> bindings. `provides`/`~{}` → una app le pasa su URL a otra. Con esas cuatro
> ideas se lee cualquier `mta.yaml`.

## 11.4 El approuter

El approuter es una app Node.js de SAP que hace de puerta de entrada:

```
  navegador ──▶ bookshop (approuter) ──▶ bookshop-srv
                 │ login con XSUAA        (sin route pública idealmente)
                 │ sesión + cookie
                 │ reenvía con Bearer
                 └ sirve UIs estáticas
```

Lo que hay en `.deploy/app-router/`:

```json
// package.json
{
  "name": "approuter",
  "dependencies": { "@sap/approuter": "^23.0.0" },
  "scripts": { "start": "node node_modules/@sap/approuter/approuter.js" }
}
```

```json
// xs-app.json: qué rutas reenvía y a dónde
{
  "routes": [
    {
      "source": "^/(.*)$",
      "target": "$1",
      "destination": "srv-api",
      "csrfProtection": true
    }
  ]
}
```

La `destination: srv-api` no es una destination de la subcuenta: es la que el
`mta.yaml` inyectó como variable de entorno `destinations` del approuter con
la URL de `srv`. Para exigir login en todo, añade `"authenticationType": "xsuaa"`
a la ruta; sin ello, el approuter pasa las peticiones anónimas y `srv`
responde 401 si tiene `@requires`.

```json
// default-env.json: para probar el approuter en local contra cds watch
{
  "destinations": [
    { "name": "srv-api", "url": "http://localhost:4004", "forwardAuthToken": true }
  ]
}
```

## 11.5 Construir

```bash
mbt build
```

```
[2026-11-14 18:00:01]  INFO Cloud MTA Build Tool version 1.2.51
[2026-11-14 18:00:01]  INFO generating the "Makefile_20261114180001.mta" file...
[2026-11-14 18:00:01]  INFO done
[2026-11-14 18:00:01]  INFO executing the "make -f Makefile_20261114180001.mta p=cf mtar= strict=true mode=" command...
[2026-11-14 18:00:01]  INFO validating the MTA project
[2026-11-14 18:00:01]  INFO running the "before-all" build...
[2026-11-14 18:00:01]  INFO executing the "npm ci" command...
...
[2026-11-14 18:00:20]  INFO executing the "npx cds build --production" command...
building project with { versions: { cds: '10.2.2', compiler: '7.2.1', dk: '10.2.1' }, target: 'gen', tasks: [
    { src: 'db',  for: 'hana',   ... },
    { src: 'srv', for: 'nodejs', ... } ] }
done > wrote output to:
   gen/db/package.json
   gen/db/src/gen/.hdiconfig
   gen/db/src/gen/.hdinamespace
   gen/db/src/gen/CatalogService.Books.hdbtable
   gen/db/src/gen/data/CatalogService.Books.csv
   gen/db/src/gen/data/CatalogService.Books.hdbtabledata
   gen/db/undeploy.json
   gen/srv/package.json
   gen/srv/srv/csn.json
   gen/srv/srv/odata/v4/CatalogService.xml
[2026-11-14 18:00:25]  INFO building the "bookshop-srv" module...
[2026-11-14 18:00:40]  INFO building the "bookshop-db-deployer" module...
[2026-11-14 18:00:45]  INFO building the "bookshop" module...
[2026-11-14 18:00:55]  INFO generating the MTA archive...
[2026-11-14 18:00:56]  INFO the MTA archive generated at: mta_archives/bookshop_1.0.0.mtar
```

> **Pendiente de validar.** Salida reconstruida; se sustituirá por la real.
> El bloque `for: 'hana'` solo aparece si `@cap-js/hana` está instalado en
> `node_modules` (`npm install` antes de `mbt build`).

El `.mtar` es un zip. Mirar dentro es un buen ejercicio:

```bash
unzip -l mta_archives/bookshop_1.0.0.mtar
```

```
  META-INF/MANIFEST.MF        qué módulo es cada zip interior
  META-INF/mtad.yaml          el mta.yaml "resuelto" que lee el deploy service
  bookshop-srv/data.zip       gen/srv con node_modules
  bookshop-db-deployer/data.zip
  bookshop/data.zip
```

> **Trampa.** `gen/srv/package.json` lleva `engines.node`. Si pide una versión
> que el buildpack de la región no tiene (cds-dk 10 escribe `^24`), el staging
> falla con *no match found for node version*. Fija `"engines": {"node": "^22"}`
> en el `package.json` del proyecto o comprueba las versiones del buildpack.
> **Pendiente de validar** en el primer despliegue.

## 11.6 Desplegar

```bash
cf login -a https://api.cf.us10-001.hana.ondemand.com
cf target -s dev
cf deploy mta_archives/bookshop_1.0.0.mtar
```

```
Deploying multi-target app archive mta_archives/bookshop_1.0.0.mtar in org 7b6c2113trial / space dev as ********...

Uploading 1 files...
  /home/rubenfs/projects/bookshop/mta_archives/bookshop_1.0.0.mtar
OK
Operation ID: 3f2a1c8e-....
Deploying in org "7b6c2113trial" and space "dev"
Detected MTA schema version: "3"
No deployed MTA detected - this is initial deployment
Detected new MTA version: "1.0.0"
Processing service "bookshop-auth"...
Processing service "bookshop-db"...
Creating service "bookshop-auth" from MTA resource "bookshop-auth"...
Creating service "bookshop-db" from MTA resource "bookshop-db"...
1 of 2 done
2 of 2 done
Creating application "bookshop-db-deployer" from MTA module "bookshop-db-deployer"...
Binding service instance "bookshop-db" to application "bookshop-db-deployer"...
Uploading application "bookshop-db-deployer"...
Staging application "bookshop-db-deployer"...
Application "bookshop-db-deployer" staged
Executing task "deploy" on application "bookshop-db-deployer"...
Task for application "bookshop-db-deployer" finished successfully
Creating application "bookshop-srv" from MTA module "bookshop-srv"...
Binding service instance "bookshop-auth" to application "bookshop-srv"...
Binding service instance "bookshop-db" to application "bookshop-srv"...
Uploading application "bookshop-srv"...
Staging application "bookshop-srv"...
Application "bookshop-srv" staged
Starting application "bookshop-srv"...
Application "bookshop-srv" started and available at "7b6c2113trial-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com"
Creating application "bookshop" from MTA module "bookshop"...
Binding service instance "bookshop-auth" to application "bookshop"...
Uploading application "bookshop"...
Staging application "bookshop"...
Application "bookshop" staged
Starting application "bookshop"...
Application "bookshop" started and available at "7b6c2113trial-dev-bookshop.cfapps.us10-001.hana.ondemand.com"
Skipping deletion of services, because the command line option "--delete-services" is not specified.
Process finished.
Use "cf dmol -i 3f2a1c8e-..." to download the logs of the process.
```

> **Pendiente de validar.** Salida reconstruida a partir de la documentación
> del plugin; se sustituirá por la real.

El orden es siempre el mismo, y cada paso tiene su pantalla:

| Paso del deploy                          | Qué ha pasado                                     | Dónde se ve                                        |
|------------------------------------------|---------------------------------------------------|----------------------------------------------------|
| Creating service `bookshop-auth`         | Instancia XSUAA con `xs-security.json`            | Instancias y suscripciones; Seguridad › Roles      |
| Creating service `bookshop-db`           | El broker crea el contenedor HDI (esquemas + usuarios) | Instancias y suscripciones; `cf services`     |
| Executing task on `bookshop-db-deployer` | HDI crea las tablas en el esquema de runtime       | Logs del deployer; Database Explorer               |
| Starting `bookshop-srv`                  | CAP arranca, lee `VCAP_SERVICES`, conecta a HANA  | Aplicaciones; `cf logs bookshop-srv --recent`      |
| Starting `bookshop`                      | El approuter arranca con la URL de `srv` y la XSUAA | Aplicaciones › bookshop › Rutas                  |

El atajo que hace todo lo anterior de una vez (build + deploy):

```bash
cds up
```

## 11.7 Comprobar

```bash
cf mtas
cf mta bookshop
cf apps
cf services
```

```
Getting multi-target apps in org 7b6c2113trial / space dev as ********...
mta id     version   namespace
bookshop   1.0.0

Showing health and status for multi-target app bookshop in org 7b6c2113trial / space dev as ********...
Version: 1.0.0
Namespace:
Apps:
name                   requested state   instances   memory   disk   urls
bookshop               started           1/1         256M     256M   7b6c2113trial-dev-bookshop.cfapps.us10-001.hana.ondemand.com
bookshop-db-deployer   stopped           0/1         256M     256M
bookshop-srv           started           1/1         256M     1G     7b6c2113trial-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com

Services:
name            service   plan          bound apps                           last operation
bookshop-auth   xsuaa     application   bookshop, bookshop-srv               create succeeded
bookshop-db     hana      hdi-shared    bookshop-db-deployer, bookshop-srv   create succeeded
```

Y en el navegador: abre la URL del approuter (`…-dev-bookshop.cfapps…`),
pasa por el login de SAP ID Service y añade `/odata/v4/catalog/Books`.

Si abres directamente la URL de `bookshop-srv` sin token, CAP responde `401`
(con `auth: xsuaa` en producción). Es correcto: el camino es por el approuter.

## 11.8 Quitar la route pública de `srv`

Que `srv` tenga URL pública es cómodo para depurar y peligroso en producción.
Para que solo sea alcanzable desde el approuter:

```yaml
  - name: bookshop-srv
    type: nodejs
    path: gen/srv
    parameters:
      instances: 1
      buildpack: nodejs_buildpack
      routes:
        - route: ${default-url}
          protocol: http1
    # ... o, para quitarla del todo:
    # parameters:
    #   no-route: true
```

Con `no-route: true` el approuter no podría alcanzarla por su URL, así que
hay que combinarlo con una route interna (`*.apps.internal`) y una política de
red (`cf add-network-policy`). Es un paso del capítulo 14; en dev se puede
dejar la route pública con `@requires` protegiendo los servicios.

## 11.9 Redesplegar y deshacer

```bash
# cambios de código: subir versión en mta.yaml o usar --version-rule
mbt build && cf deploy mta_archives/bookshop_1.0.0.mtar --version-rule ALL

# ver operaciones y descargar logs de una
cf mta-ops
cf dmol -i <operation-id>

# una operación se quedó a medias
cf deploy -i <operation-id> -a abort
cf deploy -i <operation-id> -a retry

# quitar todo: apps, y con --delete-services también instancias (¡y datos!)
cf undeploy bookshop --delete-services --delete-service-keys -f
```

> **Trampa.** `cf deploy` rechaza una versión igual o menor que la desplegada
> ("A newer version... is already deployed"). Sube `version` en `mta.yaml` o
> añade `--version-rule ALL`.

> **Trampa.** `cf undeploy bookshop` sin `--delete-services` deja las
> instancias (y los datos). Con él, borra el contenedor HDI y todo lo que
> contiene. Elige a conciencia.

## 11.10 Trampas

> **Trampa.** Hacer `mbt build` sin `npm install` previo. `cds build` no
> encuentra `@cap-js/hana` y no genera `gen/db`. El deployer sube vacío.

> **Trampa.** HANA parada (trial). "Creating service bookshop-db" falla o el
> deployer muere con error de conexión. Arranca la instancia y repite.

> **Trampa.** Cuota de memoria de la org agotada. "Staging... failed: memory
> quota exceeded". Baja `memory` de los módulos o para otras apps.

> **Trampa.** Cambiar `xs-security.json` y que el deploy falle actualizando
> `bookshop-auth` por un conflicto. Lee el error: suele ser un scope eliminado
> que un rol aún referencia.

## Para recordar

- `mta.yaml`: `modules` → apps, `resources` → instancias, `requires` →
  bindings, `provides`/`~{}` → pasar URLs entre módulos.
- `mbt build` ejecuta `npm ci` + `cds build --production` y empaqueta
  `gen/` en un `.mtar`.
- `cf deploy` crea instancias, sube apps, liga, ejecuta el deployer, arranca
  `srv` y approuter, publica routes. Cada paso tiene su pantalla.
- El deployer en *stopped* es normal. `srv` sin token da 401: entra por el
  approuter.
- `cf mtas`, `cf mta`, `cf mta-ops`, `cf dmol`: la vista MTA del space.
- `cf undeploy --delete-services` borra los datos.

## Ejercicio

1. Añade `hana,xsuaa,approuter,mta` a tu bookshop, `npm install`, `mbt build`
   y mira dentro del `.mtar`.
2. Arranca la HANA, `cf deploy`, y sigue el proceso con el cockpit abierto en
   *Instancias y suscripciones* y *Aplicaciones*.
3. Abre la app por el approuter y por la URL de `srv`. Explica la diferencia.
4. Sube `version` a `1.0.1`, cambia algo trivial, redespliega. Comprueba con
   `cf mta bookshop` y `cf events bookshop-srv`.
