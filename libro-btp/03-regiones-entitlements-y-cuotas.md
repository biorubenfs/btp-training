# 3. Regiones, entitlements y cuotas

**Objetivo del capítulo.** Entender de dónde salen las URLs de BTP y por qué
un servicio aparece o no aparece en el marketplace.

## 3.1 Regiones y landscapes

Cada subcuenta vive en una **región**: un centro de datos de un hyperscaler
operado por SAP. Se elige al crear la subcuenta y no se puede cambiar.

| Término      | Significado                                                              | Ejemplo                                     |
|--------------|--------------------------------------------------------------------------|---------------------------------------------|
| Región       | Ubicación física + proveedor                                             | `us10` = AWS, EE. UU. Este (Virginia)       |
| Landscape    | Una instalación concreta de Cloud Foundry dentro de la región. Puede haber varias | `us10-001`                         |
| API endpoint | URL del Cloud Controller, la API REST a la que habla `cf`               | `https://api.cf.us10-001.hana.ondemand.com` |
| Dominio de apps | Dominio bajo el que se publican las routes de tus apps                | `cfapps.us10-001.hana.ondemand.com`         |

Las regiones más habituales en empresas europeas:

| Código | Proveedor | Ubicación                 |
|--------|-----------|---------------------------|
| `eu10` | AWS       | Frankfurt                 |
| `eu20` | Azure     | Países Bajos              |
| `eu30` | GCP       | Frankfurt                 |
| `us10` | AWS       | Virginia (la del trial)   |
| `us20` | Azure     | Washington                |

La lista completa, con qué servicios hay en cada una, está en el Discovery
Center (`discovery-center.cloud.sap`). Antes de prometer un servicio a un
proyecto, comprueba que existe en la región de su subcuenta.

## 3.2 Anatomía de las URLs

Casi todas las URLs de BTP se leen igual. El API endpoint:

```
https://api . cf . us10-001 . hana.ondemand.com
         │     │      │              └─ dominio de SAP BTP
         │     │      └─ landscape (región us10, instalación 001)
         │     └─ entorno Cloud Foundry
         └─ API del Cloud Controller
```

La route de una aplicación desplegada:

```
https://7b6c2113trial-dev-bookshop . cfapps . us10-001 . hana.ondemand.com
        └──────────┬─────────────┘   └──┬─┘   └───┬──┘
        nombre de host (único en        apps      landscape
        la región; CF lo compone con    de CF
        org-space-app para evitar
        colisiones)
```

El servidor de tokens de la subcuenta (XSUAA, capítulo 8):

```
https://7b6c2113trial . authentication . us10 . hana.ondemand.com
        └─────┬──────┘   └──────┬──────┘   └┬─┘
        subdominio de la    servicio de     región (sin landscape)
        subcuenta           autenticación
```

Saber leer estas URLs ahorra mucho tiempo depurando: si un token viene de
`eu10` y la app está en `us10`, no va a funcionar, y lo ves en la URL.

> **Analogía.** Como las regiones de AWS (`us-east-1`), con un endpoint de API
> por región. La diferencia es que en BTP la región se fija a nivel de
> subcuenta, no de cada recurso: todo lo de una subcuenta está en la misma
> región.

## 3.3 Entitlements

Un **entitlement** es el derecho de una subcuenta a usar **un servicio con un
plan concreto**. Sin él, el servicio ni siquiera aparece como opción.

> **Idea clave.** El contrato da a la cuenta global una bolsa de servicios. El
> administrador reparte esa bolsa entre subcuentas. Solo entonces el servicio
> aparece en el marketplace de la subcuenta.
> **Entitlement** = qué servicio y qué plan. **Cuota** (*quota*) = cuánto:
> unidades, instancias, GB.

```
   CONTRATO                   REPARTO                        USO
   Cuenta global con     ──▶  1 unidad → ventas-dev     ──▶  En cada subcuenta
   2 unidades de HANA         1 unidad → ventas-prod         ya se puede crear
   Cloud                                                     una instancia HANA

   Cuenta global con     ──▶  "sin límite" → ventas-dev ──▶  Cada app crea los
   hana / hdi-shared          "sin límite" → ventas-prod     contenedores que
                                                             necesite
```

> **Analogía.** Un presupuesto por departamentos. La empresa compra licencias
> y el administrador decide cuántas recibe cada equipo. Un equipo sin licencia
> no puede usar el producto aunque la empresa lo tenga.

### Los entitlements que necesita una app CAP

| Servicio (nombre técnico) | Plan          | Nombre en el marketplace                    | Para qué                                  |
|---------------------------|---------------|---------------------------------------------|-------------------------------------------|
| `hana-cloud`              | `hana` (trial: `hana-free`) | SAP HANA Cloud                 | El servidor de base de datos (uno por subcuenta) |
| `hana`                    | `hdi-shared`  | SAP HANA Schemas & HDI Containers           | Un contenedor HDI (esquema) por app       |
| `xsuaa`                   | `application` | Authorization and Trust Management Service  | Login y autorización de la app            |
| `destination`             | `lite`        | Destination Service                         | Conexiones a sistemas externos            |
| `connectivity`            | `lite`        | Connectivity Service                        | Salida hacia sistemas on-premise          |
| `html5-apps-repo`         | `app-host`, `app-runtime` | HTML5 Application Repository    | Alojar UIs Fiori (si no usas approuter)   |

En el trial ya vienen asignados. En una empresa los gestiona el administrador
de la cuenta global, y **pedirlos es el primer trámite de cualquier proyecto
nuevo**. Si el `cf deploy` falla diciendo que el plan `hdi-shared` del
servicio `hana` no existe, no es un problema de tu código: es un entitlement
que falta en esa subcuenta.

## 3.4 Ejemplo: ver los entitlements del trial

> **Cockpit:** Subcuenta › Derechos (*Subaccount › Entitlements*). Lista los
> servicios y planes asignados a esta subcuenta con su cuota.
>
> **Cockpit:** Cuenta global › Derechos › Asignaciones de entidades (*Global
> Account › Entitlements › Entity Assignments*). Desde aquí el administrador
> reparte. Selecciona la subcuenta y pulsa *Configure Entitlements*.

Desde la CLI de Cloud Foundry no se ven los entitlements de BTP, pero sí su
consecuencia, el marketplace del space:

```bash
cf marketplace
```

```
Getting all service offerings from marketplace in org 7b6c2113trial / space dev as ********...

offering                     plans                                     description
destination                  lite                                      Provides a secure and reliable access to destination and certificate configuration
hana                         hdi-shared, schema, securestore           SAP HANA Schemas & HDI Containers
xsuaa                        application, broker, apiaccess, space     Manage application authorizations and trust to identity providers
connectivity                 lite                                      Establishes secure, reliable connectivity between cloud applications and on-premise systems
application-logs             lite                                      Streams logs of bound Cloud Foundry applications
...
```

Y el detalle de un servicio con sus planes:

```bash
cf marketplace -e hana
```

```
Getting service plan information for service offering hana in org 7b6c2113trial / space dev as ********...

broker: hana-broker
   plan          description                                                                free or paid
   hdi-shared    An isolated HDI container with a technical user for runtime access         free
   schema        A plain schema with a technical user                                       free
   securestore   A secure store for credentials                                             free
```

La CLI `btp` sí ve los entitlements directamente:

```bash
btp list accounts/entitlement --subaccount <id>
```

> **Pendiente de validar.** La `btp` CLI se instala en el capítulo 14. El
> comando anterior está tomado de su documentación.

## 3.5 Cuotas de Cloud Foundry

Además de los entitlements de BTP, la org de Cloud Foundry tiene su propia
**cuota**: memoria total, número de instancias de servicio, routes. En el
trial es pequeña y hay que tenerla en cuenta al desplegar.

```bash
cf org 7b6c2113trial
```

```
Getting info for org 7b6c2113trial as ********...

name:            7b6c2113trial
domains:         cfapps.us10-001.hana.ondemand.com, ...
quota:           trial
spaces:          dev
isolation segments:
```

```bash
cf org-quota trial
```

```
Getting quota trial info as ********...

total memory:            4G
instance memory:         unlimited
routes:                  100
service instances:       50
paid service plans:      disallowed
app instances:           unlimited
route ports:             unlimited
log volume per second:   unlimited
```

> **Pendiente de validar.** Los números exactos de la cuota del trial se
> confirmarán al ejecutar el comando. Lo importante: el total de memoria es
> compartido por todas las apps del space, así que `memory: 256M` en
> `mta.yaml` no es un detalle estético.

## 3.6 Modelos comerciales que oirás

| Modelo                      | Qué es                                                                                 |
|-----------------------------|----------------------------------------------------------------------------------------|
| Trial                       | Cuenta gratuita de aprendizaje, con caducidad y recursos limitados. El cockpit muestra la fecha de caducidad |
| Free tier                   | Planes marcados `free` en una cuenta de pago, para probar sin coste                     |
| CPEA / BTPEA / Pay-As-You-Go| Consumo. La empresa compra crédito y cada servicio lo va gastando. Es lo que pone nervioso a operaciones cuando dejas una HANA encendida sin usar |
| Subscription                | Precio fijo por servicio y periodo                                                      |

## 3.7 Trampas

> **Trampa.** "El servicio no aparece en el marketplace" casi siempre es un
> entitlement sin asignar a esta subcuenta. Antes de abrir un ticket, mira
> Subcuenta › Derechos y compara con la lista del apartado 3.3.

> **Trampa.** El entitlement puede estar asignado y aun así fallar la creación
> si la **cuota** se ha agotado: por ejemplo, una unidad de `hana-cloud` ya
> consumida por la instancia existente. El error habla de *quota exceeded*.

> **Trampa.** `hana-cloud` y `hana` son servicios distintos. El primero crea
> el servidor; el segundo, los contenedores dentro de él. Los dos hacen falta
> (capítulo 7).

## Para recordar

- Región = dónde están los datos. Importa para latencia y para la ley (RGPD →
  `eu10`, `eu20`…).
- Landscape = instalación concreta dentro de la región (`us10-001`). Aparece
  en el API endpoint y en el dominio de las apps.
- Entitlement = servicio + plan permitidos en una subcuenta. Cuota = cuánto.
- Una app CAP necesita como mínimo `hana-cloud`, `hana/hdi-shared` y
  `xsuaa/application`. Pedirlos es el primer trámite de un proyecto.
- `cf marketplace` muestra la consecuencia de los entitlements en el space.

## Ejercicio

1. En Subcuenta › Derechos, anota los servicios y planes asignados al trial.
   Compara la lista con `cf marketplace`. ¿Hay algo en una y no en la otra?
   ¿Por qué? (pista: suscripciones).
2. Lee por partes el API endpoint y el dominio de apps de tu trial.
3. Busca en el Discovery Center en qué regiones está disponible SAP HANA
   Cloud y qué planes tiene.
