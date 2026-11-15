# Parte II. Servicios

# 5. Servicios, instancias y suscripciones

**Objetivo del capítulo.** Entender el ciclo de vida de un servicio en BTP y
distinguir las dos formas de "contratar" algo: una instancia para tu código y
una suscripción para las personas.

## 5.1 Servicio, plan, instancia

En BTP casi todo es un **servicio** del catálogo, y lo que creas a partir de
él es una **instancia**. La misma palabra cubre cosas muy distintas, así que
conviene fijar las tres piezas:

| Término               | Qué es                                                          | Analogía de programación             |
|-----------------------|-----------------------------------------------------------------|--------------------------------------|
| Servicio (*offering*) | Una oferta del catálogo (Service Marketplace)                   | Una clase                            |
| Plan                  | Variante del servicio: tamaño, precio, funciones                | Los parámetros del constructor       |
| Instancia             | Un recurso concreto creado para ti, con nombre y credenciales   | Un objeto: `new Destination("lite")` |

> **Idea clave.** Ante cualquier "instancia", pregúntate siempre: **¿instancia
> de qué servicio y con qué plan?** La respuesta cambia por completo lo que
> tienes delante.

| Servicio / plan           | La instancia es…                                      |
|---------------------------|-------------------------------------------------------|
| `hana-cloud`              | Un servidor de base de datos entero                   |
| `hana` / `hdi-shared`     | Un esquema aislado (contenedor HDI) para una app      |
| `destination` / `lite`    | Un almacén de conexiones a sistemas externos          |
| `xsuaa` / `application`   | La configuración de seguridad (cliente OAuth2) de tu app |
| `application-logs` / `lite` | Un sumidero de logs con su Kibana                   |

Quien crea las instancias es el **service broker** del servicio. Cuando pides
"una instancia de `hana` plan `hdi-shared`", el broker de HANA recibe la orden,
crea los esquemas y usuarios, y devuelve las credenciales. Tú no ves el
broker, pero aparece en la columna `broker` de `cf services` y en algunos
mensajes de error.

## 5.2 Instancia frente a suscripción

Esta es la distinción que más cuesta al principio porque las dos viven en la
misma pantalla del cockpit.

|                       | Instancia de servicio                                   | Suscripción                                                 |
|-----------------------|---------------------------------------------------------|-------------------------------------------------------------|
| Qué obtienes          | Un recurso técnico que usan **tus apps**                | Acceso a una **aplicación SaaS** de SAP que usan **personas** |
| Cómo se usa           | Con credenciales (binding o service key)                | Abriendo una URL en el navegador                             |
| Dónde vive            | Normalmente en un space de CF                           | En la subcuenta                                              |
| Qué necesitas además  | Nada: la app recibe las credenciales                    | Una **role collection** asignada a tu usuario                |
| ¿Sale en `cf services`? | Sí                                                    | No                                                           |
| Ejemplos              | contenedor HDI, XSUAA, Destination                      | HANA Cloud Central, Business Application Studio, Build Work Zone |

> **Analogía.** Una instancia es como contratar una base de datos en RDS: te
> dan host y contraseña y tu código se conecta. Una suscripción es como darte
> de alta en Jira Cloud: no gestionas nada, entras por URL si tienes permiso.

```
        INSTANCIA                              SUSCRIPCIÓN
  ┌──────────────────┐                    ┌──────────────────────┐
  │ Marketplace      │                    │ Marketplace          │
  │  └ crear instancia│                   │  └ crear suscripción │
  └────────┬─────────┘                    └──────────┬───────────┘
           ▼                                         ▼
  ┌──────────────────┐                    ┌──────────────────────┐
  │ bookshop-db      │                    │ SAP HANA Cloud (tools)│
  │ (hana/hdi-shared)│                    │ URL: hana-cockpit... │
  └────────┬─────────┘                    └──────────┬───────────┘
           │ binding / service key                   │ role collection
           ▼                                         ▼
  ┌──────────────────┐                    ┌──────────────────────┐
  │ bookshop-srv     │                    │ yo, en el navegador  │
  │ (mi código)      │                    │                      │
  └──────────────────┘                    └──────────────────────┘
```

> **Cockpit:** Subcuenta › Servicios › Instancias y suscripciones (*Services ›
> Instances and Subscriptions*). Tiene dos pestañas o dos bloques, uno por
> cada tipo. Las suscripciones tienen un enlace "Ir a la aplicación"; las
> instancias tienen un menú con "Crear clave de servicio".

## 5.3 El ciclo de vida de una instancia

```
  1. ENTITLEMENT      el admin asigna servicio+plan a la subcuenta (cap. 3)
         │
         ▼
  2. CREAR            marketplace → plan → runtime (CF → space) → nombre
                      → parámetros opcionales (JSON)
         │
         ▼
  3. USAR             BINDING a una app (VCAP_SERVICES)        ─┐
                      o SERVICE KEY para usarla desde fuera     ├─ cap. 6
         │                                                     ─┘
         ▼
  4. BORRAR           primero unbind / borrar keys, después la instancia
```

### Crear una instancia

> **Cockpit:** Subcuenta › Servicios › Marketplace de servicios › (servicio) ›
> Crear (*Service Marketplace › Create*). El asistente pide plan, runtime
> (Cloud Foundry y entonces un space), nombre y, opcionalmente, parámetros
> en JSON.

```bash
cf create-service destination lite dest-test
```

```
Creating service instance dest-test in org 7b6c2113trial / space dev as ********...

Service instance dest-test created.
OK
```

Con parámetros (para XSUAA, el JSON es tu `xs-security.json`):

```bash
cf create-service xsuaa application bookshop-auth -c xs-security.json
```

Algunos brokers crean la instancia de forma asíncrona. Entonces la CLI
devuelve enseguida y hay que mirar el estado:

```bash
cf service dest-test
```

```
Showing info of service dest-test in org 7b6c2113trial / space dev as ********...

name:            dest-test
guid:            2a5d502f-....
type:            managed
broker:          destination-service-broker
offering:        destination
plan:            lite
tags:            destination, conn, connsvc
offering tags:   destination, conn, connsvc
description:     Provides a secure and reliable access to destination and certificate configuration
documentation:   https://help.sap.com/...
dashboard url:

Showing status of last operation:
   status:    create succeeded
   message:
   started:   2026-11-13T18:40:12Z
   updated:   2026-11-13T18:40:14Z

Showing bound apps:
There are no bound apps for this service instance.

Showing sharing info:
This service instance is not currently being shared.

Showing upgrade status:
There is no upgrade available for this service.
```

### Borrar una instancia

El orden es obligatorio: primero lo que depende de ella, después ella.

```bash
cf delete-service-key dest-test key1 -f
cf unbind-service bookshop-srv dest-test      # si estuviera ligada a una app
cf delete-service dest-test -f
```

Si lo intentas al revés:

```
Cannot delete service instance. Service keys, bindings, and shares must first be deleted.
```

El cockpit se niega igual, con un mensaje parecido.

## 5.4 Los servicios que verás en todos los proyectos CAP

| Servicio (marketplace)                        | Técnico / plan              | Tipo        | Para qué                                                                  |
|-----------------------------------------------|-----------------------------|-------------|---------------------------------------------------------------------------|
| SAP HANA Cloud                                | `hana-cloud` + suscripción `tools` | Instancia + suscripción | La base de datos. Se administra desde HANA Cloud Central. **En el trial se apaga cada noche** |
| SAP HANA Schemas & HDI Containers             | `hana` / `hdi-shared`       | Instancia   | Un esquema aislado dentro de la HANA para tu app. Lo despliega el `db-deployer` |
| Authorization and Trust Management Service    | `xsuaa` / `application`     | Instancia   | Login OAuth2 y autorización. Tu `xs-security.json` se convierte en roles aquí |
| Destination Service                           | `destination` / `lite`      | Instancia   | Acceso programático a las destinations de la subcuenta                     |
| Connectivity Service                          | `connectivity` / `lite`     | Instancia   | Salida hacia sistemas on-premise a través del Cloud Connector              |
| SAP Business Application Studio               | suscripción                 | Suscripción | IDE web basado en VS Code                                                 |
| SAP Build Work Zone, standard edition         | suscripción + `html5-apps-repo` | Ambos   | El launchpad Fiori donde el usuario encuentra las apps                     |
| Application Logging / SAP Cloud Logging       | `application-logs` / `lite` | Instancia   | Centraliza logs con Kibana u OpenSearch                                   |
| Job Scheduling Service                        | `jobscheduler`              | Instancia   | Cron gestionado que llama a endpoints de tu app                            |
| Alert Notification                            | `alert-notification`        | Instancia   | Avisos por correo, Slack o Teams cuando una app se cae                     |
| Credential Store                              | `credstore`                 | Instancia   | Guardar secretos fuera del código                                          |
| Event Mesh                                    | `enterprise-messaging`      | Instancia   | Mensajería asíncrona. CAP lo soporta de forma nativa                      |
| Cloud Transport Management                    | suscripción                 | Suscripción | Mover MTAs de dev a qa a prod de forma controlada                          |

> **Para un dev CAP.** Abre el `mta.yaml` de cualquier proyecto y mira la
> sección `resources`. Cada entrada con `type: org.cloudfoundry.managed-service`
> (o `com.sap.xs.hdi-container`) es una instancia que verás en *Instancias y
> suscripciones* con ese mismo nombre. Los campos `service` y `service-plan`
> son el nombre técnico y el plan de esta tabla. El capítulo 11 lo recorre
> con el `mta.yaml` real de bookshop.

## 5.5 Ejemplo real: la instancia de Destination del trial

Lo que se hizo en el trial el 13 de noviembre, paso a paso, con las dos vías:

| Paso | Cockpit                                                                                  | CLI                                              |
|------|------------------------------------------------------------------------------------------|--------------------------------------------------|
| 1    | Marketplace › Destination Service › Crear › plan `lite` › space `dev` › nombre `dest-test` | `cf create-service destination lite dest-test`  |
| 2    | Instancias y suscripciones: aparece `dest-test`, estado *Creado*                          | `cf services`                                    |
| 3    | `dest-test` › Crear clave de servicio › `key1`                                            | `cf create-service-key dest-test key1`           |
| 4    | `key1` › Ver: aparece el JSON con `clientid`, `clientsecret`, `url`, `uri`                | `cf service-key dest-test key1`                  |
| 5    | Borrar `key1`, después borrar `dest-test`                                                  | `cf delete-service-key dest-test key1 -f` y `cf delete-service dest-test -f` |

Observaciones que salieron de hacerlo:

- La instancia **sí** aparece en `cf services`, porque vive en el space `dev`.
  La suscripción a HANA Cloud Central, creada el mismo día, **no** aparece,
  porque vive en la subcuenta.
- El JSON de la service key tiene exactamente la forma de lo que una app
  recibiría por binding en `VCAP_SERVICES`. El capítulo 6 lo analiza campo a
  campo.
- El cockpit no permitió borrar la instancia mientras existía la key.

## 5.6 Suscripciones: el patrón que se repite

**Suscripción + role collection asignada = puedes usar la app.**

El booster de herramientas de HANA Cloud creó la suscripción a SAP HANA Cloud
(plan `tools`) **y** asignó la role collection *SAP HANA Cloud Administrator*
al usuario. Sin lo segundo, al abrir HANA Cloud Central se vería "no
autorizado".

> **Cockpit:** Subcuenta › Servicios › Instancias y suscripciones › (pestaña
> Suscripciones) › SAP HANA Cloud › Ir a la aplicación.

Lo mismo pasará con cualquier app SaaS de SAP y, en el capítulo 8, con tu
propia app CAP: declaras un scope, se crea un rol, lo metes en una role
collection y te la asignas.

## 5.7 Boosters

Un **booster** es un asistente guiado del cockpit que hace por ti varios pasos
de configuración seguidos: asignar entitlements, crear suscripciones o
instancias, crear role collections y asignártelas.

> **Cockpit:** Cuenta global › Boosters (*Global Account › Boosters*).

El booster no deja nada propio. Deja exactamente lo mismo que si lo hubieras
hecho tú a mano, por eso después de usarlo conviene recorrer *Derechos*,
*Instancias y suscripciones* y *Colecciones de roles* y apuntar qué cambió.

| Lo que hizo el booster "SAP HANA Cloud administration tools"  | Dónde se ve                                 |
|---------------------------------------------------------------|---------------------------------------------|
| Suscripción a SAP HANA Cloud (plan `tools`)                   | Subcuenta › Instancias y suscripciones      |
| Role collection *SAP HANA Cloud Administrator* asignada       | Subcuenta › Seguridad › Usuarios            |

> **En el trial.** El booster "Prepare an Account for Developing with CAP" que
> citan muchos tutoriales **ya no existe** en el trial. El equivalente es
> ejecutar el de herramientas de HANA Cloud y comprobar que los entitlements
> de `hana`, `xsuaa` y `destination` están asignados (en el trial lo están).

> **Analogía.** Un booster es una plantilla de CloudFormation o un script de
> setup: cómodo, pero conviene saber qué ha creado para poder mantenerlo o
> repetirlo a mano en una cuenta donde no haya boosters.

## 5.8 Trampas

> **Trampa.** Intentar borrar una instancia con keys o bindings vivos. Orden:
> keys y bindings primero, instancia después.

> **Trampa.** Buscar una suscripción con `cf services`. No está ahí: las
> suscripciones son de BTP, no de Cloud Foundry. Mira el cockpit o
> `btp list accounts/subscription`.

> **Trampa.** Abrir una app suscrita y ver "no autorizado". Falta la role
> collection. Y tras asignarla, cierra sesión y vuelve a entrar para que el
> token se renueve.

> **Trampa.** Crear instancias a mano en el cockpit y luego desplegar con
> `mta.yaml`. Si los nombres coinciden, `cf deploy` reutiliza la instancia y
> puede intentar actualizarla con otros parámetros. Si no coinciden, acabas
> con dos. Elige una vía: en proyectos CAP, la vía es `mta.yaml`.

## Para recordar

- Servicio → plan → instancia, igual que clase → parámetros → objeto. Siempre
  pregunta "¿instancia de qué?".
- Instancia = para tus apps (credenciales, vive en un space, sale en
  `cf services`). Suscripción = para personas (URL + role collection, vive en
  la subcuenta).
- Ciclo: entitlement → crear → binding o key → borrar en orden inverso.
- Los cuatro imprescindibles de CAP: `hana-cloud`, `hana/hdi-shared`,
  `xsuaa/application`, `destination/lite`.
- Booster = atajo. Después de usarlo, revisa qué creó.

## Ejercicio

1. Crea con `cf create-service destination lite dest-test` una instancia, mírala
   con `cf service dest-test` y localízala en el cockpit. Bórrala desde el
   cockpit.
2. Haz lo contrario: crea otra desde el cockpit y bórrala con la CLI. Intenta
   borrarla con una key creada y lee el mensaje de error.
3. Abre SAP HANA Cloud Central desde la suscripción. Comprueba si la instancia
   está *Running* o *Stopped* y arráncala si hace falta.
