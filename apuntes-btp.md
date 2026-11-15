# Apuntes de SAP BTP

Notas conceptuales del curso, escritas mientras lo hacemos. Cada concepto tiene:

- **Idea clave**: lo esencial en una o dos frases.
- **Analogía**: con cosas conocidas del backend o de AWS.
- **Ejemplo**: con los valores reales de mi trial.
- **Para recordar**: resumen final.
- **Trampa típica**: errores habituales, cuando los hay.

> Trial en AWS **us10** · Módulos cubiertos: **00–05** · Actualizado: **2026-11-13**

---

## Índice

0. BTP en una página
1. Jerarquía de cuentas
2. Regiones y endpoints
3. Entitlements y cuotas
4. Entornos de ejecución
5. Servicios, planes e instancias
6. Usuarios y roles
7. Bindings y service keys
8. SAP HANA Cloud
9. Boosters
10. Diario del curso
11. Glosario

---

## 0. BTP en una página

SAP Business Technology Platform es la nube de SAP para construir y ejecutar
aplicaciones alrededor de sus productos (S/4HANA, SuccessFactors…). No es un
proveedor de infraestructura propio: corre **encima** de AWS, Azure o Google
Cloud y añade una capa de plataforma con servicios de SAP.

> **Idea clave.** En BTP casi todo se reduce a cuatro preguntas:
>
> - **¿Dónde?** → jerarquía de cuentas y región (secciones 1 y 2)
> - **¿Qué puedo usar?** → entitlements (sección 3)
> - **¿Qué he creado?** → instancias y suscripciones (secciones 5, 7 y 8)
> - **¿Quién puede hacer qué?** → role collections (sección 6)

| Concepto BTP        | Lo más parecido en AWS         | Matiz                                          |
|---------------------|--------------------------------|------------------------------------------------|
| Cuenta global       | AWS Organization               | El contrato con SAP; agrupa todo y factura     |
| Subaccount          | Una cuenta AWS de la Org       | Vive en una sola región; unidad de aislamiento |
| Cloud Foundry       | Elastic Beanstalk / Heroku     | PaaS: subes código y la plataforma lo ejecuta  |
| Service Marketplace | Consola de servicios de AWS    | Catálogo de lo que puedes instanciar           |
| SAP HANA Cloud      | RDS / Aurora                   | Base de datos gestionada                       |
| XSUAA               | Cognito                        | Emite tokens OAuth2 para apps y servicios      |
| Role collection     | Grupo de políticas IAM         | Se asigna a usuarios para darles permisos      |

Las analogías ayudan a ubicarse, pero no son exactas. Cuando no encajen, gana
la definición de BTP.

---

## 1. Jerarquía de cuentas

Todo lo que creas en BTP cuelga de un árbol. Saber en qué nivel estás explica
la mayoría de los "no lo encuentro" del cockpit.

### Diagrama (mi trial)

```
┌─ CUENTA GLOBAL ────────────────────────────────────────────────────┐
│  contrato · facturación · reparto de entitlements                  │
│                                                                    │
│  ┌─ SUBACCOUNT "trial" ─────────────────────────────────────────┐  │
│  │  región us10 · subdominio 7b6c2113trial                      │  │
│  │                                                              │  │
│  │  A nivel subaccount:                                         │  │
│  │   · suscripciones (SAP HANA Cloud Central)                   │  │
│  │   · instancia de SAP HANA Cloud (el servidor de BD)          │  │
│  │   · usuarios y role collections                              │  │
│  │   · destinations                                             │  │
│  │                                                              │  │
│  │  ┌─ ORG CLOUD FOUNDRY "7b6c2113trial" (una por subaccount) ┐ │  │
│  │  │                                                         │ │  │
│  │  │  ┌─ SPACE "dev" ──────────┐   ┌─ SPACE "prod" ───────┐  │ │  │
│  │  │  │ apps:                  │   │ (ejemplo, no existe) │  │ │  │
│  │  │  │  bookshop-srv…         │   │ sus propias apps e   │  │ │  │
│  │  │  │ instancias de servicio:│   │ instancias, aisladas │  │ │  │
│  │  │  │  HDI, xsuaa, dest…     │   │ de dev               │  │ │  │
│  │  │  └────────────────────────┘   └──────────────────────┘  │ │  │
│  │  └─────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌─ OTRA SUBACCOUNT (ejemplo) "prod-eu10" en Frankfurt ─────────┐  │
│  │  sus propios usuarios, roles, servicios y su propia org CF   │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

### Los niveles, de arriba abajo

| Nivel                   | Qué es                                                                                       | En mi trial                              |
|-------------------------|----------------------------------------------------------------------------------------------|------------------------------------------|
| Cuenta global           | Lo que contratas con SAP. Desde aquí se crean subaccounts y se reparten entitlements.        | La cuenta trial                          |
| Directorio (opcional)   | Carpeta para agrupar subaccounts, por ejemplo por departamento. Las trials no suelen usarlos. | —                                        |
| Subaccount              | Unidad de aislamiento: **una región**, sus usuarios, roles y servicios. Tiene un **subdominio** que aparece en URLs y tokens. | `trial` en us10, subdominio `7b6c2113trial` |
| Entorno (org CF)        | Al activar Cloud Foundry en la subaccount se crea **una** org.                               | `7b6c2113trial`                          |
| Space                   | Subdivisión de la org donde viven apps e instancias. Separa entornos o equipos.              | `dev`                                    |

> **Analogía.** Una empresa (cuenta global) con oficinas en distintas ciudades
> (subaccounts por región). Cada oficina tiene un edificio de Cloud Foundry
> (org) con varias plantas (spaces). En cada planta trabajan tus apps. Algunas
> cosas son de la oficina entera, como la base de datos o el control de
> accesos, y no de una planta concreta.

### Ejemplo: cómo se organizaría una empresa

Un patrón habitual es **una subaccount por etapa**, porque así cada etapa tiene
usuarios, roles y base de datos separados:

```
Cuenta global "ACME"
├── Subaccount acme-dev   (eu10) → org → space dev
├── Subaccount acme-qa    (eu10) → org → space qa
└── Subaccount acme-prod  (eu10) → org → space prod
```

En la trial solo hay una subaccount, así que simularemos "producción" con lo
que tenemos.

> **Trampa típica.** El cockpit muestra cosas distintas según el nivel. Las
> role collections de la cuenta global (Global Account Administrator/Viewer)
> no son las de la subaccount (Subaccount Administrator, SAP HANA Cloud
> Administrator…). Si no encuentras algo, mira la ruta de navegación de
> arriba: ¿estás en la cuenta global o dentro de la subaccount?

**Para recordar**

- Cuenta global ⊃ subaccounts ⊃ una org de CF ⊃ spaces ⊃ apps e instancias.
- La subaccount es la frontera importante: región, usuarios, roles y servicios.
- Unas cosas viven en la subaccount (suscripciones, HANA Cloud) y otras en un
  space (apps, contenedores HDI).

---

## 2. Regiones y endpoints

Cada subaccount vive en una **región**: un centro de datos de un hyperscaler
operado por SAP. Se elige al crear la subaccount y no se cambia.

| Término      | Significado                                                                   | Ejemplo                                      |
|--------------|-------------------------------------------------------------------------------|----------------------------------------------|
| Región       | Ubicación física + proveedor                                                  | `us10` = AWS, EE. UU. Este (Virginia)        |
| Landscape    | Una instalación concreta de Cloud Foundry en la región. Puede haber varias.   | `us10-001`                                   |
| API endpoint | URL del Cloud Controller de CF, la API REST a la que habla el comando `cf`. Aparece en la vista general de la subaccount. | `https://api.cf.us10-001.hana.ondemand.com` |

Si lees la URL del endpoint por partes:

```
https://api . cf . us10-001 . hana.ondemand.com
         │     │      │              └─ dominio de SAP BTP
         │     │      └─ landscape (región us10, instalación 001)
         │     └─ entorno Cloud Foundry
         └─ API del Cloud Controller
```

> **Analogía.** Como las regiones de AWS (`us-east-1`), con un endpoint de API
> por región. La diferencia es que en BTP la región se fija a nivel de
> subaccount, no de cada recurso.

**Para recordar**

- Región → dónde están los datos. Importa para la latencia y para la ley
  (RGPD → regiones de la UE como `eu10`).
- El API endpoint es lo que necesita `cf login`. Sale de la página de la subaccount.

---

## 3. Entitlements y cuotas

Un **entitlement** es el permiso de la cuenta para usar **un servicio con un
plan concreto**. Sin él, el servicio ni siquiera aparece como opción.

> **Idea clave.** El contrato da a la cuenta global una bolsa de servicios, que
> se reparte entre subaccounts.
> **Entitlement** = qué servicio y plan. **Cuota** = cuánto (unidades, memoria,
> número de instancias).

```
 CONTRATO                   REPARTO                        USO
 Cuenta global con     ──▶  1 unidad → acme-dev       ──▶  En cada subaccount
 2 unidades de HANA         1 unidad → acme-prod           ya se puede crear
                                                           una instancia HANA
```

> **Analogía.** Un presupuesto por departamentos. La empresa compra licencias
> y el administrador decide cuántas recibe cada equipo. Un equipo sin licencia
> no puede usar el producto, aunque la empresa lo tenga.

### Entitlements que necesita una app CAP

| Servicio      | Plan          | Para qué                                  |
|---------------|---------------|-------------------------------------------|
| `hana-cloud`  | (el del trial)| El servidor de base de datos              |
| `hana`        | `hdi-shared`  | Un contenedor HDI (schema) para la app    |
| `xsuaa`       | `application` | Login y autorización de la app            |
| `destination` | `lite`        | Guardar conexiones a sistemas externos    |

En la trial ya vienen asignados. En una empresa los gestiona el administrador
de la cuenta global, y pedirlos suele ser el primer trámite de un proyecto.

**Para recordar**

- Entitlement = servicio + plan permitidos en una subaccount.
- "El servicio no aparece en el Marketplace" casi siempre significa que falta
  el entitlement.

---

## 4. Entornos de ejecución

El entorno es **dónde corre tu código**. Una subaccount puede activar varios.

| Entorno                   | Qué es                                                               | Cuándo se usa                            |
|---------------------------|----------------------------------------------------------------------|------------------------------------------|
| Cloud Foundry             | PaaS: subes código o un `.mtar` y CF construye, ejecuta, escala y reinicia | **El que usaremos.** Por defecto para CAP |
| Kyma                      | Kubernetes gestionado con extras de SAP                              | Contenedores propios o control fino      |
| ABAP environment          | ABAP en la nube                                                      | Equipos ABAP                             |
| Other / Multi-environment | Servicios que no pertenecen a ningún runtime                         | Por ejemplo, la instancia de HANA Cloud  |

> **Analogía.** Cloud Foundry es a BTP lo que Heroku a AWS. Tú haces `git push`
> (aquí, `cf deploy`) y te olvidas de servidores, sistemas operativos y
> balanceadores.

**Para recordar**

- CAP + Cloud Foundry es el camino estándar. Kyma es la alternativa con Kubernetes.
- CF tiene sus propios roles (Space Developer, Org Manager…), además de las
  role collections de BTP (sección 6).

---

## 5. Servicios, planes e instancias

En BTP casi todo es un **servicio** del catálogo, y lo que creas a partir de él
es una **instancia**. La misma palabra cubre cosas muy distintas.

> **Idea clave.** Ante cualquier "instancia", pregúntate siempre:
> **¿instancia de qué servicio y con qué plan?**

| Término               | Qué es                                                   | Analogía de programación          |
|-----------------------|----------------------------------------------------------|-----------------------------------|
| Servicio              | Una oferta del catálogo (Service Marketplace)            | Una clase                         |
| Plan                  | Variante del servicio: tamaño, precio, funciones         | Parámetros del constructor        |
| Instancia de servicio | Un recurso concreto creado para ti, con nombre y credenciales | Un objeto: `new Destination("lite")` |

Ejemplos de lo distinta que puede ser una "instancia":

| Servicio / plan           | La instancia es…                                   |
|---------------------------|----------------------------------------------------|
| `hana-cloud`              | Un servidor de base de datos entero                |
| `hana` / `hdi-shared`     | Un schema aislado (contenedor HDI) para una app    |
| `destination` / `lite`    | Un almacén de conexiones a sistemas externos       |
| `xsuaa` / `application`   | La configuración de seguridad de tu app            |

### Instancia vs suscripción

|                       | Instancia de servicio                         | Suscripción                                   |
|-----------------------|-----------------------------------------------|-----------------------------------------------|
| Qué obtienes          | Un recurso técnico que usan **tus apps**      | Acceso a una **aplicación SaaS** de SAP que usan personas |
| Cómo se usa           | Con credenciales (binding o service key)      | Abriendo una URL en el navegador              |
| Dónde vive            | Normalmente en un space de CF                 | En la subaccount                              |
| Qué necesitas además  | Nada: la app recibe las credenciales          | Una **role collection** asignada              |
| Ejemplo en mi trial   | `dest-test` (destination / lite)              | SAP HANA Cloud Central (plan `tools`)         |

> **Analogía.** Una instancia es como contratar una base de datos en RDS: te
> dan host y contraseña y tu código se conecta. Una suscripción es como darte
> de alta en Jira Cloud: no gestionas nada, entras por URL si tienes permiso.

### Ejemplo: lo que hicimos con Destination

1. **Crear la instancia**: Marketplace → Destination Service → plan `lite` →
   space `dev` → nombre `dest-test`.
2. **Aparece en CF**: `cf services` la muestra, porque vive en el space.
3. **Crear una service key** (`key1`): credenciales para usarla desde fuera
   (sección 7).
4. **Borrar**: primero la key, después la instancia. No se puede borrar una
   instancia con keys o bindings vivos.

**Para recordar**

- Servicio → plan → instancia, igual que clase → parámetros → objeto.
- Instancia = para tus apps (credenciales). Suscripción = para personas
  (URL + role collection).

---

## 6. Usuarios y roles

Los permisos en BTP se organizan en capas, y cada capa se gestiona en un sitio
distinto. Es la parte más confusa al principio.

### De la pieza más pequeña a la más grande

```
  SCOPE  ──▶  ROLE  ──▶  ROLE COLLECTION  ──▶  USUARIO
 permiso      agrupa      agrupa roles,          la recibe,
 atómico      scopes      incluso de apps        directamente o vía
 ("Admin")    (desde una  distintas.             grupos del Identity
 definido     role        ES LO QUE SE           Provider
 por la app   template)   ASIGNA
```

### Las tres capas de permisos

| Capa          | Ejemplos                                                           | Dónde se gestiona                                 |
|---------------|--------------------------------------------------------------------|---------------------------------------------------|
| Cuenta global | Global Account Administrator, Global Account Viewer                | Cockpit, nivel cuenta global › Seguridad          |
| Subaccount    | Subaccount Administrator, SAP HANA Cloud Administrator, las de tus apps (`Bookshop_Admin`) | Cockpit, dentro de la subaccount › Seguridad |
| Cloud Foundry | Org Manager, Space Developer, Space Manager, Auditor               | Cockpit › org o space › Miembros (no son role collections) |

> **Trampa típica.** Ser administrador de la cuenta global **no** da permisos
> automáticos dentro de una subaccount, ni en sus spaces. Cada capa se asigna
> por separado. En la trial SAP lo hace por ti; en una empresa, el primer día
> seguramente tendrás que pedir que te añadan.

### El patrón que se repite

**Suscripción + role collection asignada = puedes usar la app.**

El booster de HANA Cloud creó la suscripción a HANA Cloud Central **y** me
asignó la role collection *SAP HANA Cloud Administrator*. Sin lo segundo, al
abrirla vería "no autorizado".

Con mi app CAP pasará lo mismo (módulo 07): declararé un scope `Admin`, crearé
la role collection `Bookshop_Admin` y me la asignaré.

**Para recordar**

- Scope ⊂ role ⊂ role collection → usuario.
- Tres capas independientes: cuenta global, subaccount y Cloud Foundry.
- ¿"No autorizado"? Revisa la role collection en la subaccount correcta.

---

## 7. Bindings y service keys

Una instancia de servicio no sirve de nada si nadie puede llamarla. Hay dos
formas de obtener sus credenciales, y las dos dan **el mismo JSON**.

|                              | Binding                                         | Service key                                     |
|------------------------------|-------------------------------------------------|-------------------------------------------------|
| Para quién                   | Una app desplegada en CF                        | Cualquier cosa fuera de CF: portátil, Postman, otro sistema |
| Cómo llegan las credenciales | Variable de entorno `VCAP_SERVICES`, inyectada al arrancar la app | Las copias del cockpit o con `cf service-key` |
| Uso en CAP                   | CAP la lee sola en producción                   | Modo híbrido con `cds bind` (módulo 09)         |

> **Analogía.** Un binding es como las variables de entorno que Heroku inyecta
> al añadir un add-on (`DATABASE_URL`). Una service key es como generar una
> API key en un panel web para usarla tú desde fuera.

### Anatomía de la service key que creamos

JSON real de `dest-test / key1` (ya borrada), con valores recortados:

```json
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

| Campo                 | Qué significa                                                                  |
|-----------------------|--------------------------------------------------------------------------------|
| `clientid`            | El "usuario" OAuth2 del servicio                                               |
| `clientsecret`        | La "contraseña" OAuth2. Es secreto; deja de valer al borrar la key             |
| `credential-type`     | `binding-secret` = id + secreto. La alternativa es `x509` (certificados)       |
| `url`                 | **Servidor de tokens** (XSUAA) de mi subaccount. Lleva mi subdominio           |
| `uri`                 | **API REST** del servicio Destination. Aquí se llama con el token              |
| `identityzone`        | Subdominio de la subaccount: a qué "inquilino" pertenece el token              |
| `tenantid`/`instanceid` | IDs de la subaccount (tenant) y de esta instancia concreta                  |
| `uaadomain`           | Dominio de XSUAA en la región                                                  |
| `verificationkey`     | Clave pública para verificar la firma de los tokens JWT                        |
| `xsappname`           | Nombre interno de la "aplicación" OAuth2 que representa esta instancia         |

### Cómo se usan esas credenciales

Todos los servicios de BTP siguen el mismo flujo OAuth2, *client credentials*:

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

Con curl:

```bash
# 1. Token
curl -u "$CLIENTID:$CLIENTSECRET" \
  -d grant_type=client_credentials \
  "https://7b6c2113trial.authentication.us10.hana.ondemand.com/oauth/token"

# 2. Llamada a la API del servicio Destination
curl -H "Authorization: Bearer $TOKEN" \
  "https://destination-configuration.cfapps.us10.hana.ondemand.com/destination-configuration/v1/subaccountDestinations"
```

CAP y las librerías de SAP hacen esto por ti, pero conviene saberlo para depurar.

### Qué hay en `VCAP_SERVICES` para el contenedor HDI

Al desplegar, CF inyecta en la app la variable `VCAP_SERVICES`: un JSON con
una entrada por cada servicio bindeado, agrupadas por nombre de servicio. La
del contenedor HDI, recortada:

```json
{
  "hana": [{
    "name": "bookshop-db",
    "plan": "hdi-shared",
    "credentials": {
      "host": "xxxx.hana.trial-us10.hanacloud.ondemand.com",
      "port": "443",
      "user": "BOOKSHOP_DB_1_RT",
      "password": "…",
      "schema": "BOOKSHOP_DB_1",
      "certificate": "-----BEGIN CERTIFICATE-----…"
    }
  }]
}
```

Ahí están el usuario `_RT` y el esquema de runtime de la sección 8. CAP
arranca, busca la entrada de tipo `hana` y se conecta sin que configures nada.
Es la columna "Binding" de la tabla de arriba aplicada a HANA.

### Que una app CF llame a otra app CF

Es habitual ver una app que guarda la service key "de otra app" para
llamarla. Conviene afinar dos cosas:

1. **Una app no tiene service keys.** Solo las instancias de servicio las
   tienen. Lo que tenía la otra app era una instancia de `xsuaa` bindeada, y la
   key se creó de esa instancia.
2. **La key no da acceso a la app, da un token.** Contiene `clientid`,
   `clientsecret` y la `url` de XSUAA. Con eso pides un JWT por client
   credentials (el diagrama de arriba) y la app destino lo acepta porque lo
   emitió su propio XSUAA.

Hay tres maneras de montarlo:

| Forma                                   | Cómo llegan las credenciales a la app A                  | Cuándo tiene sentido                                        |
|-----------------------------------------|----------------------------------------------------------|-------------------------------------------------------------|
| Service key de la XSUAA de B            | Alguien la copia a mano en una variable de entorno de A  | Apps de equipos o subaccounts distintos. Es la versión "a mano" |
| Misma instancia de XSUAA bindeada a A y B | Ya están en `VCAP_SERVICES` de A por el binding         | A y B van en el mismo `mta.yaml`. No hace falta key           |
| Destination                             | A pide el destination por nombre; la librería SAP gestiona el token | La forma recomendada. Credenciales fuera del código (módulo de destinations) |

```
 A ── clientid/secret (key o binding) ──▶ XSUAA de B ── JWT ──▶ A ── Bearer JWT ──▶ B
```

La primera opción funciona, pero hereda la trampa de abajo: una credencial
real que no caduca y que alguien tiene que rotar.

> **Trampa típica.** Una service key es una credencial real y no caduca sola.
> Bórrala cuando ya no la uses y no la subas a git. En CAP, `cds bind` guarda
> solo una referencia a la key, no el secreto.

**Para recordar**

- Binding = credenciales para una app en CF (`VCAP_SERVICES`).
  Service key = credenciales para usar fuera.
- `url` = dónde pido el token. `uri` = dónde uso el token.
- Las apps no tienen service keys, las tienen sus instancias de XSUAA. Para
  que A llame a B: mismo XSUAA si comparten `mta.yaml`, destination si no.
- Orden de borrado: keys y bindings primero, la instancia después.

---

## 8. SAP HANA Cloud

> **Idea clave.** "Instancia de SAP HANA Database" **no** es la base de datos de
> mi app. Es el **servidor de base de datos entero**, gestionado por SAP. Las
> apps reciben dentro de él un trozo aislado llamado **contenedor HDI**.

### Las cuatro capas

Hay cuatro palabras que se confunden y conviene separarlas:

| Término              | Qué es realmente                                                              | Equivalente en Postgres                 |
|----------------------|-------------------------------------------------------------------------------|-----------------------------------------|
| Instancia HANA Cloud | El servidor: CPU, memoria, disco. Se crea con el entitlement `hana-cloud`.    | Un servidor Postgres en RDS             |
| Base de datos        | Una sola por instancia. En HANA Cloud no se crean varias.                     | Una única `database`                    |
| Esquema              | Espacio de nombres para tablas, como en cualquier SQL. `ESQUEMA.TABLA`.       | Un `schema`                             |
| Contenedor HDI       | **Dos esquemas + dos usuarios** que HDI crea y gestiona como un paquete. Lo pide la app con el servicio `hana` / `hdi-shared`. | Un schema por app, con grants solo a su owner, automatizado |

Un detalle de HANA que cambia la forma de pensar: **cada usuario tiene
automáticamente un esquema con su mismo nombre**. El esquema `DBADMIN` no es
"el contenedor de todo", es solo el esquema personal del administrador y
normalmente está vacío. Los contenedores HDI están al mismo nivel que él, no
dentro.

```
SUBACCOUNT trial
└── Instancia SAP HANA Cloud "hana-trial"     ← el servidor (servicio hana-cloud)
     │                                           creado en HANA Cloud Central
     └── Base de datos (una sola)
          ├── esquemas SYS, _SYS_BI…           ← sistema
          ├── esquema DBADMIN                  ← el personal del admin, vacío
          │
          ├── esquema BOOKSHOP_DB_1            ┐  contenedor HDI "bookshop-db"
          ├── esquema BOOKSHOP_DB_1#DI         │  (servicio hana / hdi-shared,
          ├── usuario BOOKSHOP_DB_1_RT         │   vive en el space dev;
          └── usuario BOOKSHOP_DB_1#OO         ┘   todo esto lo crea HDI junto)
          │
          └── esquemas y usuarios de otra app  ← otro contenedor, aislado:
                                                  no ve las tablas de bookshop
```

Qué hay dentro de un contenedor:

- **Esquema de runtime** (`BOOKSHOP_DB_1`): aquí viven las tablas BOOKS y
  AUTHORS. El nombre lo genera HDI, no lo eliges tú.
- **Esquema de despliegue** (`BOOKSHOP_DB_1#DI`): guarda los ficheros
  `.hdbtable` y el estado de lo ya desplegado. Es la tabla de migraciones
  aplicadas.
- **Usuarios técnicos** (`_RT` para la app, `#OO` como owner): los únicos con
  permisos sobre esos esquemas. La app recibe sus credenciales vía binding.

Son esquemas normales de HANA. Si entras con `DBADMIN` al Database Explorer
los ves listados junto al resto. La diferencia con un esquema creado a mano es
que HDI es su dueño, tú no tienes grants sobre ellos y no debes tocarlos
directamente.

> **Analogía.** Un servidor Postgres con una única database, donde cada app
> tiene su schema y solo su owner tiene permisos sobre él. HDI automatiza ese
> patrón y lo hace obligatorio. El aislamiento no lo da el esquema en sí, lo
> dan los permisos atados a los usuarios del contenedor.

### ¿Dos bases de datos separadas?

| Qué necesito                                       | Qué creo                                | Entitlement             |
|----------------------------------------------------|-----------------------------------------|-------------------------|
| Dos apps con sus datos aislados (caso normal)      | Dos contenedores HDI en la misma instancia | `hana` / `hdi-shared`, dos veces |
| Dos entornos con recursos separados (dev y prod)   | Dos instancias HANA Cloud, una por subaccount | `hana-cloud`, dos veces |
| Dos "databases" en el sentido Postgres             | No existe en HANA Cloud                 | —                       |

En el trial solo cabe **una instancia**, así que la segunda fila no aplica.
Cuando despleguemos en el space "prod", bookshop tendrá un segundo contenedor
dentro de la misma instancia `hana-trial`.

| Pieza                | Equivalente conocido           | Quién lo crea                        | ¿Sale en `cf services`?    |
|----------------------|--------------------------------|--------------------------------------|----------------------------|
| Instancia HANA Cloud | Un servidor Postgres en RDS    | Yo, una vez, en HANA Cloud Central   | No: vive en la subaccount  |
| Contenedor HDI       | Un schema con su usuario owner | La app al desplegar (`cf deploy`)    | Sí: vive en el space       |
| Tablas y vistas      | Lo que crean las migraciones   | CAP, desde el modelo `.cds`          | —                          |

### ¿Qué es HDI exactamente?

**HDI** (HANA Deployment Infrastructure) es ese paquete de esquemas aislados
más un **mecanismo de despliegue**. No escribes `CREATE TABLE`: CAP genera
ficheros declarativos (`.hdbtable`, `.hdbview`…) y HDI calcula y aplica las
diferencias contra el esquema `#DI`. Es como tener un sistema de migraciones
dentro de la propia base de datos.

### Cómo nace el contenedor al desplegar

Una app CAP necesita como mínimo un contenedor HDI, y las tablas van en su
esquema de runtime. Pero **nada de eso se crea a mano**. En el proyecto solo
tocas dos cosas:

- **El modelo**, en ficheros `.cds`: entidades `Books`, `Authors`… con sus
  campos.
- **La dependencia de HANA**, en `package.json` o `mta.yaml`: una línea que
  dice "este proyecto usa `hana` con plan `hdi-shared`".

A partir de ahí la cadena es automática:

```
 .cds ──cds build──▶ gen/db/*.hdbtable ──cf deploy──▶ broker hana crea el contenedor
                                                        (2 esquemas + 2 usuarios)
                                                               │
                                                      db deployer (app efímera)
                                                      entra como owner #OO y pasa
                                                      los .hdbtable a HDI
                                                               │
                                                      HDI crea/modifica tablas en
                                                      BOOKSHOP_DB_1 y anota en #DI
                                                               │
                                                      bookshop-srv recibe el usuario
                                                      _RT por binding y empieza a leer
```

1. `cds build` traduce el modelo a ficheros `.hdbtable` y `.hdbview` en
   `gen/db`.
2. `cf deploy` ve que la app necesita una instancia de `hana` / `hdi-shared` y
   la pide al broker. Si no existe, la crea: ahí nacen los esquemas y usuarios.
3. El **db deployer**, una app efímera, se conecta con el usuario owner y le
   pasa los `.hdbtable` a HDI. HDI calcula las diferencias y las aplica en el
   esquema de runtime, anotando el estado en el `#DI`.
4. La app de servicio recibe las credenciales del usuario `_RT` por binding y
   empieza a leer y escribir.

El orden mental es el inverso a "primero creo el contenedor y luego las
tablas": describes el modelo, declaras la dependencia, y el contenedor con sus
tablas aparece como consecuencia del despliegue. El único paso manual previo
es el instance mapping.

> **Lo que verás en el cockpit.** Tras el primer deploy, en el space aparece
> una instancia de servicio `bookshop-db` del servicio `hana`, plan
> `hdi-shared`. Esa entrada **es** el contenedor. Si la borras, se van los
> esquemas, los usuarios y los datos.

### El instance mapping

El servidor HANA vive en la subaccount, pero los contenedores HDI se piden
desde un space de Cloud Foundry. El **mapping** conecta los dos: le dice al
broker `hana` de una org (y opcionalmente de un space) "crea los contenedores
en esta instancia".

```
Instancia HANA "hana-trial"  ──mapping──▶  org 7b6c2113trial / space dev
                                             └─ aquí ya se pueden crear
                                                contenedores HDI
```

> **Trampas típicas.**
>
> 1. Sin mapping, el despliegue falla al crear el contenedor HDI
>    ("no HANA database found").
> 2. En la trial **la instancia se para cada noche**: hay que arrancarla en
>    HANA Cloud Central antes de trabajar.
> 3. Si en conexiones permitidas solo están las IPs de BTP, el portátil no
>    puede conectar en modo híbrido. Por eso elegimos "Allow all IP addresses".

**Para recordar**

- Instancia HANA Cloud = servidor con una única base de datos (subaccount).
  Contenedor HDI = dos esquemas + dos usuarios de una app (space).
- `hana-cloud` lo pide el admin una vez para el servidor. `hana` / `hdi-shared`
  lo consume cada app al desplegar para tener su contenedor.
- El esquema `DBADMIN` es el personal del admin. Los contenedores están a su
  lado, no dentro.
- La app nunca usa `DBADMIN`: usa los usuarios técnicos de su contenedor HDI.
- "Dos bases de datos" = dos contenedores en la misma instancia.
- El contenedor y sus tablas los crea el deploy a partir del modelo `.cds`. Tú
  no creas nada a mano, salvo el mapping.
- Mapping a la org/space, "allow all IPs" y arrancarla cada día en la trial.

---

## 9. Boosters

Un **booster** es un asistente guiado del cockpit que hace por ti varios pasos
de configuración seguidos.

Lo que hace un booster lo podrías hacer a mano: asignar entitlements, crear
suscripciones o instancias, crear role collections y asignártelas. El booster
no deja nada propio; deja exactamente lo mismo que si lo hubieras hecho tú.

| Lo que hizo el booster de HANA Cloud                       | Dónde se ve                               |
|------------------------------------------------------------|-------------------------------------------|
| Suscripción a SAP HANA Cloud (plan `tools`)                | Subaccount › Instancias y suscripciones   |
| Role collection *SAP HANA Cloud Administrator* asignada    | Subaccount › Seguridad › Usuarios         |

> **Analogía.** Como una plantilla de CloudFormation o un script de setup:
> cómodo, pero conviene saber qué ha creado para poder mantenerlo o repetirlo
> a mano.

**Para recordar**

- Booster = atajo. Después de usarlo, revisa qué creó.
- El booster "CAP" del curso ya no existe en la trial. Usamos el de
  herramientas de HANA Cloud.

---

## 10. Diario del curso

| Fecha      | Módulo | Qué hicimos                                                                                       |
|------------|--------|---------------------------------------------------------------------------------------------------|
| 2026-11-12 | 00–02  | Trial creada en AWS us10. Herramientas: cds-dk, mbt, cf CLI, plugin multiapps (ver `INSTALADO.md`) |
| 2026-11-12 | 03     | `cf login` contra `api.cf.us10-001`; org `7b6c2113trial`, space `dev`. Entitlements revisados. Space de prueba creado y borrado |
| 2026-11-13 | 04     | Booster de herramientas de HANA Cloud → suscripción a HANA Cloud Central + role collection        |
| 2026-11-13 | 05     | Creación de la instancia HANA Cloud en marcha. Ejercicio Destination: `dest-test` + key `key1`, inspeccionadas y borradas |

---

## 11. Glosario

| Término          | Definición                                                                        |
|------------------|-----------------------------------------------------------------------------------|
| Cockpit          | Consola web de BTP                                                                |
| Subaccount       | Unidad de aislamiento en una región, con sus usuarios, roles y servicios          |
| Org / Space      | Contenedores de Cloud Foundry: una org por subaccount, varios spaces por org      |
| Entitlement      | Permiso para usar un servicio + plan en una subaccount                            |
| Service instance | Recurso creado a partir de un servicio del catálogo                               |
| Subscription     | Acceso a una aplicación SaaS multitenant de SAP                                   |
| Binding          | Unión app ↔ instancia; inyecta credenciales en `VCAP_SERVICES`                    |
| Service key      | Credenciales de una instancia para usarla fuera de CF                             |
| XSUAA            | Servicio de autorización OAuth2 de BTP: emite y valida tokens JWT                 |
| Role collection  | Conjunto de roles que se asigna a usuarios                                        |
| HANA Cloud       | Base de datos gestionada de SAP. La "instancia" es el servidor completo           |
| HDI container    | Schema aislado en HANA, con mecanismo de despliegue, para una app                 |
| Instance mapping | Hace visible una instancia de HANA Cloud a una org/space de CF                    |
| Booster          | Asistente del cockpit que automatiza pasos de configuración                       |
| MTA / .mtar      | Multi-Target Application: app + servicios descritos en `mta.yaml`, empaquetados para `cf deploy` |
