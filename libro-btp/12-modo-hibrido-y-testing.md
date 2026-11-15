# 12. Modo híbrido y testing

**Objetivo del capítulo.** Ejecutar la app en el portátil contra la HANA y la
XSUAA reales del trial, sin desplegar, y usar eso para escribir tests de
integración de verdad. Es el capítulo que más rentabiliza el gusto por el
testing.

## 12.1 Los tres modos de ejecución

```
  DEVELOPMENT                 HYBRID                        PRODUCTION
  cds watch                   cds watch --profile hybrid    cf deploy
  ┌──────────────┐            ┌──────────────┐              ┌──────────────┐
  │ portátil     │            │ portátil     │              │ Cloud Foundry│
  │ SQLite :mem  │            │   │          │              │   │          │
  │ auth mocked  │            │   │ cds bind │              │   │ binding  │
  └──────────────┘            │   ▼          │              │   ▼          │
                              │ HANA  (BTP)  │              │ HANA  (BTP)  │
                              │ XSUAA (BTP)  │              │ XSUAA (BTP)  │
                              └──────────────┘              └──────────────┘
  rápido, sin red             datos y auth reales,          lo que ve el usuario
  no prueba HANA ni roles     código local, depurable
```

| Modo        | Base de datos         | Autenticación     | Para qué                                                            |
|-------------|-----------------------|-------------------|---------------------------------------------------------------------|
| development | SQLite en memoria     | mocked            | Programar. Reinicio en milisegundos, tests unitarios                |
| hybrid      | HANA real (contenedor del space) | XSUAA real | Probar SQL específico de HANA, roles reales, destinations reales, **tests de integración** |
| production  | HANA vía `VCAP_SERVICES` | XSUAA vía `VCAP_SERVICES` | Lo desplegado                                                |

> **Idea clave.** El modo híbrido no es un entorno nuevo: es tu portátil
> haciendo de `bookshop-srv`, con las mismas credenciales que tendría la app
> desplegada. Lo que falle aquí fallaría en la nube, y lo depuras con
> breakpoints.

## 12.2 `cds bind`: service keys sin copiar secretos

`cds bind` conecta un servicio de `cds.requires` con una instancia del space
actual. Crea una service key si no existe y guarda **solo la referencia** en
`.cdsrc-private.json`; las credenciales se piden a Cloud Foundry en cada
arranque.

```bash
cf target                 # hay que estar en el space donde están las instancias
cds bind -2 bookshop-db
cds bind -2 bookshop-auth
```

```
Retrieving data from Cloud Foundry...
Binding db to Cloud Foundry managed service bookshop-db:bookshop-db-key with kind hana.
Saving bindings to .cdsrc-private.json in profile hybrid.

TIP: Run with cloud bindings: cds watch --profile hybrid

Retrieving data from Cloud Foundry...
Binding auth to Cloud Foundry managed service bookshop-auth:bookshop-auth-key with kind xsuaa.
Saving bindings to .cdsrc-private.json in profile hybrid.
```

Lo que queda en el fichero:

```json
{
  "requires": {
    "[hybrid]": {
      "db": {
        "binding": {
          "type": "cf",
          "apiEndpoint": "https://api.cf.us10-001.hana.ondemand.com",
          "org": "7b6c2113trial",
          "space": "dev",
          "instance": "bookshop-db",
          "key": "bookshop-db-key",
          "resolved": false
        },
        "kind": "hana"
      },
      "auth": {
        "binding": { "...": "...", "instance": "bookshop-auth", "key": "bookshop-auth-key" },
        "kind": "xsuaa"
      }
    }
  }
}
```

Ni un secreto. Por eso puede vivir en el disco, aunque sigue en `.gitignore`
porque es configuración personal (otro desarrollador tendrá otro space).

```bash
cf service-keys bookshop-db       # la key que cds bind creó
cds env requires.db --profile hybrid --resolve-bindings   # las credenciales resueltas
```

> **Trampa.** `cds bind` usa el `cf target` actual. Si estás en `prod`, te
> liga a la HANA de prod. Mira `cf target` antes.

> **Trampa.** Las keys que crea `cds bind` son keys normales: no caducan.
> Cuando cambies de proyecto, `cf delete-service-key bookshop-db bookshop-db-key`.

## 12.3 Arrancar en híbrido

```bash
cds watch --profile hybrid
```

```
cds serve all --with-mocks --in-memory? --profile hybrid

[cds] - loaded model from 2 file(s):

  srv/cat-service.cds
  db/schema.cds

[cds] - connect to db > hana {
  host: 'xxxx.hana.trial-us10.hanacloud.ondemand.com',
  port: '443',
  user: 'BOOKSHOP_DB_1_RT',
  schema: 'BOOKSHOP_DB_1',
  ...
}
[cds] - using auth strategy {
  kind: 'xsuaa',
  impl: '@sap/cds/lib/auth/xsuaa-auth'
}
[cds] - serving CatalogService { path: '/odata/v4/catalog' }

[cds] - server listening on { url: 'http://localhost:4004' }
```

Dos diferencias con el modo development: `connect to db > hana` con el
usuario `_RT` del contenedor, y `auth strategy xsuaa`. Ahora
`curl localhost:4004/odata/v4/catalog/Books` devuelve **401**, porque no
llevas token. Es la prueba de que la seguridad real está activa.

### Probar con un token real

Para llamar al servicio en híbrido necesitas un JWT de la XSUAA de bookshop.
Lo más sencillo es el flujo *password* contra la instancia (solo en dev):

```bash
KEY=$(cf service-key bookshop-auth bookshop-auth-key | sed '1,2d')
CLIENTID=$(echo "$KEY" | jq -r .credentials.clientid)
CLIENTSECRET=$(echo "$KEY" | jq -r .credentials.clientsecret)
URL=$(echo "$KEY" | jq -r .credentials.url)

TOKEN=$(curl -s -u "$CLIENTID:$CLIENTSECRET" \
  -d grant_type=password -d username="$MI_USUARIO" -d password="$MI_PASSWORD" \
  "$URL/oauth/token" | jq -r .access_token)

curl -s -H "Authorization: Bearer $TOKEN" localhost:4004/odata/v4/catalog/Books | jq
```

El token lleva los scopes de las role collections del usuario. Si no tienes
`Bookshop_Admin`, el `AdminService` devolverá 403 también en híbrido:
exactamente lo que pasaría en la nube.

> **Pendiente de validar.** El *grant type* `password` puede estar
> deshabilitado según la configuración del IdP. Alternativa: ejecutar el
> approuter en local (`.deploy/app-router` con `default-env.json`) y entrar
> por el navegador.

### Híbrido a medias

Se puede mezclar: HANA real y auth simulada, para probar SQL sin pelearse con
tokens:

```bash
cds bind -2 bookshop-db                     # solo la db
cds watch --profile hybrid                  # auth sigue en mocked
```

CAP avisa con `using auth strategy mocked`. Con usuarios de prueba definidos
en `package.json` (`cds.requires.auth.users`) puedes simular roles:

```json
"cds": {
  "requires": {
    "auth": {
      "kind": "mocked",
      "users": {
        "alice": { "roles": ["Admin"] },
        "bob":   { "roles": [] }
      }
    }
  }
}
```

```bash
curl -u alice: localhost:4004/odata/v4/admin/Books      # 200
curl -u bob:   localhost:4004/odata/v4/admin/Books      # 403
```

## 12.4 Tests

### Unitarios e integración ligera: SQLite

CAP incluye utilidades de test sobre `@sap/cds/lib/utils/cds-test` (o
`@cap-js/cds-test`), que arrancan el servidor en memoria:

```bash
cds add test            # añade test/ con un ejemplo y la dependencia
npm install
```

```js
// test/catalog.test.js
import cds from '@sap/cds'
import { expect } from 'chai'

const { GET, POST, axios } = cds.test(import.meta.dirname + '/..')

describe('CatalogService', () => {
  it('lista libros', async () => {
    const { data } = await GET('/odata/v4/catalog/Books')
    expect(data.value).to.have.length.greaterThan(0)
  })

  it('rechaza stock negativo', async () => {
    axios.defaults.auth = { username: 'alice', password: '' }
    await expect(POST('/odata/v4/admin/Books', { title: 'x', stock: -1 }))
      .to.be.rejectedWith(/400/)
  })
})
```

```bash
npm test
```

Rápidos, sin red, se ejecutan en cualquier CI. Cubren modelo, handlers y
validaciones. **No** cubren diferencias SQLite/HANA ni roles reales.

### Integración real: contra la HANA del trial

`cds bind --exec` ejecuta cualquier comando con las credenciales de los
bindings híbridos en `VCAP_SERVICES`:

```bash
cds bind --exec -- npm test
cds bind --exec --profile hybrid -- npx mocha test/integration/*.test.js
```

Los mismos tests, ahora contra el contenedor HDI real. Lo que descubren que
SQLite no:

| Diferencia                                   | Ejemplo                                                           |
|----------------------------------------------|-------------------------------------------------------------------|
| Tipos y longitudes                           | `String(10)` en HANA corta o falla; SQLite acepta cualquier cosa  |
| Funciones SQL en vistas                      | `strftime` existe en SQLite, no en HANA                           |
| Mayúsculas en nombres                        | HANA guarda identificadores en mayúsculas                         |
| Concurrencia y locks                         | Dos escrituras simultáneas se comportan distinto                  |
| Roles y scopes                               | Solo con XSUAA real se prueba `@requires` con tokens de verdad     |

> **Idea clave.** Estrategia razonable: tests unitarios con SQLite en cada
> commit, tests de integración con `cds bind --exec` contra la HANA de dev
> antes de cada deploy o en un job nocturno. Nunca contra prod.

### Un contenedor para tests

Los tests de integración ensucian datos. Opciones, de menos a más limpia:

1. **Mismo contenedor de dev**, con `before/after` que limpian lo creado.
2. **Un contenedor propio para tests**: `cf create-service hana hdi-shared
   bookshop-db-test`, `cds deploy --to hana:bookshop-db-test` para crear las
   tablas, y `cds bind -2 bookshop-db-test --for test` para un perfil `test`.
   Después, `cds bind --exec --profile test -- npm test`.

La segunda es la buena en equipo: cada desarrollador puede tener su
contenedor dentro de la misma HANA (capítulo 7, "dos bases de datos").

```bash
cds deploy --to hana:bookshop-db-test      # crea/actualiza tablas en ese contenedor desde el portátil
```

Este `cds deploy` hace desde tu máquina lo que el `db-deployer` hace en el
`cf deploy`: `cds build` + HDI deploy con las credenciales del contenedor.
Útil también para aplicar un cambio de modelo a dev sin redesplegar `srv`.

## 12.5 Depurar en híbrido

```bash
cds watch --profile hybrid --debug          # abre el inspector de Node
```

En VS Code, el `.vscode/launch.json` que crea `cds init` ya tiene una
configuración `cds watch`; añade `"args": ["--profile", "hybrid"]` y pon
breakpoints en los handlers. Estás depurando contra datos reales con una
pila de llamadas local.

## 12.6 Trampas

> **Trampa.** HANA parada (trial). `cds watch --profile hybrid` falla con
> `connection refused` o `ECONNRESET` sin decir que está parada. Arráncala.

> **Trampa.** "Allow only BTP IPs" en la instancia HANA. Mismo síntoma que la
> anterior pero permanente. Cambia a *Allow all* en HANA Cloud Central.

> **Trampa.** `cds bind` desde el space equivocado. Mira `cf target`.

> **Trampa.** Tests de integración contra un contenedor compartido sin
> limpiar. Usa un contenedor de tests o transacciones que se deshacen.

> **Trampa.** Olvidar que `.cdsrc-private.json` tiene el nombre de la key y
> que esa key es una credencial viva en BTP. Borra la key al terminar.

## Para recordar

- Tres modos: development (SQLite, mocked), hybrid (servicios reales desde el
  portátil), production (desplegado).
- `cds bind -2 <instancia>` guarda una referencia a una service key en
  `.cdsrc-private.json`. Sin secretos, pero la key existe en BTP.
- `cds watch --profile hybrid` arranca contra HANA y XSUAA reales. 401 sin
  token es señal de que funciona.
- `cds bind --exec -- npm test`: los mismos tests contra la HANA de dev.
- Un contenedor HDI por desarrollador o para tests es barato y evita pisarse.
- `cds deploy --to hana:<instancia>` despliega el esquema desde el portátil.

## Ejercicio

1. `cds bind -2 bookshop-db,bookshop-auth` y `cds watch --profile hybrid`.
   Comprueba el 401 y luego llama con un token.
2. `cds add test`, escribe dos tests (uno de lectura, uno de validación) y
   ejecútalos con `npm test` y con `cds bind --exec -- npm test`. Mide tiempos.
3. Crea un contenedor `bookshop-db-test`, despliega el esquema con
   `cds deploy --to hana:bookshop-db-test` y ejecuta los tests contra él con
   un perfil `test`.
4. Pon un breakpoint en un handler y depura en híbrido.
