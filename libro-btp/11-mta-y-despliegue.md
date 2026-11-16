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
| `bookshop-srv`         | Módulo (app)  | `gen/srv`: tu servicio CAP compilado, `csn.json`, `package.json` con las dependencias de runtime | El servidor Node que has estado viendo con `cds-tsx watch`, pero con HANA detrás y validando JWT. Expone `/catalog`. Corre siempre | `cf apps`, *started*                 |
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

### Dos caminos de entrada

Bookshop sigue siendo una API: `srv` es quien responde. El approuter no la
sustituye, le pone delante un login para quien no sabe pedir tokens: el
navegador. Un programa sí sabe, y no lo necesita.

| Quien llama                          | A dónde              | Cómo se identifica                                   |
|--------------------------------------|----------------------|------------------------------------------------------|
| Una persona con navegador            | Approuter            | Login con usuario y contraseña; cookie de sesión     |
| Un programa (otra app, `curl`, Postman) | `srv` directamente | Un JWT en la cabecera `Authorization: Bearer`        |

**Ejemplo 1: listar libros desde el navegador.** Abres
`https://…-dev-bookshop.cfapps…/catalog/Books`.

1. El approuter busca en `xs-app.json`: la ruta `^/(.*)$` va a la
   destination `srv-api`. No llevas cookie, así que te redirige al login de
   XSUAA.
2. Te identificas con tu usuario del trial. XSUAA devuelve al approuter un
   código, el approuter lo cambia por un JWT y te deja una cookie de sesión.
3. El approuter reenvía `GET /catalog/Books` a
   `https://…-dev-bookshop-srv.cfapps…/catalog/Books` con
   `Authorization: Bearer <jwt>` (eso es `forwardAuthToken: true`).
4. `srv` valida el JWT con `@sap/xssec`, ejecuta el handler `after READ`
   y devuelve el JSON. El approuter te lo pasa sin tocarlo.

La segunda petición ya lleva cookie y solo ocurren los pasos 3 y 4.

**Ejemplo 2: la misma lista desde `curl`.** Sin approuter. Es lo que hace
una app que llama a otra: pide un token a XSUAA con las credenciales de una
service key de `bookshop-auth` y lo presenta a `srv`.

```bash
# 1. Token con client credentials (url, clientid y clientsecret de la service key)
TOKEN=$(curl -s -X POST "$UAA_URL/oauth/token" \
  -u "$CLIENTID:$CLIENTSECRET" \
  -d "grant_type=client_credentials" | jq -r .access_token)

# 2. Llamada directa a srv
curl -H "Authorization: Bearer $TOKEN" \
  https://…-dev-bookshop-srv.cfapps…/catalog/Books
```

**Ejemplo 3: un servicio personalizado.** Una acción en `cat-service.cds`:

```cds
service CatalogService @(path: '/catalog') {
  @readonly entity Books as projection on my.Books;
  action submitOrder(book: Books:ID, quantity: Integer) returns { stock: Integer };
}
```

CAP la expone como `POST /catalog/submitOrder` con cuerpo
`{"book": "…", "quantity": 2}`. El flujo es el mismo que para `Books`:
desde una UI en el navegador va por el approuter con la cookie; desde un
programa va directa a `srv` con el token. El handler,
`this.on('submitOrder', …)`, se escribe una vez y no sabe por qué camino ha
llegado la petición.

Dos matices:

- En local llamas a `srv` en `localhost:4004` sin token porque la auth es
  `mocked`. En BTP, con `auth: xsuaa`, la misma llamada sin token devuelve
  **401**.
- Si quitas la route pública de `srv` (11.8), los programas entran también
  por el approuter: acepta un `Authorization: Bearer` que ya venga puesto y
  lo reenvía sin pedir login.

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

Salida real del 16 de noviembre, recortada donde se indica:

```
[2026-11-16 22:45:46]  INFO Cloud MTA Build Tool version 1.2.51
[2026-11-16 22:45:46]  INFO generating the "Makefile_20261116224546.mta" file...
[2026-11-16 22:45:46]  INFO executing the "make -f Makefile_20261116224546.mta p=cf mtar= strict=true mode=" command...
[2026-11-16 22:45:46]  INFO validating the MTA project
[2026-11-16 22:45:46]  INFO running the "before-all" build...
[2026-11-16 22:45:46]  INFO executing the "npm ci" command...
added 96 packages, and audited 211 packages in 3s
[2026-11-16 22:45:49]  INFO executing the "npx cds build --production" command...
building project with {
  versions: { cds: '10.2.2', compiler: '7.2.1', dk: '10.2.1' },
  target: 'gen',
  tasks: [
    { src: '.',   for: 'typescript', options: { model: [ 'db', 'srv', 'app', 'app/*', '@sap/cds/srv/outbox', '.' ] } },
    { src: 'db',  for: 'hana',       options: { model: [ 'db', 'srv', 'app', 'app/*', '@sap/cds/srv/outbox' ] } },
    { src: 'srv', for: 'nodejs',     options: { model: [ 'db', 'srv', 'app', 'app/*', '@sap/cds/srv/outbox' ] } }
  ]
}
...done > wrote output to:
   gen/db/package.json
   gen/db/src/gen/.hdiconfig
   gen/db/src/gen/.hdinamespace
   gen/db/src/gen/CatalogService.Authors.hdbview
   gen/db/src/gen/CatalogService.Books.hdbview
   gen/db/src/gen/cds.outbox.Messages.hdbtable
   gen/db/src/gen/data/sap.capire.bookshop-Authors.csv
   gen/db/src/gen/data/sap.capire.bookshop-Authors.hdbtabledata
   gen/db/src/gen/data/sap.capire.bookshop-Books.csv
   gen/db/src/gen/data/sap.capire.bookshop-Books.hdbtabledata
   gen/db/src/gen/sap.capire.bookshop.Authors.hdbtable
   gen/db/src/gen/sap.capire.bookshop.Books.hdbtable
   gen/db/undeploy.json
   gen/srv/package-lock.json
   gen/srv/package.json
   gen/srv/srv/_i18n/i18n.json
   gen/srv/srv/_i18n/messages.properties
   ... 26 more. Run with DEBUG=build to show all files.

build completed in 3321 ms
[2026-11-16 22:45:53]  INFO building the "bookshop-srv" module...
[2026-11-16 22:45:53]  INFO executing the "npm clean-install --production" command...
npm warn EBADENGINE Unsupported engine {
npm warn EBADENGINE   package: 'bookshop@1.0.0',
npm warn EBADENGINE   required: { node: '^24' },
npm warn EBADENGINE   current: { node: 'v22.22.0', npm: '10.9.4' }
npm warn EBADENGINE }
added 76 packages, and audited 77 packages in 822ms
[2026-11-16 22:45:55]  INFO finished building the "bookshop-srv" module
[2026-11-16 22:45:55]  INFO building the "bookshop-db-deployer" module...
[2026-11-16 22:45:55]  INFO executing the "npm install --production" command...
added 29 packages, and audited 30 packages in 3s
[2026-11-16 22:45:58]  INFO finished building the "bookshop-db-deployer" module...
[2026-11-16 22:45:58]  INFO building the "bookshop" module...
[2026-11-16 22:45:58]  INFO executing the "npm install --production" command...
added 194 packages, and audited 195 packages in 6s
[2026-11-16 22:46:06]  INFO finished building the "bookshop" module
[2026-11-16 22:46:06]  INFO generating the "META-INF/mtad.yaml" file...
[2026-11-16 22:46:06]  INFO the MTA archive generated at: .../bookshop-cap/mta_archives/bookshop_1.0.0.mtar
[2026-11-16 22:46:06]  INFO cleaning temporary files...
```

Qué está pasando, por fases:

| Fase                              | Qué hace                                                                                                            |
|-----------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `before-all`: `npm ci`            | Instala en la raíz según el `package-lock.json`. Por eso `cds add` sin `npm install` rompe aquí                     |
| `before-all`: `cds build --production` | Tres tareas: `typescript` compila `srv/*.ts` con `tsconfig.cdsbuild.json`; `hana` escribe `gen/db`; `nodejs` escribe `gen/srv` |
| Módulo `bookshop-srv`             | `npm clean-install --production` **dentro de `gen/srv`**: instala solo `dependencies` (sin `tsx`, sin `typescript`) y lo empaqueta |
| Módulo `bookshop-db-deployer`     | Lo mismo en `gen/db`: `@sap/hdi-deploy` y el driver `hdb`                                                          |
| Módulo `bookshop`                 | Lo mismo en `.deploy/app-router`: `@sap/approuter` con sus 194 paquetes. Deja un `package-lock.json` ahí, que va a git |
| `mtad.yaml`                       | El `mta.yaml` "resuelto" para el deploy service                                                                     |

Lo que hay en `gen/db` merece una mirada, porque es la traducción del
modelo CDS a objetos de HANA:

| Fichero                                   | Qué es                                                                                     |
|-------------------------------------------|--------------------------------------------------------------------------------------------|
| `sap.capire.bookshop.Books.hdbtable`      | Una entidad de `db/schema.cds` → una **tabla**                                             |
| `CatalogService.Books.hdbview`            | Una proyección del servicio → una **vista** sobre la tabla. El servicio no lee tablas, lee vistas |
| `cds.outbox.Messages.hdbtable`            | Tabla del *outbox* de CAP (mensajería asíncrona). No la has pedido; viene con el runtime     |
| `data/sap.capire.bookshop-Books.csv` + `.hdbtabledata` | Los CSV iniciales y la instrucción de carga para HDI                            |
| `.hdiconfig`, `.hdinamespace`             | Qué plugin de HDI trata cada extensión; el prefijo de nombres                               |
| `undeploy.json`                           | Qué objetos puede borrar HDI si desaparecen del modelo                                      |

Y en `gen/srv`, la comprobación que importa en un proyecto TypeScript:

```
gen/srv/srv/cat-service.js        ← el handler compilado (gracias a tsconfig.cdsbuild.json)
gen/srv/srv/csn.json              ← el modelo compilado que lee CAP en runtime
gen/srv/srv/odata/v4/CatalogService.xml
gen/srv/@cds-models/...           ← los tipos de cds-typer, compilados a .js
```

Si `cat-service.js` no está, la app arrancará sin tu lógica y nadie avisará.
Es la trampa 2 del capítulo 10.

El `.mtar` es un zip. Mirar dentro es un buen ejercicio:

```bash
unzip -l mta_archives/bookshop_1.0.0.mtar
```

```
  Length      Name
      472  META-INF/MANIFEST.MF          qué módulo es cada zip interior
     1648  META-INF/mtad.yaml            el mta.yaml "resuelto" que lee el deploy service
  7190206  bookshop/data.zip             .deploy/app-router con node_modules
  2504988  bookshop-db-deployer/data.zip gen/db con node_modules
  3861664  bookshop-srv/data.zip         gen/srv con node_modules
       63  xs-security.json              el path del recurso bookshop-auth, copiado
```

El `mtad.yaml` es casi igual al `mta.yaml`, con dos diferencias que
explican lo que son los tipos "bonitos": `type: nodejs` se ha convertido en
`javascript.nodejs` y `type: hdb` en `com.sap.xs.hdi`. Los nombres cortos
son alias que `mbt` traduce a los que entiende el deploy service.

> **Trampa.** `cds build` escribe `"engines": { "node": "^24" }` en
> `gen/srv/package.json` y `gen/db/package.json` aunque el `package.json`
> del proyecto no tenga `engines`. De ahí el aviso `EBADENGINE` si tu Node
> local es 22: es inofensivo en el build, pero en el staging el buildpack
> de la región tiene que tener un Node 24 o fallará con *no match found for
> node version*. En `us10` el `nodejs_buildpack` 1.9.7 lo trae. Si en otra
> región no, pon `"engines": {"node": "^22"}` en el `package.json` del
> proyecto: `cds build` respeta el valor si existe.

## 11.6 Desplegar

```bash
cf target -s dev            # si no estás ya en dev
cf deploy mta_archives/bookshop_1.0.0.mtar
```

Salida real del primer despliegue, 16 de noviembre:

```
Deploying multi-target app archive mta_archives/bookshop_1.0.0.mtar in org 7b6c2113trial / space dev as ********...

Uploading 1 files...
  /home/rubenfs/projects/btp-training-projects/bookshop-cap/mta_archives/bookshop_1.0.0.mtar
 1s  11.56 MiB / 11.56 MiB [=========================================] 100.00% 1s
OK
Operation ID: e235a154-e207-11f1-a792-eeee0a92bfeb
Deploying in org "7b6c2113trial" and space "dev"
Detected MTA schema version: "3"
No deployed MTA detected - this is initial deployment of MTA with ID "bookshop"
Detected new MTA version: "1.0.0"
Processing service "bookshop-db"...
Creating service "bookshop-db" from MTA resource "bookshop-db"...
Processing service "bookshop-auth"...
Setting service "bookshop-auth" parameters from "xs-security.json"
Creating service "bookshop-auth" from MTA resource "bookshop-auth"...
0 of 1 done, (1 creating)
1 of 1 done
Creating application "bookshop-srv" from MTA module "bookshop-srv"...
Binding service instance "bookshop-auth" to application "bookshop-srv"...
Creating application "bookshop" from MTA module "bookshop"...
Binding service instance "bookshop-db" to application "bookshop-srv"...
Binding service instance "bookshop-auth" to application "bookshop"...
Creating application "bookshop-db-deployer" from MTA module "bookshop-db-deployer"...
Binding service instance "bookshop-db" to application "bookshop-db-deployer"...
Uploading application "bookshop"...
Uploading application "bookshop-srv"...
Uploading application "bookshop-db-deployer"...
Staging application "bookshop-srv"...
Staging application "bookshop"...
Staging application "bookshop-db-deployer"...
Application "bookshop" staged
Application "bookshop-srv" staged
Starting application "bookshop"...
Starting application "bookshop-srv"...
Application "bookshop-srv" started and available at "7b6c2113trial-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com"
Application "bookshop" started and available at "7b6c2113trial-dev-bookshop.cfapps.us10-001.hana.ondemand.com"
Application "bookshop-db-deployer" staged
Executing task "deploy" on application "bookshop-db-deployer"...
Skipping deletion of services, because the command line option "--delete-services" is not specified.
Process finished.
Use "cf dmol -i e235a154-e207-11f1-a792-eeee0a92bfeb" to download the logs of the process.
```

Cada línea es una operación que ya conoces de los capítulos 4 y 5, solo que
lanzada por el deploy service:

| Línea del deploy                          | Equivale a                                   | Dónde se ve después                                   |
|-------------------------------------------|----------------------------------------------|-------------------------------------------------------|
| Creating service `bookshop-db`            | `cf create-service hana hdi-shared bookshop-db` | Instancias y suscripciones; `cf services`          |
| Creating service `bookshop-auth` (con `xs-security.json`) | `cf create-service xsuaa application bookshop-auth -c xs-security.json` | Instancias y suscripciones; Seguridad › Roles |
| Creating application + Binding            | `cf push --no-start` + `cf bind-service`     | Aplicaciones; `cf env <app>` muestra el `VCAP_SERVICES` |
| Uploading / Staging                       | Subir el `data.zip` y ejecutar el buildpack  | `cf logs <app> --recent`, líneas `[STG]`              |
| Starting                                  | `cf start`                                   | `cf apps`                                             |
| Executing task "deploy" on `bookshop-db-deployer` | `cf run-task bookshop-db-deployer "npm start"` | `cf tasks bookshop-db-deployer`; logs `[APP/TASK/deploy]` |

> **Trampa.** Con `enable-parallel-deployments: true` el orden **no** es
> "primero el deployer, luego `srv`". En la salida de arriba `srv` y el
> approuter arrancan *antes* de que la tarea del deployer termine, y la
> última línea solo dice *Executing task*, no si acabó bien. Dos
> consecuencias:
>
> 1. Hay que comprobar la tarea aparte: `cf tasks bookshop-db-deployer`
>    debe decir `SUCCEEDED`.
> 2. `srv` arranca contra un contenedor aún vacío. En su log aparece un
>    `warn` del *outbox*: `Could not find table/view CDS_OUTBOX_MESSAGES in
>    schema FE77…`. Es inofensivo: CAP lo reintenta y en cuanto el deployer
>    crea las tablas todo funciona. Pero si lo ves, ya sabes por qué.

El atajo que hace build y deploy de una vez:

```bash
cds up
```

## 11.7 Comprobar

```bash
cf mtas
cf mta bookshop
cf tasks bookshop-db-deployer
```

```
mta id     version   namespace
bookshop   1.0.0

Version: 1.0.0
Namespace:

Apps:
name                   requested state   instances   memory   disk     urls
bookshop-srv           STARTED           1/1         85.8M    226.4M   7b6c2113trial-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com
bookshop               STARTED           1/1         45.5M    240.2M   7b6c2113trial-dev-bookshop.cfapps.us10-001.hana.ondemand.com
bookshop-db-deployer   STOPPED           0/1         0        0

Services:
name            service   plan          bound apps                           last operation
bookshop-db     hana      hdi-shared    bookshop-srv, bookshop-db-deployer   create succeeded
bookshop-auth   xsuaa     application   bookshop-srv, bookshop               create succeeded

id   name     state       start time                      command
1    deploy   SUCCEEDED   Mon, 16 Nov 2026 21:53:19 UTC   npm start
```

Fíjate en que `cf mta` muestra la memoria **usada** (85.8M), no la
reservada. La reservada se ve con `cf app bookshop-srv`: 1G para `srv`,
porque el `mta.yaml` no fija `memory` y ese es el valor por defecto del
space. El approuter sí lleva `memory: 256M`.

El log del deployer cuenta lo que hizo en HANA. Es el mismo contenedor
HDI del capítulo 7, con otro nombre:

```bash
cf logs bookshop-db-deployer --recent | grep -E 'Deploying|Make|container'
```

```
Deploying "src/gen/sap.capire.bookshop.Authors.hdbtable"... ok (0s 88ms)
Deploying "src/gen/sap.capire.bookshop.Books.hdbtable"... ok (0s 28ms)
Deploying "src/gen/data/sap.capire.bookshop-Authors.hdbtabledata$0.expand"... ok (0s 437ms)
Deploying "src/gen/data/sap.capire.bookshop-Books.hdbtabledata$0.expand"... ok (0s 425ms)
Deploying "src/gen/CatalogService.Authors.hdbview"... ok (0s 40ms)
Deploying "src/gen/CatalogService.Books.hdbview"... ok (0s 40ms)
Make succeeded (0 warnings): 11 files deployed (effective 13), 0 files undeployed (effective 0)
Deploying to the container "FE77BBFE8A6A4B1C8996B61789849DB4"... ok (2s 114ms)
```

Y el arranque de `srv` cuenta a qué se ha conectado. Las líneas que
importan, sin el JSON que las envuelve:

```bash
cf logs bookshop-srv --recent | grep -E 'Installing node|connect to db|auth strategy|serving|launched'
```

```
[STG] -----> Installing node 24.22.1
[cds] connect to db > hana { host: 'b7f3e3c5-….hna0.prod-us10.hanacloud.ondemand.com', port: '443',
                              schema: 'FE77BBFE8A6A4B1C8996B61789849DB4',
                              user: 'FE77BBFE8A6A4B1C8996B61789849DB4_…_RT', hdi_user: '…_DT' }
[cds] using auth strategy { kind: 'xsuaa' }
[cds] serving CatalogService { at: [ '/catalog' ], impl: 'srv/cat-service.js' }
[cds] server v10.2.2 launched in 918 ms
```

Tres cosas se confirman ahí: el buildpack ha instalado Node 24 (el
`engines ^24` de 11.5 no era problema en `us10`), `srv` usa el usuario
`_RT` del contenedor (el de runtime, no el `_DT` de diseño, igual que
viste en `SYS.SCHEMAS` en el capítulo 7), y el handler cargado es el
`.js` compilado.

Por último, los dos caminos de entrada de 11.4 con `curl`:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://7b6c2113trial-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com/catalog/Books
curl -s -i https://7b6c2113trial-dev-bookshop.cfapps.us10-001.hana.ondemand.com/catalog/Books | head -c 300
```

```
401
```

```
HTTP/2 200
content-type: text/html
set-cookie: JSESSIONID=…; HttpOnly; Secure
<html><head>…<script>…location="https://7b6c2113trial.authentication.us10.hana.ondemand.com/oauth/authorize?response_type=code&client_id=sb-bookshop-7b6c2113trial-dev!t742437&redirect_uri=https%3A%2F%2F7b6c2113trial-dev-bookshop.cfapps.us10-001.hana.ondemand.com%2Flogin%2Fcallback"</script></head></html>
```

`srv` directo, sin token: **401**, como anunciaba 11.4. El approuter no
responde con un 302 sino con un **200 y una página mínima** cuyo script
guarda en cookies a dónde querías ir y te manda al `/oauth/authorize` de
XSUAA. El `client_id` que ves, `sb-bookshop-7b6c2113trial-dev!t742437`, es
el de la instancia `bookshop-auth`: `sb-` + el `xsappname` del `mta.yaml`.

En el navegador: abre la URL del approuter, pasa por el login de SAP ID
Service y añade `/catalog/Books`. Los libros con `stock > 100` llevan
"(en oferta)": el handler del capítulo 10 corriendo en BTP contra HANA.

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
