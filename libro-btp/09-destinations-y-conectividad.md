# 9. Destinations y conectividad

**Objetivo del capítulo.** Saber cómo una app en BTP habla con un S/4HANA, con
una API externa o con otra app sin URLs ni credenciales en el código.

## 9.1 Qué es una destination

Una **destination** es una conexión con nombre que vive en la subcuenta: URL,
tipo de autenticación, credenciales y propiedades adicionales. Tu código pide
"la destination `S4_SALES`" y el Destination Service le devuelve la URL y un
token o cabecera de autenticación ya resueltos.

```
  bookshop-srv                 Destination Service          Sistema destino
      │                              │                             │
      │ "dame NORTHWIND"             │                             │
      │ ────────────────────────────▶│                             │
      │ { URL, Authentication,       │                             │
      │   authTokens: [...] }        │                             │
      │ ◀────────────────────────────│                             │
      │                                                            │
      │ GET https://services.odata.org/... (+ cabecera de auth)    │
      │ ──────────────────────────────────────────────────────────▶│
```

Ventajas: la misma app funciona en dev, qa y prod apuntando a sistemas
distintos (cada subcuenta tiene su propia `S4_SALES`), y las credenciales no
están ni en el código ni en variables de entorno de la app.

> **Analogía.** Un pool de conexiones JNDI configurado en el servidor de
> aplicaciones, o un fichero de configuración por entorno, pero gestionado
> por la plataforma y con OAuth2 incorporado.

## 9.2 Crear una destination

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

Ejemplo para el ejercicio, un OData público de pruebas:

```
Name:            NORTHWIND
Type:            HTTP
URL:             https://services.odata.org
Proxy Type:      Internet
Authentication:  NoAuthentication
```

> **Trampa.** El botón *Comprobar conexión* (*Check Connection*) solo prueba
> que el host se alcanza. No valida credenciales ni rutas. Un "200 OK" ahí no
> garantiza nada más que DNS y red.

Con la API REST, usando la service key del capítulo 6:

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

Si la destination tuviera `OAuth2ClientCredentials`, la respuesta incluiría
`authTokens` con un token ya pedido al sistema destino. Eso es lo que te
ahorra el servicio.

## 9.3 Destinations de subcuenta y de instancia

Hay dos ámbitos:

| Ámbito        | Dónde se crea                                           | Quién la ve                                    |
|---------------|---------------------------------------------------------|------------------------------------------------|
| Subcuenta     | Conectividad › Destinos                                 | Todas las apps de la subcuenta                 |
| Instancia     | Instancias y suscripciones › (instancia destination) › Destinos | Solo las apps ligadas a esa instancia  |

Las de subcuenta son las normales. Las de instancia se usan cuando una app
quiere sus destinations privadas. En la respuesta de la API, `owner` dice
cuál es.

## 9.4 Cloud Connector

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

## 9.5 Consumir una destination desde CAP

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

## 9.6 Trampas

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
- `Internet` para lo público, `OnPremise` para lo interno vía Cloud Connector.
- *Check Connection* no valida credenciales.
- CAP: `cds import` → `cds.requires.<nombre>` → `credentials.destination` en
  `[production]` → `cds.connect.to`.
- Para on-premise hacen falta dos servicios: destination y connectivity.

## Ejercicio

1. Crea la destination `NORTHWIND` del apartado 9.2. Léela con la API REST
   usando una service key de una instancia `destination/lite`.
2. En bookshop, importa Northwind con `cds import`, configura el servicio
   externo y expón una entidad `Suppliers` que lo use. Despliega y llámala.
3. Cambia la URL de la destination a algo erróneo sin redesplegar y observa
   el error en `cf logs bookshop-srv`. Déjala bien. Acabas de ver por qué las
   destinations son configuración y no código.
