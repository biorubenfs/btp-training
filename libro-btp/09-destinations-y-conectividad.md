# 9. Destinations y conectividad

**Objetivo del capítulo.** Saber cómo una app en BTP habla con un S/4HANA, con
una API externa o con otra app sin URLs ni credenciales en el código.

## 9.1 Qué es una destination

Una app en BTP casi nunca vive sola: llama a un S/4HANA, a una API externa o
a otra app tuya. Para cada una de esas llamadas necesita una URL, un tipo de
autenticación y unas credenciales. Una **destination** es exactamente eso,
guardado con un nombre en la subcuenta:

```
Nombre:          S4_SALES
URL:             https://s4dev.acme.com
Authentication:  OAuth2ClientCredentials
Client ID:       sb-ventas-…
Client Secret:   ********
Token URL:       https://acme.authentication.eu10.hana.ondemand.com/oauth/token
```

Tu código no lleva ni la URL ni las credenciales. Pide "dame `S4_SALES`" y
el **Destination Service** le devuelve la URL y una cabecera de autenticación
ya resuelta.

```
  bookshop-srv                 Destination Service          Sistema destino
      │                              │                             │
      │ "dame S4_SALES"              │                             │
      │ ────────────────────────────▶│  (pide el token al S/4      │
      │ { URL, Authentication,       │   con el client id/secret   │
      │   authTokens: [...] }        │   guardados en la entrada)  │
      │ ◀────────────────────────────│                             │
      │                                                            │
      │ GET https://s4dev.acme.com/… + Authorization: Bearer …     │
      │ ──────────────────────────────────────────────────────────▶│
```

### Por qué no basta con una variable de entorno

Una variable de entorno con la URL funcionaría. Tres cosas que no te da:

1. **Un valor por entorno sin tocar código.** La subcuenta `dev` tiene su
   `S4_SALES` apuntando al S/4 de desarrollo; la de `prod`, al real. La misma
   app, desplegada en cada subcuenta, llama al sistema correcto.
2. **Credenciales fuera de la app.** Las guarda la plataforma, cifradas. Un
   administrador las rota sin redesplegar nada, y quien haga `cf env` a la app
   no ve el secreto del S/4.
3. **La autenticación hacia el destino la hace el servicio.** Si la entrada es
   OAuth2, el servicio pide el token al sistema destino y lo devuelve hecho.
   Si es *principal propagation*, convierte al usuario que está usando tu app
   en una identidad válida en el S/4. Si el sistema está dentro de la red de
   la empresa, lo enruta por el túnel del Cloud Connector. Todo eso a mano
   son cientos de líneas y varios errores difíciles.

> **Analogía.** Un gestor de secretos y conexiones con nombre, como AWS
> Secrets Manager o un pool JNDI del servidor de aplicaciones, pero con la
> autenticación hacia el destino incorporada.

## 9.2 Destination y Destination Service: dos cosas con el mismo nombre

Aquí está la confusión más habitual, y conviene cortarla pronto. Hay dos
cosas distintas que se llaman parecido:

| Cosa                                       | Dónde se crea                                                  | Qué es                                                                              |
|--------------------------------------------|----------------------------------------------------------------|-------------------------------------------------------------------------------------|
| **Las destinations**                       | Subcuenta › Conectividad › Destinos                            | Las entradas de configuración en sí (`NORTHWIND`, `S4_SALES`). Las crea un admin   |
| **La instancia del Destination Service**   | Instancias y suscripciones, servicio `destination`, plan `lite` | La **puerta de acceso** a esas entradas para una app concreta. No contiene nada    |

La instancia no contiene destinations. Es un cliente OAuth2 registrado que
tiene permiso para **leer** las destinations de la subcuenta por API. Por eso,
recién creada la instancia y su key, la API devuelve una lista vacía:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$URI/destination-configuration/v1/subaccountDestinations"
```

```
[]
```

Y después de crear `NORTHWIND` en Conectividad › Destinos, **sin tocar la
instancia ni la key**, la misma llamada devuelve:

```json
[
  {
    "Name": "NORTHWIND",
    "Type": "HTTP",
    "Description": "",
    "URL": "https://services.odata.org",
    "ProxyType": "Internet",
    "Authentication": "NoAuthentication"
  }
]
```

(Salida real del trial, 2026-11-15.) Los dos pasos son independientes: el
destino se puede crear sin que exista ninguna instancia, y la instancia sin
que exista ningún destino. El orden da igual.

### Para qué sirve entonces la service key

La API del Destination Service no es pública: hay que identificarse. La
instancia es el "usuario" OAuth2 y la key son sus credenciales en un fichero,
el `clientid` y el `clientsecret` más la `url` de dónde pedir el token y la
`uri` de la API (capítulo 6). El flujo de un programa que quiera leer una
destination es siempre este:

```
1. Leo clientid, clientsecret, url y uri (de la key o del binding)
2. Mando clientid + clientsecret a `url` y me dan un token
3. Con el token pido a `uri` "dame NORTHWIND"
4. Me devuelven la URL del destino (y su cabecera de auth, si la tiene)
5. Llamo al destino
```

Quién necesita la key y quién no:

| Quién llama al Destination Service              | Cómo le llegan las credenciales                        | ¿Key? |
|-------------------------------------------------|--------------------------------------------------------|-------|
| Una app desplegada en Cloud Foundry             | Binding: `cf deploy` las pone en `VCAP_SERVICES`       | No    |
| Tu portátil: `curl`, Postman, `cds watch --profile hybrid` | Las copias tú de la key                     | Sí    |
| Un sistema fuera de BTP                         | Alguien le pasa los cuatro valores de la key           | Sí    |

En un proyecto CAP normal la instancia existe, está ligada a la app y **no
tiene ninguna key**. La key solo aparece cuando alguien de fuera de Cloud
Foundry quiere entrar.

### Dos autenticaciones, no una

Cuando tu app llama a un S/4 a través de una destination hay dos
autenticaciones distintas, y conviene no mezclarlas:

| Para hablar con            | Credenciales                                    | De dónde salen                                                  |
|----------------------------|-------------------------------------------------|-----------------------------------------------------------------|
| El Destination Service     | `clientid` y `clientsecret` de la instancia     | Del binding o de la key                                         |
| El S/4 (el destino)        | Usuario del S/4, token OAuth del S/4, certificado… | Guardadas **dentro** de la destination. El servicio las resuelve y tu código nunca las ve en claro |

Con la key tienes solo la primera. La segunda vive en el destino, y ese es el
valor de todo el mecanismo.

## 9.3 Crear una destination

> **Cockpit:** Subcuenta › Conectividad › Destinos › Nuevo destino
> (*Connectivity › Destinations › New Destination*).

Los campos que importan:

| Campo                 | Valores habituales                                                                                     |
|-----------------------|--------------------------------------------------------------------------------------------------------|
| Name                  | Mayúsculas y guiones bajos por convención: `NORTHWIND`, `S4_SALES`                                     |
| Type                  | `HTTP` en el 95 % de los casos. También `RFC`, `LDAP`, `MAIL`                                           |
| URL                   | La base: `https://services.odata.org`                                                                  |
| Proxy Type            | `Internet` para cualquier cosa alcanzable desde la nube. `OnPremise` para sistemas de la red corporativa, vía Cloud Connector |
| Authentication        | `NoAuthentication`, `BasicAuthentication`, `OAuth2ClientCredentials` (servicio a servicio), `OAuth2SAMLBearerAssertion` y `PrincipalPropagation` (el usuario final se propaga al destino con su identidad) |
| Additional Properties | Pares clave-valor. Habituales en SAP: `HTML5.DynamicDestination=true`, `WebIDEEnabled=true`, `sap-client=100` |

**Ejemplo 1, un OData público sin autenticación** (el del ejercicio):

```
Name:            NORTHWIND
Type:            HTTP
URL:             https://services.odata.org
Proxy Type:      Internet
Authentication:  NoAuthentication
```

**Ejemplo 2, otra app tuya protegida con XSUAA.** Es el caso de "una app CAP
llama a otra app" del capítulo 6.6. Los cuatro valores que allí se copiaban a
mano a variables de entorno van aquí, y el código de la app que llama se
queda sin ninguno:

```
Name:            APP_PEDIDOS
Type:            HTTP
URL:             https://pedidos-srv.cfapps.us10.hana.ondemand.com
Proxy Type:      Internet
Authentication:  OAuth2ClientCredentials
Client ID:       sb-pedidos!t12345          ← clientid de la XSUAA de pedidos
Client Secret:   ********                   ← clientsecret de esa XSUAA
Token Service URL: https://7b6c2113trial.authentication.us10.hana.ondemand.com/oauth/token
```

Cuando bookshop pida `APP_PEDIDOS`, el Destination Service pedirá el token a
la XSUAA de pedidos con ese client id y secret, y se lo devolverá a bookshop
ya hecho en `authTokens`. Cambiar la URL de pedidos o rotar su secreto es
editar esta entrada, sin redesplegar bookshop.

> **Trampa.** El botón *Comprobar conexión* (*Check Connection*) solo prueba
> que el host se alcanza. No valida credenciales ni rutas. Un "200 OK" ahí no
> garantiza nada más que DNS y red.

Leer una destination concreta con la API REST, usando la service key del
capítulo 6:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$URI/destination-configuration/v1/destinations/NORTHWIND" | jq
```

```json
{
  "owner": { "SubaccountId": "1be714d1-…", "InstanceId": null },
  "destinationConfiguration": {
    "Name": "NORTHWIND",
    "Type": "HTTP",
    "URL": "https://services.odata.org",
    "Authentication": "NoAuthentication",
    "ProxyType": "Internet"
  }
}
```

> **Pendiente de validar.** Salida reconstruida de la documentación; la de
> `subaccountDestinations` del apartado 9.2 sí es real.

Si la destination tuviera `OAuth2ClientCredentials`, la respuesta incluiría
`authTokens` con un token ya pedido al sistema destino. Eso es lo que te
ahorra el servicio.

## 9.4 Destinations de subcuenta y de instancia

Hay dos ámbitos:

| Ámbito        | Dónde se crea                                           | Quién la ve                                    |
|---------------|---------------------------------------------------------|------------------------------------------------|
| Subcuenta     | Conectividad › Destinos                                 | Todas las apps de la subcuenta                 |
| Instancia     | Instancias y suscripciones › (instancia destination) › Destinos | Solo las apps ligadas a esa instancia  |

Las de subcuenta son las normales. Las de instancia se usan cuando una app
quiere sus destinations privadas. En la respuesta de la API, `owner` dice
cuál es.

## 9.5 Cloud Connector

Para llegar a sistemas dentro de la red de la empresa (un S/4HANA on-premise,
una base de datos interna) hace falta el **Cloud Connector**: un programa que
se instala en la red corporativa y abre un **túnel saliente** hacia una o
varias subcuentas. No hay que abrir puertos de entrada en el firewall.

```
   BTP (subcuenta ventas-dev)                 Red de la empresa
  ┌──────────────────────────┐              ┌────────────────────────────┐
  │ bookshop-srv             │              │  Cloud Connector           │
  │   │ destination S4_DEV   │   túnel TLS  │   expone: s4dev:443        │
  │   ▼ ProxyType=OnPremise  │◀═════════════│   como virtual host        │
  │ Connectivity Service     │  (saliente)  │   "s4-virtual:443"         │
  └──────────────────────────┘              │        │                   │
                                            │        ▼                   │
                                            │  S/4HANA (s4dev.acme.local)│
                                            └────────────────────────────┘
```

Lo que necesitas saber como desarrollador:

- Dentro del conector se declara qué sistemas internos y qué rutas se
  exponen, con un **virtual host** que es el que usas en la destination (no
  el hostname real).
- Lo administra infraestructura o el equipo *basis*. Tú necesitas leer su
  estado y su **Location ID** si hay varios.
- Para usarlo, tu app liga el **Connectivity Service** (`connectivity` /
  `lite`) además del Destination Service, y las librerías de SAP enrutan por
  el proxy que da ese servicio.

> **Cockpit:** Subcuenta › Conectividad › Cloud Connectors. Muestra cada
> conector con estado *Conectado* o no, su Location ID y los sistemas
> expuestos.

> **En el trial.** No hay Cloud Connector ni sistemas on-premise. Se puede
> instalar uno en el portátil para practicar, pero no es necesario para el
> objetivo del libro.

## 9.6 Consumir una destination desde CAP

CAP consume servicios externos en tres pasos:

**1. Importar el modelo del servicio externo.** De su metadata OData:

```bash
curl -s "https://services.odata.org/V4/Northwind/Northwind.svc/\$metadata" -o northwind.xml
cds import northwind.xml --as cds
```

Esto crea `srv/external/Northwind.cds` y añade en `package.json`:

```json
"cds": {
  "requires": {
    "Northwind": {
      "kind": "odata-v4",
      "model": "srv/external/Northwind"
    }
  }
}
```

**2. Decir dónde está en cada entorno.** En local, con mocks o una URL
directa; en producción, con la destination:

```json
"cds": {
  "requires": {
    "Northwind": {
      "kind": "odata-v4",
      "model": "srv/external/Northwind",
      "[production]": {
        "credentials": {
          "destination": "NORTHWIND",
          "path": "/V4/Northwind/Northwind.svc"
        }
      }
    }
  }
}
```

Y añadir el Destination Service al proyecto, que también lo mete en
`mta.yaml`:

```bash
cds add destination
```

**3. Usarlo en un handler.**

```js
// srv/cat-service.js
import cds from '@sap/cds'

export default class CatalogService extends cds.ApplicationService {
  async init() {
    const northwind = await cds.connect.to('Northwind')
    this.on('READ', 'Suppliers', req => northwind.run(req.query))
    return super.init()
  }
}
```

En local, `cds watch` simula el servicio externo con datos de prueba
(*mocked*). En modo híbrido (capítulo 12), `cds bind -2 <instancia-destination>`
hace que use la destination real desde tu portátil.

> **Pendiente de validar.** Los pasos de `cds import` y la configuración de
> `[production]` se ejecutarán en el ejercicio de este capítulo.

### Los dos patrones que verás en proyectos reales

**Patrón A: la app lee una destination.** El `mta.yaml` declara una instancia
de `destination` y la liga al módulo de la app. Nadie crea keys. Al
desplegar, las credenciales entran en `VCAP_SERVICES`, el SAP Cloud SDK las
encuentra solo y resuelve la destination por nombre. Es el patrón correcto y
el que produce `cds add destination`.

**Patrón B: la app lleva una key copiada a mano.** Para llamar a otra app
protegida con XSUAA, alguien crea una service key de la instancia XSUAA de
esa app y copia `clientid`, `clientsecret`, `url` y la URL de la app a
variables de entorno de la que llama. El código pide el token y lo manda
como Bearer. Funciona, pero hereda todos los problemas de las keys: un
secreto real que no caduca, duplicado, que alguien tiene que rotar y que, si
se borra la key, deja la app rota sin aviso.

| | Patrón B (key a mano)                     | Patrón A con destination `OAuth2ClientCredentials` |
|---|-------------------------------------------|----------------------------------------------------|
| Dónde están las credenciales de la otra app | Variables de entorno de tu app | Dentro de la destination, en la subcuenta |
| Quién pide el token a la otra app | Tu código | El Destination Service |
| Qué tiene tu app en `VCAP_SERVICES` | Nada relacionado | El binding de `destination` |
| Cambiar la URL o rotar el secreto | Redesplegar o editar env | Editar la destination en el cockpit |

Los dos son el mismo mecanismo. En A lo hace la plataforma; en B lo haces tú
con las piezas sueltas. Si te encuentras B en un proyecto, el ejemplo 2 del
apartado 9.3 es la migración.

## 9.7 Trampas

> **Trampa.** Crear la instancia de `destination` y su key, llamar a la API y
> ver `[]`. No falta nada en la instancia: faltan las destinations, que se
> crean aparte en Conectividad › Destinos.

> **Trampa.** *Check Connection* en verde y la app falla. El botón no valida
> credenciales. Prueba con la API o con la app.

> **Trampa.** Destination `OnPremise` y la app no liga `connectivity`. El
> error habla de proxy o de "destination not reachable". Hace falta el
> Connectivity Service además del Destination Service.

> **Trampa.** Cambiar la destination y esperar que la app lo note al momento.
> El Destination Service y las librerías cachean unos minutos. Para pruebas
> rápidas, reinicia la app.

> **Trampa.** Credenciales en la destination de dev que apuntan a prod. Las
> destinations se llaman igual en todas las subcuentas precisamente para que
> cada una apunte a su sistema. Revisa la URL, no solo el nombre.

## Para recordar

- Destination = conexión con nombre en la subcuenta: URL + autenticación +
  propiedades. El código pide el nombre, la plataforma resuelve el resto.
- La instancia del Destination Service no contiene destinations: es la puerta
  para leerlas. Binding para la app en CF, key solo para entrar desde fuera.
- Dos autenticaciones: la de tu app contra el Destination Service (key o
  binding) y la del destino, que vive dentro de la destination.
- `Internet` para lo público, `OnPremise` para lo interno vía Cloud Connector.
- *Check Connection* no valida credenciales.
- CAP: `cds import` → `cds.requires.<nombre>` → `credentials.destination` en
  `[production]` → `cds.connect.to`.
- Para on-premise hacen falta dos servicios: destination y connectivity.

## Ejercicio

1. Crea una instancia `destination/lite` con una key, pide un token y llama a
   `subaccountDestinations`: `[]`. Crea la destination `NORTHWIND` del
   apartado 9.3 y repite la llamada. (Hecho en el trial el 2026-11-15.)
2. En bookshop, importa Northwind con `cds import`, configura el servicio
   externo y expón una entidad `Suppliers` que lo use. Despliega y llámala.
3. Cambia la URL de la destination a algo erróneo sin redesplegar y observa
   el error en `cf logs bookshop-srv`. Déjala bien. Acabas de ver por qué las
   destinations son configuración y no código.
