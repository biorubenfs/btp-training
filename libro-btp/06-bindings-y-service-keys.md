# 6. Bindings y service keys

**Objetivo del capítulo.** Saber cómo llegan las credenciales de un servicio a
quien lo usa, leer el JSON de credenciales sin miedo y entender el flujo OAuth2
que hay detrás de todos los servicios de BTP.

## 6.1 Dos caminos, el mismo JSON

Una instancia de servicio no sirve de nada si nadie puede llamarla. Hay dos
formas de obtener sus credenciales, y las dos devuelven **el mismo JSON**:

|                              | Binding                                                     | Service key                                                   |
|------------------------------|-------------------------------------------------------------|---------------------------------------------------------------|
| Para quién                   | Una app desplegada en Cloud Foundry                         | Cualquier cosa fuera de CF: tu portátil, Postman, otro sistema |
| Cómo llegan las credenciales | Variable de entorno `VCAP_SERVICES`, inyectada al arrancar  | Las copias del cockpit o con `cf service-key`                 |
| Quién lo crea                | `cf bind-service`, o `cf deploy` leyendo `requires` del `mta.yaml` | `cf create-service-key`, el cockpit, o `cds bind`      |
| Caducidad                    | Vive mientras viva el binding                               | **No caduca.** Vive hasta que la borras                       |
| Uso en CAP                   | Producción: CAP lo lee solo                                 | Modo híbrido con `cds bind` (capítulo 12)                     |

```
                      ┌─────────────────────┐
                      │ instancia           │
                      │ bookshop-db         │
                      │ (hana / hdi-shared) │
                      └──────┬───────┬──────┘
             binding         │       │        service key "dev-key"
                             ▼       ▼
             ┌───────────────────┐  ┌────────────────────────────┐
             │ app bookshop-srv  │  │ mi portátil                │
             │ VCAP_SERVICES={…} │  │ cds bind → .cdsrc-private  │
             └───────────────────┘  │ cds watch --profile hybrid │
                                    └────────────────────────────┘
```

> **Analogía.** Un binding es como las variables de entorno que Heroku inyecta
> al añadir un add-on (`DATABASE_URL`). Una service key es como generar una
> API key en un panel web para usarla tú desde fuera.

## 6.2 Bindings en la práctica

> **Cockpit:** Subcuenta › Cloud Foundry › Espacios › dev › Aplicaciones ›
> bookshop-srv › Enlaces de servicio (*Service Bindings*). Lista las instancias
> ligadas y permite ligar otra.

En proyectos CAP los bindings los crea `cf deploy` a partir de la sección
`requires` de cada módulo del `mta.yaml`. A mano, para experimentar:

```bash
cf bind-service bookshop-srv dest-test
cf restage bookshop-srv          # imprescindible: el binding solo entra con un restage
cf unbind-service bookshop-srv dest-test
```

```
Binding service instance dest-test to app bookshop-srv in org 7b6c2113trial / space dev as ********...
OK

TIP: Use 'cf restage bookshop-srv' to ensure your env variable changes take effect
```

Para ver lo que ha llegado a la app:

```bash
cf env bookshop-srv
```

## 6.3 Service keys en la práctica

> **Cockpit:** Subcuenta › Servicios › Instancias y suscripciones › (instancia)
> › ⋮ › Crear clave de servicio (*Create Service Key*). Después, el nombre de
> la clave › Ver (*View*) muestra el JSON.

```bash
cf create-service-key dest-test key1
cf service-keys dest-test
cf service-key dest-test key1
```

```
Creating service key key1 for service instance dest-test as ********...
OK

Getting keys for service instance dest-test as ********...

name
key1

Getting key key1 for service instance dest-test as ********...

{
  "credentials": {
    "clientid": "sb-clone2a5d…!b742437|destination-xsappname!b62",
    "clientsecret": "e80d1a5f-…",
    "credential-type": "binding-secret",
    "identityzone": "7b6c2113trial",
    "instanceid": "2a5d502f-…",
    "tenantid": "1be714d1-…",
    "tenantmode": "dedicated",
    "token-type": ["xsuaa"],
    "uaadomain": "authentication.us10.hana.ondemand.com",
    "uri": "https://destination-configuration.cfapps.us10.hana.ondemand.com",
    "url": "https://7b6c2113trial.authentication.us10.hana.ondemand.com",
    "verificationkey": "-----BEGIN PUBLIC KEY----- …",
    "xsappname": "clone2a5d…!b742437|destination-xsappname!b62"
  }
}
```

Es el JSON real de la key `key1` creada en el trial (ya borrada), con los
secretos recortados.

### Anatomía del JSON

| Campo                   | Qué significa                                                                         |
|-------------------------|---------------------------------------------------------------------------------------|
| `clientid`              | El "usuario" OAuth2 del servicio                                                      |
| `clientsecret`          | La "contraseña" OAuth2. Secreto. Deja de valer al borrar la key                       |
| `credential-type`       | `binding-secret` = id + secreto. La alternativa es `x509` (certificado cliente)       |
| `url`                   | **Servidor de tokens** (XSUAA) de la subcuenta. Lleva el subdominio                   |
| `uri`                   | **API REST** del servicio. Aquí se llama con el token                                 |
| `identityzone`          | Subdominio de la subcuenta: a qué inquilino pertenece el token                        |
| `tenantid` / `instanceid` | IDs de la subcuenta (tenant) y de esta instancia concreta                           |
| `tenantmode`            | `dedicated`: la instancia es solo de esta subcuenta                                   |
| `uaadomain`             | Dominio de XSUAA en la región                                                         |
| `verificationkey`       | Clave pública para verificar la firma de los tokens JWT                               |
| `xsappname`             | Nombre interno de la "aplicación" OAuth2 que representa esta instancia                |

> **Idea clave.** `url` = dónde pido el token. `uri` = dónde uso el token.
> Casi todos los servicios de BTP tienen estos dos campos y el mismo flujo.

## 6.4 El flujo OAuth2 que hay detrás

Todos los servicios de BTP se consumen igual, con OAuth2 *client credentials*:

```
  Mi código                     XSUAA (url)                Servicio (uri)
     │                              │                            │
     │ 1. clientid + clientsecret   │                            │
     │ ───────────────────────────▶ │                            │
     │                              │                            │
     │ 2. access_token (JWT)        │                            │
     │ ◀─────────────────────────── │                            │
     │                                                           │
     │ 3. GET … con  Authorization: Bearer <token>               │
     │ ────────────────────────────────────────────────────────▶ │
     │                                                           │
     │ 4. respuesta                                              │
     │ ◀──────────────────────────────────────────────────────── │
```

Con `curl`, usando los valores de la key:

```bash
# 0. Guardar la key en variables (jq lee el JSON que imprime cf)
KEY=$(cf service-key dest-test key1 | sed '1,2d')
CLIENTID=$(echo "$KEY" | jq -r .credentials.clientid)
CLIENTSECRET=$(echo "$KEY" | jq -r .credentials.clientsecret)
URL=$(echo "$KEY" | jq -r .credentials.url)
URI=$(echo "$KEY" | jq -r .credentials.uri)

# 1. Pedir el token
TOKEN=$(curl -s -u "$CLIENTID:$CLIENTSECRET" \
  -d grant_type=client_credentials \
  "$URL/oauth/token" | jq -r .access_token)

# 2. Llamar a la API del servicio Destination
curl -s -H "Authorization: Bearer $TOKEN" \
  "$URI/destination-configuration/v1/subaccountDestinations" | jq
```

```
[
  {
    "Name": "NORTHWIND",
    "Type": "HTTP",
    "URL": "https://services.odata.org",
    "Authentication": "NoAuthentication",
    "ProxyType": "Internet"
  }
]
```

El token es un JWT. Si lo decodificas (`echo $TOKEN | cut -d. -f2 | base64 -d`)
verás `client_id`, `zid` (el tenant), `scope` y la caducidad `exp`,
normalmente 12 horas.

CAP y las librerías de SAP (`@sap/xssec`, `@sap-cloud-sdk/connectivity`) hacen
esto por ti. Conviene saberlo para depurar: un 401 en el paso 3 significa
token inválido o del tenant equivocado; un 401 en el paso 1 significa
credenciales caducadas (key borrada) o mal copiadas.

## 6.5 Qué hay en `VCAP_SERVICES`

Al desplegar, Cloud Foundry inyecta en la app la variable `VCAP_SERVICES`: un
JSON con una entrada por cada servicio ligado, agrupadas por nombre de
servicio:

```json
{
  "hana": [
    {
      "label": "hana",
      "plan": "hdi-shared",
      "name": "bookshop-db",
      "instance_name": "bookshop-db",
      "binding_name": null,
      "tags": ["hana", "database", "relational"],
      "credentials": {
        "host": "xxxx.hana.trial-us10.hanacloud.ondemand.com",
        "port": "443",
        "driver": "com.sap.db.jdbc.Driver",
        "url": "jdbc:sap://xxxx.hana.trial-us10.hanacloud.ondemand.com:443?encrypt=true&...",
        "schema": "BOOKSHOP_DB_1",
        "hdi_user": "BOOKSHOP_DB_1_DT",
        "hdi_password": "<secreto>",
        "user": "BOOKSHOP_DB_1_RT",
        "password": "<secreto>",
        "certificate": "-----BEGIN CERTIFICATE-----…"
      }
    }
  ],
  "xsuaa": [
    {
      "label": "xsuaa",
      "plan": "application",
      "name": "bookshop-auth",
      "tags": ["xsuaa"],
      "credentials": {
        "clientid": "sb-bookshop-7b6c2113trial-dev!t12345",
        "clientsecret": "<secreto>",
        "url": "https://7b6c2113trial.authentication.us10.hana.ondemand.com",
        "xsappname": "bookshop-7b6c2113trial-dev!t12345",
        "identityzone": "7b6c2113trial",
        ...
      }
    }
  ]
}
```

Cómo lo usa CAP:

1. Recorre todas las entradas.
2. Para `cds.requires.db`, busca una con `tags` que contenga `hana` (o `label`
   igual a `hana`) y la usa como base de datos.
3. Para `cds.requires.auth`, busca `xsuaa`.
4. Si en `package.json` hay `cds.requires.<nombre>` con `vcap: { name: "x" }`,
   usa la entrada con ese `name`.

En las credenciales del contenedor HDI aparecen dos usuarios: `_RT` (runtime,
el que usa la app para leer y escribir) y `_DT` (design time, el que usa el
deployer para crear tablas). El capítulo 7 explica qué son.

> **Trampa.** `cf env` y la pestaña *Variables de entorno* del cockpit
> muestran los secretos en claro. No pegues esa salida en un chat, un ticket
> o un repositorio. Si necesitas compartir credenciales con alguien, que cree
> su propia service key.

## 6.6 Que una app llame a otra app

Es habitual ver un proyecto en el que una app A guarda "la service key de la
app B" para llamarla. Conviene afinar dos cosas:

1. **Una app no tiene service keys.** Solo las instancias de servicio las
   tienen. Lo que tenía B era una instancia de `xsuaa` ligada, y la key se creó
   de esa instancia.
2. **La key no da acceso a la app, da un token.** Contiene `clientid`,
   `clientsecret` y la `url` de XSUAA. Con eso pides un JWT por client
   credentials y B lo acepta porque lo emitió su propia XSUAA.

```
 A ── clientid/secret (key o binding) ──▶ XSUAA de B ── JWT ──▶ A ── Bearer JWT ──▶ B
```

Hay tres maneras de montarlo:

| Forma                                      | Cómo llegan las credenciales a A                                 | Cuándo tiene sentido                                                 |
|--------------------------------------------|------------------------------------------------------------------|----------------------------------------------------------------------|
| Service key de la XSUAA de B               | Alguien la copia a mano a una variable de entorno de A           | Apps de equipos o subcuentas distintos. Es la versión "a mano"       |
| Misma instancia XSUAA ligada a A y B       | Ya están en `VCAP_SERVICES` de A por el binding                  | A y B van en el mismo `mta.yaml`. No hace falta key                  |
| Destination                                | A pide la destination por nombre; la librería gestiona el token | **La recomendada.** Credenciales fuera del código (capítulo 9)       |

La primera funciona pero hereda el problema de las keys: una credencial real
que no caduca y que alguien tiene que rotar.

## 6.7 Trampas

> **Trampa.** Una service key es una credencial real y no caduca sola.
> Bórrala cuando ya no la uses y no la subas a git. En CAP, `cds bind` guarda
> solo una **referencia** a la key en `.cdsrc-private.json`, no el secreto, y
> lo resuelve en cada arranque pidiéndoselo a CF.

> **Trampa.** Ligar un servicio y hacer `cf restart` en lugar de `cf restage`.
> La app arranca sin el nuevo binding y falla "sin motivo".

> **Trampa.** Mezclar la `url` (XSUAA, para el token) con la `uri` (el
> servicio, para la llamada). Un 404 en `url/destination-configuration/...`
> es este error.

## Para recordar

- Binding = credenciales para una app en CF (`VCAP_SERVICES`). Service key =
  las mismas credenciales para usar fuera.
- `url` = dónde pido el token. `uri` = dónde uso el token.
- Todos los servicios de BTP: client credentials → JWT → Bearer.
- CAP elige la base de datos y la autenticación por los `tags` de
  `VCAP_SERVICES`.
- Las apps no tienen keys, las tienen sus instancias. Para que A llame a B:
  misma XSUAA si comparten `mta.yaml`, destination si no.
- Orden de borrado: keys y bindings primero, la instancia después.

## Ejercicio

1. Crea una instancia `dest-test` y una key. Con `jq` y `curl`, pide un token y
   llama a la API de destinations como en 6.4. Decodifica el JWT y localiza
   `zid` y `exp`.
2. Borra la key e intenta pedir el token otra vez. Lee el error.
3. Cuando bookshop esté desplegado: compara el bloque `xsuaa` de
   `cf env bookshop-srv` con una service key de `bookshop-auth`. Deben ser
   iguales salvo `clientsecret`.
