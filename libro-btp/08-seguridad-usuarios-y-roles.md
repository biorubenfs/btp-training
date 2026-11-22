# 8. Seguridad: identidad, roles y XSUAA

**Objetivo del capítulo.** Entender quién interviene cuando alguien abre tu
app, qué decide cada uno, y cómo una línea en `xs-security.json` acaba
siendo un `200` o un `403`.

La seguridad en BTP parece enorme porque aparecen muchos nombres a la vez:
proveedor de identidad, SAP ID service, IAS, Entra ID, XSUAA, approuter,
JWT, scopes, role collections... El capítulo los presenta **de uno en uno y
siempre con la misma analogía**, en tres partes:

| Parte | Pregunta                          | Piezas                                     |
|-------|-----------------------------------|--------------------------------------------|
| 1     | ¿Quién eres? (autenticación)      | Proveedor de identidad, usuarios sombra, IAS, Entra ID |
| 2     | ¿Qué puedes hacer? (autorización) | XSUAA, scopes, roles, role collections, `@requires` |
| 3     | ¿Cómo viaja eso en una petición?  | Approuter, JWT, `srv`, 401 y 403           |

Al final, el caso de una cadena de librerías inventada, Librerías Folio,
junta las tres con bookshop como app.

> **Idea clave.** Como desarrollador solo tocas **tres sitios**:
> `xs-security.json` (qué permisos existen), los `@requires` del CDS (qué
> pide cada operación) y, si hace falta, `req.user.is()` en el código. Todo
> lo demás se configura una vez por empresa y lo hace otra persona.

## 8.1 El mapa: un congreso

Este capítulo usa una sola imagen. Tu app es **una sala dentro de un
recinto de congresos**:

```
  ┌───────────────────────────────────────────────────────────────────────────┐
  │ QUIEN EXPIDE EL DNI         Proveedor de identidad (IdP)                  │
  │ "Esta persona es Ana"       Trial: SAP ID service (accounts.sap.com)      │
  │                             Empresa: Entra ID, a través de su IAS         │
  └───────────────────────────────────┬───────────────────────────────────────┘
                                      │ la subcuenta se fía de él
  ┌───────────────────────────────────▼───────────────────────────────────────┐
  │ EL RECINTO                  Subcuenta                                     │
  │ Registro de recepción       Usuarios sombra (Seguridad › Usuarios)        │
  │                                                                           │
  │   ┌──────────────────────────────────────────────────────────────────┐    │
  │   │ MOSTRADOR DE PULSERAS    XSUAA: bookshop-auth                    │    │
  │   │ de tu sala               Da pulseras (JWT) con colores (scopes)  │    │
  │   │                          según las role collections de cada uno  │    │
  │   └──────────────────────────────────────────────────────────────────┘    │
  │   ┌────────────────────┐      ┌──────────────────────────────────────┐    │
  │   │ GUARDARROPA        │ ───▶ │ PORTERO DE LA SALA                   │    │
  │   │ approuter          │      │ bookshop-srv (CAP)                   │    │
  │   │ guarda tu pulsera  │      │ Solo mira la pulsera: ¿es de esta    │    │
  │   │ y te da un         │      │ sala?, ¿ha caducado?, ¿tiene el      │    │
  │   │ resguardo (cookie) │      │ color que pide esta puerta?          │    │
  │   └────────────────────┘      └──────────────────────────────────────┘    │
  └───────────────────────────────────────────────────────────────────────────┘
```

| En el congreso                         | En BTP                            | En bookshop                     |
|----------------------------------------|-----------------------------------|---------------------------------|
| DNI y quien lo expide                  | Proveedor de identidad (IdP)      | SAP ID service                  |
| Registro de recepción                  | Usuarios sombra de la subcuenta   | Seguridad › Usuarios            |
| Mostrador de pulseras de la sala       | Instancia XSUAA                   | `bookshop-auth`                 |
| Pulsera                                | JWT                               | El token que llega a `srv`      |
| Colores de la pulsera                  | Scopes                            | Ninguno todavía                 |
| Lista de qué pulsera dar a quién       | Role collections asignadas        | Ninguna todavía                 |
| Guardarropa (guarda la pulsera)        | Approuter                         | `bookshop`                      |
| Resguardo del guardarropa              | Cookie de sesión                  | `JSESSIONID`                    |
| Portero de la sala                     | Tu servicio CAP                   | `bookshop-srv`                  |

Dos ideas que salen del dibujo y que explican casi todo lo demás:

- **El portero nunca ve el DNI.** `srv` no sabe de contraseñas ni de
  proveedores de identidad. Solo comprueba pulseras.
- **El DNI no dice a qué salas puedes entrar.** Que el IdP te identifique
  no te da permiso para nada. Los permisos los decide la sala.

> **Analogía.** En AWS, Cognito hace de IdP y de mostrador de pulseras a la
> vez. En BTP son piezas separadas, y por eso en el cockpit las verás en
> pantallas distintas.

## Parte 1 · ¿Quién eres?

## 8.2 El proveedor de identidad

El **proveedor de identidad** (IdP, *identity provider*) es quien comprueba
usuario y contraseña y responde "esta persona es Ana". Es el único que ve
tu contraseña.

Una subcuenta no tiene usuarios propios: **se fía de uno o más IdPs**. Esa
relación se llama *confianza* (*trust*) y se ve aquí:

> **Cockpit:** Subcuenta › Seguridad › Configuración de confianza (*Trust
> Configuration*). En el trial hay una sola fila, *SAP ID service*, marcada
> como *Default Identity Provider* (`sap.default`). Comprobado el
> 2026-11-21.

**SAP ID service** es el login de `accounts.sap.com`, el mismo con el que
entras al cockpit. Es **un IdP compartido por todo el mundo**: cualquiera
puede crearse una cuenta gratis.

> **Analogía.** Es como un botón "Entrar con Google". Cualquier cuenta de
> Google puede identificarse en cualquier web que lo ofrezca. Que esa web le
> deje hacer algo es otro asunto, y lo decide la web.

## 8.3 Usuarios sombra: el registro de recepción

La primera vez que alguien hace login en una app de tu subcuenta, la
subcuenta le crea un **usuario sombra** (*shadow user*): una ficha mínima en
Seguridad › Usuarios. No tiene contraseña ni role collections. Es el
registro de recepción: "esta persona ha pasado por aquí".

La ficha existe para poder asignarle role collections. Hace falta "un
alguien" al que colgarle permisos.

### Dónde vive cada cosa

| Sitio                                   | Qué guarda                                                   | ¿Contraseña? |
|-----------------------------------------|--------------------------------------------------------------|--------------|
| **IdP** (SAP ID service, Entra ID...)   | La cuenta de verdad: email, contraseña, grupos               | Sí, solo aquí |
| **Subcuenta** (usuarios sombra)         | Email, de qué IdP viene y qué role collections tiene         | No           |
| **Tu base de datos** (`bookshop-db`)    | Tus datos de negocio. **No hay tabla de usuarios**           | No           |

Tu app no guarda usuarios. Sabe quién es cada uno porque **viene en el JWT
de cada petición**, y CAP lo deja preparado:

```ts
this.on('READ', 'Books', req => {
  req.user.id           // "ana@empresa.com" → sale del token
  req.user.is('Admin')  // true/false        → sale de los scopes del token
})
```

Los usuarios aparecen en tu base solo cuando el negocio necesita
**referirse** a ellos ("quién creó esta oferta"). Aun así, guardas el
identificador como texto, no la cuenta. CAP lo trae hecho con el aspecto
`managed`:

```cds
using { managed } from '@sap/cds/common';
entity Books : managed { ... }
// añade createdBy, createdAt, modifiedBy, modifiedAt
// y CAP los rellena con req.user.id en cada escritura
```

### La lista es de la subcuenta, no de la app

Seguridad › Usuarios no dice en qué app ha entrado cada uno. Con varias apps
en la subcuenta, todos sus usuarios salen mezclados. Esa lista no está
pensada para responder "¿cuántos usuarios tiene mi app?". Esa pregunta en
realidad son dos:

| Pregunta                          | Dónde se responde                                                                 |
|-----------------------------------|-----------------------------------------------------------------------------------|
| ¿Quién **puede** usar la app X?   | En sus role collections: Seguridad › Colecciones de roles › (colección) › usuarios o grupos. Con grupos de la empresa, en el propio grupo |
| ¿Quién **ha usado** la app X, y cuándo? | Es un dato de uso, no de identidad: logs de la app (`cf logs`), tu propia base (`createdBy`, una tabla de accesos), el servicio Audit Log de BTP o los informes del IAS |

> **Analogía.** ¿Quién puede entrar en la sala de bookshop? Mira quién tiene
> la pulsera, no el registro de recepción. ¿Quién entró ayer? Eso lo dice
> el lector de tarjetas de esa puerta (los logs), no recepción.

Si una empresa quiere aislar del todo una app, con sus propios usuarios y
administradores, la despliega en **su propia subcuenta** (capítulo 2).

## 8.4 Por qué cualquiera puede entrar en bookshop

Recién desplegado, **cualquier persona con cuenta de SAP puede usar
bookshop**. Juntando las piezas:

1. La subcuenta confía en SAP ID service, que admite a cualquiera que se
   registre.
2. Al hacer login, la subcuenta le crea un usuario sombra sin preguntar.
3. Ese usuario no tiene roles, pero tus servicios tampoco piden ninguno: CAP
   en producción solo exige estar autenticado (lo explica 8.8).

Choca, pero es coherente: BTP separa **identificar** de **autorizar**, y lo
que uno espera como "dar de alta a un usuario" es la segunda parte. Lo que
convierte un usuario sombra en alguien con permiso es una role collection, y
lo que hace que ese permiso sea necesario es un `@requires`.

Si además quieres controlar el login, cada IdP tiene dos ajustes en
Configuración de confianza:

| Ajuste                              | Efecto si se apaga                                                                          |
|-------------------------------------|---------------------------------------------------------------------------------------------|
| *Available for User Logon*          | Ese IdP deja de aparecer en el login. Así se retira SAP ID service en producción            |
| *Create Shadow Users During Logon*  | Solo entra quien **ya exista** en Seguridad › Usuarios. Hay que darlo de alta antes, a mano o por API |

> **En el trial.** No toques ninguno de los dos: te quedarías sin poder
> entrar en tu propia app. Bookshop se cierra con roles (8.10), que es la
> forma correcta.

## 8.5 En una empresa: Entra ID e IAS

En una empresa aparecen dos actores más. Ninguno toca tu código.

### Entra ID: el directorio de empleados

**Entra ID** es el nuevo nombre de Azure Active Directory: el directorio de
empleados de Microsoft en la nube. **Active Directory** es su versión
clásica, instalada en servidores propios. Para lo que nos ocupa son lo
mismo: **la lista oficial de empleados, con sus contraseñas y sus grupos.**
Es quien te valida cuando entras a Outlook o Teams con la cuenta del
trabajo.

No es de SAP. Casi todas las empresas ya lo tienen antes de llegar a BTP. Lo
que **no** quieren es que cada empleado tenga otra contraseña para SAP, ni
tener que darlo de baja en dos sitios cuando se va. Por eso la fuente de
verdad sigue siendo Entra ID, y SAP se fía de él.

### IAS: el login propio de la empresa

**IAS** (*Identity Authentication Service*, parte de SAP Cloud Identity
Services) es el servicio de login de SAP. La forma más fácil de entenderlo:

> **Idea clave.** SAP ID service es, en la práctica, **un IAS gigante
> compartido por todo el mundo**. El IAS de una empresa es lo mismo, pero
> privado: un tenant solo suyo.

|                       | SAP ID service             | IAS de una empresa                                   |
|-----------------------|----------------------------|------------------------------------------------------|
| Dirección             | `accounts.sap.com`         | `<empresa>.accounts.ondemand.com` o un dominio propio |
| Cuántos hay           | Uno para todo el planeta   | Uno por empresa (normalmente uno de test y otro productivo) |
| Quién puede registrarse | Cualquiera               | Solo quien la empresa decida                         |
| Conecta con Entra ID  | No                         | Sí                                                   |
| Quién pone las reglas | SAP                        | La empresa: doble factor, qué grupos entran en qué aplicación... |

Lo que hace un IAS:

- **Login**, con la imagen de la empresa si se quiere.
- **Puente con el directorio corporativo**: en vez de pedir la contraseña él,
  reenvía al login de Microsoft y recibe la respuesta, con los grupos.
- **Usuarios propios**, si la empresa no tiene directorio: entonces el IAS
  hace de DNI y de recepción a la vez.
- **Un solo login para todo lo de SAP**: BTP, S/4HANA Cloud,
  SuccessFactors... confían en el mismo IAS.

Para el desarrollador, el IAS es infraestructura, como el servidor de
correo. Si la empresa usa productos cloud de SAP, normalmente ya tiene uno
(suele venir con el contrato). Si no, lo pide su equipo de sistemas: en BTP
aparece como *Cloud Identity Services*.

> **Trampa.** HANA no trae IAS. **SAP HANA Cloud** es una base de datos, la
> de bookshop. **S/4HANA Cloud** es el ERP de SAP, una aplicación de negocio
> cuyos usuarios sí entran por IAS. Comparten la palabra "HANA" y nada más.

### La cadena de confianza

Cada flecha es una **relación de confianza** y se configura **en los dos
extremos**, como cuando dos personas se intercambian el teléfono:

```
 Entra ID ◄──────────► IAS de la empresa ◄──────────► Subcuenta ──► XSUAA de tu app
          confianza A                     confianza B
```

| Confianza | En un extremo                                             | En el otro                                               |
|-----------|-----------------------------------------------------------|----------------------------------------------------------|
| A         | En Entra ID, el IAS se registra como "aplicación empresarial": puede pedirle que autentique empleados, y recibe email y grupos | En el IAS, Entra ID se registra como "IdP corporativo": el login se manda a Microsoft |
| B         | En la subcuenta, Configuración de confianza › *Establish Trust*: "me fío de este IAS" | En el IAS aparece la subcuenta como aplicación           |

**Entra ID no sabe que tu app existe.** Para él, el IAS es una aplicación
más, como Zoom o Salesforce. Tu app solo la conoce su XSUAA, dentro de la
subcuenta. Por eso se pone el IAS en medio:

```
 Sin IAS:  Entra ID ──► app 1, app 2, ... app 30     30 registros en Microsoft,
                                                     uno por app nueva
 Con IAS:  Entra ID ──► IAS ──► subcuenta ──► app 1 ... app 30
                                                     1 registro, hecho una vez
```

| Una vez, cuando la empresa empieza con SAP cloud (sistemas)    | Por cada app nueva                                          |
|----------------------------------------------------------------|-------------------------------------------------------------|
| ① Conseguir el tenant de IAS                                   | ④ **Tú**: `xs-security.json` y `@requires`                  |
| ② Confianza A: IAS ↔ Entra ID                                  | ⑤ Administrador BTP: role collections ↔ grupos de Entra ID |
| ③ Confianza B: cada subcuenta ↔ IAS                            |                                                             |

Lo que cambia entre el trial y una empresa es solo la parte de arriba:

```
 Trial:    SAP ID service (compartido) ─────────────► subcuenta ──► bookshop-auth (XSUAA) ──► srv
 Empresa:  Entra ID ──► IAS de la empresa ──────────► subcuenta ──► XSUAA de la app ──────► srv
```

Tu `xs-security.json`, tus `@requires` y tu código no cambian si mañana la
empresa conecta su Entra ID.

> **Trampa.** Con dos IdPs en la subcuenta (`sap.default` y el IAS), tu
> usuario puede salir **dos veces** en Seguridad › Usuarios, una por IdP. Las
> role collections se asignan a uno de los dos y el otro no las ve. Si tienes
> un 403 "sin motivo", comprueba con qué IdP entraste.

> **Para más adelante.** SAP empuja a que las apps nuevas hablen
> directamente con el IAS, sin XSUAA (en CAP, `auth: "ias"`). La mayoría de
> proyectos, bookshop incluido, siguen con XSUAA. Las ideas del capítulo son
> las mismas: cambia quién emite la pulsera.

## Parte 2 · ¿Qué puedes hacer?

## 8.6 Scopes, roles y role collections

La autorización se construye en tres niveles de paquetes, cada uno hecho por
una persona distinta:

```
  SCOPE  ──▶  ROLE  ──▶  ROLE COLLECTION  ──▶  USUARIO o GRUPO
 permiso      paquete     paquete de roles,      la recibe, directamente
 atómico      de scopes   incluso de apps        o por su grupo del IdP
 ("Discount") (desde un   distintas.
              role        ES LO ÚNICO QUE
              template)   SE ASIGNA
```

| Pieza           | Qué es                          | Quién la define                         | Dónde se ve                                         |
|-----------------|---------------------------------|-----------------------------------------|-----------------------------------------------------|
| Scope           | Un permiso: "puede hacer descuentos grandes" | Tú, en `xs-security.json`               | Dentro del rol, en Seguridad › Roles                |
| Role template   | Un perfil: "Encargado = leer + vender + descontar" | Tú, en `xs-security.json` | Seguridad › Roles (se genera un rol al desplegar)   |
| Role collection | Lo que se asigna a la gente     | Un administrador, o tu `xs-security.json` | Seguridad › Colecciones de roles                  |
| Asignación      | Quién tiene qué role collection | Un administrador                        | Seguridad › Usuarios, o en la colección (usuarios y grupos) |

En la analogía: los scopes son los **colores** que puede tener una pulsera,
y las role collections son la **lista** que dice qué colores darle a cada
persona.

**En el JWT solo viajan los scopes.** `srv` recibe "este usuario tiene Read,
Sell y Discount", no "este usuario es Encargado". (El token puede traer
también los nombres de las role collections, pero CAP no los usa para
autorizar.)

> **Trampa.** La palabra "rol" significa cosas distintas según quién hable.
> CAP llama *role* a lo que XSUAA llama **scope**: cuando escribes
> `@requires: 'Discount'` o `req.user.is('Discount')`, CAP lo llama comprobar
> un rol, pero lo que mira es el scope `$XSAPPNAME.Discount` del token. Si la
> documentación de CAP dice *role*, piensa en un scope del
> `xs-security.json`.

> **Idea clave.** El código comprueba **permisos** ("¿puede hacer
> descuentos grandes?"), no **cargos** ("¿es encargado?"). Los cargos
> cambian: un dependiente veterano pasa a poder descontar, se crea un perfil
> nuevo... Eso se resuelve reorganizando paquetes en `xs-security.json` y en
> el cockpit, sin tocar el código. Por
> eso conviene que los scopes describan capacidades y no puestos.

## 8.7 Las tres capas de permisos

Lo anterior trata de los permisos **dentro de tu app**. Hay otras dos capas
independientes que dan permisos sobre la propia plataforma:

| Capa          | Ejemplos                                                                              | Dónde se gestiona                                              |
|---------------|---------------------------------------------------------------------------------------|----------------------------------------------------------------|
| Cuenta global | Global Account Administrator, Global Account Viewer                                   | Cockpit, nivel cuenta global › Seguridad                       |
| Subcuenta     | Subaccount Administrator, Subaccount Viewer, SAP HANA Cloud Administrator, Destination Administrator, **y las de tus apps** (`Bookshop_Admin`) | Cockpit, dentro de la subcuenta › Seguridad |
| Cloud Foundry | Org Manager, Space Developer, Space Manager, Auditor                                  | Cockpit › org o space › Miembros. **No son role collections**  |

Role collections de plataforma que conviene conocer:

| Role collection                 | Permite                                                             |
|---------------------------------|---------------------------------------------------------------------|
| Subaccount Administrator        | Todo en la subcuenta: servicios, usuarios, destinations             |
| Subaccount Viewer               | Ver todo, tocar nada. **La que pedir para aprender**                |
| SAP HANA Cloud Administrator    | HANA Cloud Central: crear, parar, arrancar, mapear instancias       |
| Destination Administrator       | Crear y editar destinations                                         |
| Cloud Connector Administrator   | Gestionar Cloud Connectors                                          |
| Global Account Administrator    | Nivel cuenta global: entitlements, subcuentas, directorios          |

> **Trampa.** Ser administrador de la cuenta global **no** da permisos dentro
> de una subcuenta, ni en sus spaces. Cada capa se asigna por separado. En el
> trial SAP lo hace todo por ti; en una empresa, el primer día tendrás que
> pedir que te añadan en las tres.

Qué pedir el primer día en una empresa, para aprender sin romper nada:

- *Subaccount Viewer* en la subcuenta de desarrollo (ver todo, tocar nada).
- *Space Developer* en el space `dev` (desplegar).
- Más adelante, *Subaccount Administrator* solo en dev.

## 8.8 Lo que CAP hace sin que se lo pidas

Bookshop no tiene ningún `@requires`, y aun así `srv` responde 401 sin
token. No viene de una anotación tuya: es un comportamiento por defecto de
CAP en producción. En `@sap/cds` 10.2.2 está en
`lib/srv/protocols/http.js`:

```js
const rr = d['@requires'] || d['@restrict']...      // ¿el servicio declara roles?
const roles = rr?.length ? rr : (
  process.env.NODE_ENV === 'production' &&           // si no, y estamos en producción
  cds.requires.auth?.restrict_all_services !== false &&
  ['authenticated-user']                             // → se exige estar autenticado
)
```

Un servicio sin `@requires` ni `@restrict` se comporta, en producción, como
si llevara `@requires: 'authenticated-user'`. El ajuste se llama
`restrict_all_services` y viene activado. La auth `mocked` de desarrollo lo
apaga expresamente (`restrict_all_services: false` en
`lib/env/cds-requires/auth-strategies.js`). Por eso en local no lo notas.

| | Local (`cds watch`) | BTP desplegado |
|---|---|---|
| Auth                       | `mocked`            | `xsuaa` (perfil `[production]` del `package.json`) |
| Servicio sin `@requires`   | Abierto a todos     | Exige un usuario autenticado (cualquier JWT válido) |
| Llamada sin token          | 200                 | **401**                                         |

> **Trampa.** "Exigir estar autenticado" no es "exigir un rol". Con SAP ID
> service, cualquiera con cuenta de SAP está autenticado (8.4). Un
> `AdminService` sin `@requires` deja escribir a cualquiera de ellos a
> través del approuter. **Ningún servicio debería quedarse sin `@requires`.**

## 8.9 Comprobar permisos: declarativo y en código

CAP ofrece tres niveles. Cada uno responde a una pregunta distinta:

```
@requires / @restrict        →  "¿puede llamar a esto?"          sí/no, por servicio u operación
@restrict con where          →  "¿puede tocar ESTA fila?"        cada uno, solo los libros que creó
req.user.is() en el handler  →  "¿puede hacer esto CON ESTOS     reglas que dependen de los
                                 DATOS?"                          valores de la petición
```

### Declarativo, en el CDS

| Anotación                         | Efecto                                                                    |
|-----------------------------------|---------------------------------------------------------------------------|
| `@requires: 'Admin'`              | Solo tokens con el scope `Admin`. Sin él, `403`; sin token, `401`          |
| `@requires: 'authenticated-user'` | Cualquier usuario autenticado. Es lo que CAP aplica por defecto (8.8)      |
| `@restrict: [{ grant: 'READ', to: 'Read' }, { grant: '*', to: 'ManageCatalog' }]` | Permisos por operación              |
| `@restrict: [{ grant: '*', to: 'ManageCatalog', where: 'createdBy = $user' }]` | Permisos por fila                      |

### En código, con `req.user`

Cuando la decisión depende de los datos, se pregunta en el handler. El
ejemplo es la acción `submitOrder` de bookshop (la venta de un libro, la
misma de 11.4), con un parámetro más: el descuento. Pueden vender quienes
tengan el scope `Sell`, pero solo quien tenga `Discount` puede aplicar más de
un 10 %.

```cds
// srv/cat-service.cds
service CatalogService @(path: '/catalog', requires: 'Read') {   // la puerta del servicio
  @readonly entity Books   as projection on my.Books;
  @readonly entity Authors as projection on my.Authors;

  @requires: 'Sell'                                               // la puerta de la acción
  action submitOrder(book: Books:ID, quantity: Integer, discount: Decimal) returns { stock: Integer };
}
```

```ts
// srv/cat-service.ts, dentro de init()
this.on('submitOrder', async (req) => {
  const { book, quantity, discount = 0 } = req.data
  // Aquí solo llega quien tiene 'Read' y 'Sell'. Ahora miramos qué más trae su token:
  if (discount > 10 && !req.user.is('Discount')) {
    return req.reject(403, 'Solo un encargado puede aplicar más de un 10 % de descuento')
  }
  const b = await SELECT.one.from(Books, book)
  if (!b) return req.reject(404, 'Libro no encontrado')
  if (b.stock < quantity) return req.reject(409, `Solo quedan ${b.stock}`)
  await UPDATE(Books, book).with({ stock: { '-=': quantity } })
  return { stock: b.stock - quantity }
})
```

Un 403 que no sale de ninguna anotación: el endpoint es el mismo para Ana y
para Pedro, y lo que cambia la respuesta es el valor de `discount`. Eso no
se puede expresar con `@requires`.

| Expresión                          | Devuelve                                                      |
|------------------------------------|---------------------------------------------------------------|
| `req.user.id`                      | El usuario del token, normalmente el email. `system` si es un token de client credentials (8.11) |
| `req.user.is('Discount')`          | `true` si el JWT trae el scope `Discount`                     |
| `req.user.is('authenticated-user')`| `true` si trae un token válido, tenga los scopes que tenga    |

En `is()` va el nombre del scope **sin** el prefijo `$XSAPPNAME.`: CAP lo
quita al leer el token (`scope.replace(xsappname, '')` en
`lib/srv/middlewares/auth/jwt-auth.js`).

> **Idea clave.** Siempre una puerta en el CDS, para que nadie sin permiso
> llegue a tu código, y las reglas finas en el handler.

## 8.10 Proteger bookshop paso a paso

La cadena completa, de tu fichero al `200`:

```
  xs-security.json ──deploy──▶ bookshop-auth ──▶ Roles ──▶ Role Collection ──▶ Usuario
  scopes +                     (XSUAA)           Seguridad   Bookshop_Admin      Seguridad
  role-templates                                 › Roles                         › Usuarios
                                                                                     │
                                                                                     ▼
                                     login → JWT con los scopes del usuario → CAP evalúa @requires
```

### Paso 1: declarar scopes y roles en `xs-security.json`

`cds add xsuaa` lo deja vacío, que es lo que tiene bookshop hoy:

```json
{
  "scopes": [],
  "attributes": [],
  "role-templates": []
}
```

Añadimos un scope y un rol de administrador. `$XSAPPNAME` es un marcador que
XSUAA sustituye por el nombre real de la app. Ese nombre lo fija el
`mta.yaml`, en `config.xsappname: bookshop-${org}-${space}`, que manda
sobre lo que ponga este fichero:

```json
{
  "scopes": [
    { "name": "$XSAPPNAME.Admin", "description": "Administrar el catálogo" }
  ],
  "attributes": [],
  "role-templates": [
    {
      "name": "Admin",
      "description": "Administrador de bookshop",
      "scope-references": ["$XSAPPNAME.Admin"]
    }
  ],
  "role-collections": [
    {
      "name": "Bookshop_Admin",
      "description": "Administradores de bookshop",
      "role-template-references": ["$XSAPPNAME.Admin"]
    }
  ]
}
```

La sección `role-collections` es opcional. Si la pones, el deploy crea la
colección y te ahorra la mitad del paso 4. Es lo recomendable para que el
proyecto sea reproducible.

> **Pendiente de validar.** En CAP, `cds add xsuaa` más `cds build` pueden
> generar los scopes a partir de las anotaciones `@requires` del modelo. Se
> comprobará qué genera cds-dk 10.2.1 al desplegar bookshop.

### Paso 2: usar el scope en el modelo CAP

```cds
// srv/admin-service.cds
using { sap.capire.bookshop as my } from '../db/schema';

@requires: 'Admin'
service AdminService @(path: '/admin') {
  entity Books   as projection on my.Books;
  entity Authors as projection on my.Authors;
}
```

`CatalogService` puede quedarse sin `@requires`: seguirá exigiendo estar
autenticado (8.8). Si quisieras que solo lo usen personas autorizadas, le
pondrías su propio scope, por ejemplo `Read`, como en 8.13.

> **Trampa.** No proyectes sobre `CatalogService.Books`. Las anotaciones se
> heredan en la proyección y `AdminService.Books` saldría `@readonly`: todo
> POST daría 405. Proyecta sobre las entidades de `db`. Comprobado con
> `cds compile` sobre bookshop.

### Paso 3: desplegar y comprobar que el rol existe

Tras `cf deploy`:

> **Cockpit:** Subcuenta › Seguridad › Roles (*Security › Roles*). Filtra por
> `bookshop`: aparece el rol `Admin` con la aplicación `bookshop-7b6c2113trial-dev!t12345`.

El sufijo `!t12345` es el identificador que XSUAA añade a cada instancia. Es
normal y no se configura.

### Paso 4: role collection y asignación

> **Cockpit:** Subcuenta › Seguridad › Colecciones de roles › Crear
> (*Role Collections › Create*) › nombre `Bookshop_Admin` › Editar › Añadir rol
> › aplicación `bookshop-…`, rol `Admin` › Guardar.
>
> **Cockpit:** Subcuenta › Seguridad › Usuarios › (tu usuario) › Asignar
> colección de roles (*Assign Role Collection*) › `Bookshop_Admin`.

Con la `btp` CLI (capítulo 14):

```bash
btp create security/role-collection Bookshop_Admin --description "Administradores de bookshop"
btp add security/role Admin --to-role-collection Bookshop_Admin \
    --of-app bookshop-7b6c2113trial-dev!t12345 --of-role-template Admin
btp assign security/role-collection Bookshop_Admin --to-user mi@correo.com --of-idp sap.default
```

> **Pendiente de validar.** Comandos tomados de la referencia de `btp`. Se
> ejecutarán cuando se instale la CLI.

### Paso 5: comprobar

Por el approuter, con tu usuario: `/admin/Books` da 403 antes de asignarte
la colección y 200 después, **tras cerrar sesión y volver a entrar**. Con
otra cuenta de SAP sin la colección, 403 siempre.

> **Pendiente de validar.** Las peticiones de `http/cloud.http` usan un
> token de client credentials, que no lleva los scopes de ninguna persona
> (8.11). Tras el paso 2, `/admin` debería responder 403 también con ese
> token. Para que la propia app tenga el scope, se declara en
> `xs-security.json` con `"authorities": ["$XSAPPNAME.Admin"]`. Se probará al
> hacer este capítulo.

## Parte 3 · El recorrido de una petición

## 8.11 Los dos caminos de entrada

`srv` acepta peticiones por dos caminos, y en los dos le llega lo mismo: una
cabecera `Authorization: Bearer <JWT>`. Cambia quién consigue el token.

### Camino 1: una persona con navegador, por el approuter

El navegador no sabe pedir tokens ni guardarlos de forma segura. Para eso
está el approuter: es el **guardarropa**. Guarda tu pulsera y te da un
resguardo (la cookie de sesión).

```
Navegador           approuter              XSUAA          IdP (SAP ID)           srv
   │── GET /catalog/… ─►│                    │                  │                 │
   │                    │ ¿cookie? NO        │                  │                 │
   │◄── al login ───────│                    │                  │                 │
   │── pide login ──────────────────────────►│                  │                 │
   │                    │                    │── ¿quién es? ───►│                 │
   │◄── formulario de login (o directo si ya hay sesión) ───────│                 │
   │                    │                    │◄── es Ana ───────│                 │
   │◄── vuelve con un "code" ────────────────│                  │                 │
   │                    │── code ───────────►│                  │                 │
   │                    │◄── JWT ────────────│                  │                 │
   │                    │ guarda el JWT en la sesión            │                 │
   │◄── cookie ─────────│                    │                  │                 │
   │                    │── GET + Authorization: Bearer JWT ─────────────────────►│
   │                    │◄── 200 ─────────────────────────────────────────────────│
   │◄── libros ─────────│                    │                  │                 │
```

- **El navegador nunca ve el JWT.** Lleva solo la cookie. El token se queda
  dentro del approuter.
- Que el approuter añada la cabecera al reenviar es el `forwardAuthToken:
  true` del `mta.yaml` (capítulo 11.3).
- El JWT lleva **a la persona**: `req.user.id` es su email.
- A partir de la segunda petición ya hay cookie, y solo ocurren las dos
  últimas flechas.

### Camino 2: un programa, directo a `srv`

Un programa sí sabe pedir tokens. Es lo que hace `http/cloud.http` con la
key `rest-client-key`, y lo que hace una app cuando llama a otra
(capítulo 6.6):

```
REST Client / otra app              XSUAA                         srv
   │ POST /oauth/token               │                              │
   │ clientid + clientsecret         │                              │
   │ grant_type=client_credentials ─►│                              │
   │◄──────────── JWT ───────────────│                              │
   │── GET /catalog/Books + Authorization: Bearer JWT ─────────────►│
   │◄─────────────────────────── 200 ───────────────────────────────│
```

Aquí no hay persona ni login. **La que se autentica es la app**, con el id y
el secreto de la key. En la analogía es una pulsera de personal (catering,
montaje): válida, pero sin nombre de asistente. CAP la representa así
(`jwt-auth.js`): `req.user.id` es `system`, con los roles internos
`system-user` y, si el token es de la propia app, `internal-user`. Los
scopes que tenga son los que la app se haya concedido con `authorities` en
`xs-security.json`, no los de ninguna persona.

### Sin token, directo a `srv`

```
Navegador ── GET bookshop-srv.../catalog/Books (sin Authorization) ──► srv ──► 401
```

`srv` no tiene login y no sabe mandarte a uno: eso solo lo hace el
approuter. Y tu sesión de `accounts.sap.com` es una cookie de otro dominio,
que el navegador no envía a `srv` (y aunque lo hiciera, una cookie no es un
JWT). **Desde el navegador, entra siempre por la URL del approuter**, la que
no lleva `-srv`.

### Lo que comprueba `srv`, en orden

```
¿Trae JWT?                         NO → 401
¿Lo ha firmado su XSUAA?           NO → 401   (con la verificationkey del binding)
¿Ha caducado?                      SÍ → 401
¿Tiene los scopes que pide         NO → 403
 el servicio o la operación?       SÍ → se ejecuta tu código
```

> **Trampa.** Te asignan la role collection, recargas y sigue dando 403. La
> pulsera que guarda el approuter es la vieja, sin el color nuevo. **Cierra
> sesión y vuelve a entrar.** Es el error más repetido de todo BTP.

## 8.12 401 frente a 403

| Código | Significa                  | Causa habitual                                                                 | Dónde mirar                                   |
|--------|----------------------------|--------------------------------------------------------------------------------|-----------------------------------------------|
| 401    | No sé quién eres           | Llamas a `srv` directamente sin token; token caducado o de otra XSUAA; el approuter no tiene XSUAA ligada | URL que usas; enlaces de servicio del approuter |
| 403    | Sé quién eres y no puedes  | El servicio pide un scope que tu token no trae: role collection sin asignar, o token viejo | Seguridad › Usuarios; cerrar sesión |

## 8.13 Caso completo: bookshop en Librerías Folio

Librerías Folio es una cadena de librerías con varias tiendas. Usa Microsoft
para el correo y Teams, y SAP para su negocio. Bookshop es su app interna:
el catálogo y las ventas en tienda. Los requisitos:

- La usan algunos empleados, **no todos**: el personal de almacén o de
  contabilidad no tiene nada que hacer en ella.
- Hay tres perfiles:

| Perfil            | Qué hace                                                  |
|-------------------|-----------------------------------------------------------|
| **Dependiente**   | Consulta el catálogo y vende, con descuento de hasta el 10 % |
| **Encargado**     | Lo mismo, con cualquier descuento                         |
| **Administrador** | Da de alta, edita y borra libros y autores                |

### Quién hace qué

| Paso | Quién                         | Qué                                                    | Dónde                          |
|------|-------------------------------|--------------------------------------------------------|--------------------------------|
| 1    | Sistemas de Folio             | Grupos y sus miembros                                  | Entra ID                       |
| 2    | Sistemas de Folio (una vez)   | Confianzas Entra ID ↔ IAS ↔ subcuenta                  | IAS y cockpit                  |
| 3    | **Tú**                        | Scopes, role templates, `@requires`                    | `xs-security.json`, `.cds`     |
| 4    | Administrador BTP             | Role collections mapeadas a grupos                     | Cockpit (o `xs-security.json`) |

### Paso 1: grupos en Entra ID

```
Grupo                    Miembros
───────────────────      ──────────────────────
FOLIO-Dependientes       ana, luis, marta
FOLIO-Encargados         pedro
FOLIO-Admin              lucía
```

Es lo único que se toca en Microsoft. Quien no esté en ninguno de los tres
grupos no usa la app, aunque sea empleado de Folio.

### Paso 2: confianzas

Las de 8.5. No son por bookshop: se hacen una vez y sirven para todas las
apps de Folio en BTP. En la subcuenta productiva, SAP ID service queda sin
*Available for User Logon*, así que una cuenta cualquiera de SAP ya no
sirve.

### Paso 3: tu código

Cuatro scopes (capacidades) y tres role templates (perfiles):

```json
{
  "scopes": [
    { "name": "$XSAPPNAME.Read",          "description": "Consultar el catálogo" },
    { "name": "$XSAPPNAME.Sell",          "description": "Vender en tienda" },
    { "name": "$XSAPPNAME.Discount",      "description": "Descuentos de más del 10 %" },
    { "name": "$XSAPPNAME.ManageCatalog", "description": "Mantener libros y autores" }
  ],
  "role-templates": [
    { "name": "Dependiente",   "scope-references": ["$XSAPPNAME.Read", "$XSAPPNAME.Sell"] },
    { "name": "Encargado",     "scope-references": ["$XSAPPNAME.Read", "$XSAPPNAME.Sell", "$XSAPPNAME.Discount"] },
    { "name": "Administrador", "scope-references": ["$XSAPPNAME.Read", "$XSAPPNAME.ManageCatalog"] }
  ]
}
```

Los dos servicios de bookshop, cada uno con su puerta:

```cds
// srv/cat-service.cds: la tienda
service CatalogService @(path: '/catalog', requires: 'Read') {
  @readonly entity Books   as projection on my.Books;
  @readonly entity Authors as projection on my.Authors;

  @requires: 'Sell'
  action submitOrder(book: Books:ID, quantity: Integer, discount: Decimal) returns { stock: Integer };
}

// srv/admin-service.cds: el mantenimiento del catálogo
service AdminService @(path: '/admin', requires: 'ManageCatalog') {
  entity Books   as projection on my.Books;
  entity Authors as projection on my.Authors;
}
```

Y en el handler de `submitOrder`, la regla del descuento de 8.9. Fíjate en
lo que **no** sabes: quién es Ana y qué grupos existen en Folio. Solo
declaras qué permisos hay y qué pide cada operación.

> **Idea clave.** En 8.10, para practicar, el scope del `AdminService` se
> llama `Admin`. Aquí se llama `ManageCatalog`: describe lo que permite, no
> quién lo tiene. Si mañana el encargado también puede dar de alta libros,
> se añade `ManageCatalog` a su perfil y nada más. Con un scope llamado
> `Admin`, tendrías un encargado con permiso "de administrador" solo para
> mantener el catálogo.

### Paso 4: role collections ↔ grupos

| Role collection          | Contiene el rol | Mapeada al grupo del IdP |
|--------------------------|-----------------|--------------------------|
| Bookshop Dependiente     | Dependiente     | FOLIO-Dependientes       |
| Bookshop Encargado       | Encargado       | FOLIO-Encargados         |
| Bookshop Administrador   | Administrador   | FOLIO-Admin              |

> **Cockpit:** Subcuenta › Seguridad › Colecciones de roles › (colección) ›
> Editar › Grupos de usuarios (*User Groups*): el nombre del grupo tal como
> lo envía el IAS, y el IdP.

Este es el puente: "quien llegue con el grupo X recibe la colección Y". Se
configura una vez y nadie vuelve a tocar el cockpit por personas.

### Lo que pasa con cada uno

```
Ana (FOLIO-Dependientes)
  login Microsoft → IAS: "grupo FOLIO-Dependientes" → XSUAA: "Bookshop Dependiente"
  → JWT con [Read, Sell]
  → GET /catalog/Books                                             200
  → submitOrder con un 5 % de descuento                            200
  → submitOrder con un 15 %: lo para el handler                    403
  → POST /admin/Books                                              403

Pedro (FOLIO-Encargados)
  → JWT con [Read, Sell, Discount]
  → submitOrder con un 15 %                                        200
  → POST /admin/Books                                              403

Lucía (FOLIO-Admin)
  → JWT con [Read, ManageCatalog]
  → POST /admin/Books                                              200
  → submitOrder: la administradora no vende                        403

Raúl (almacén, en ningún grupo de la app)
  → login correcto, JWT sin scopes → en todo                       403

Alguien con una cuenta de SAP cualquiera
  → no puede ni hacer login: la subcuenta no se fía de su IdP       —
```

Fíjate en los tres orígenes del 403: el `@requires` del servicio (Raúl en
todo, Ana en `/admin`), el de la acción (Lucía al vender) y el handler (Ana
con un 15 %).

Raúl puede hacer login, pero no hacer nada. Si Folio quiere que ni siquiera
pueda hacer login, el IAS permite limitar qué grupos acceden a cada
aplicación. Es una capa opcional: lo que protege de verdad es que **ningún
servicio quede sin `@requires`**.

### El día a día

| Situación                                   | Qué se hace                                                  | ¿Se toca SAP? |
|---------------------------------------------|--------------------------------------------------------------|---------------|
| Entra una dependienta nueva                 | Sistemas la mete en `FOLIO-Dependientes`                     | No            |
| Ascienden a Ana a encargada                 | La cambian de grupo; en su siguiente login tiene `Discount`  | No            |
| Alguien deja la empresa                     | Baja en Entra ID: pierde Outlook y bookshop a la vez         | No            |
| Los encargados también mantienen el catálogo | Añadir `ManageCatalog` al role template `Encargado`         | Sí, pero el código no |

## 8.14 Trampas

> **Trampa.** Abrir la URL de `srv` en el navegador y recibir 401. Es lo
> esperado: entra por el approuter.

> **Trampa.** Dejar un servicio sin `@requires` creyendo que es privado. En
> producción solo exige estar autenticado, y con SAP ID service eso es
> cualquiera con cuenta de SAP.

> **Trampa.** Token viejo tras asignar la role collection. Cerrar sesión.

> **Trampa.** Dos usuarios con el mismo correo, de IdPs distintos. Asignar la
> colección al que usas para entrar.

> **Trampa.** Confundir roles de CF (Space Developer, para desplegar) con role
> collections de BTP (para usar apps y el cockpit). Hacen falta los dos y se
> piden en sitios distintos.

> **Trampa.** Cambiar `xs-security.json` y redesplegar: XSUAA actualiza
> scopes y roles, pero las role collections que creó alguien a mano no se
> tocan. Si renombras un role template, la colección se queda con el viejo.

## Para recordar

- Autenticación (¿quién eres?: IdP, Configuración de confianza) ≠
  autorización (¿qué puedes hacer?: XSUAA, scopes, role collections).
- El portero (`srv`) solo mira la pulsera (JWT). Nunca ve la contraseña.
- Trial: SAP ID service, compartido, admite a cualquiera. Empresa: Entra ID →
  IAS → subcuenta. Lo de debajo de la subcuenta no cambia.
- Los usuarios sombra viven en la subcuenta, no en tu base. Quién **puede**
  usar una app se ve en sus role collections; quién **la ha usado**, en los
  logs.
- Scope ⊂ role ⊂ role collection → usuario o grupo. Solo se asignan role
  collections, y en el token solo viajan scopes.
- CAP llama "rol" al scope. El código pregunta por permisos, no por cargos.
- Sin `@requires`, CAP en producción exige `authenticated-user`
  (`restrict_all_services`). Pon siempre un `@requires`.
- Navegador → approuter (cookie, el JWT se queda dentro). Programa → `srv`
  con su propio JWT de client credentials (`req.user.id` = `system`).
- 401 = sin token o token inválido. 403 = token sin el scope. ¿403 tras
  asignar? Cerrar sesión y volver a entrar.

## Ejercicio

1. Abre Configuración de confianza y Seguridad › Usuarios. Anota qué IdP
   hay y qué usuarios sombra existen. Haz login en bookshop con otra cuenta
   de SAP desde una ventana de incógnito y comprueba que aparece un usuario
   nuevo.
2. En bookshop, añade el scope y el role template `Admin` de 8.10 y anota
   `@requires: 'Admin'` en `AdminService`. Redespliega.
3. Comprueba que el rol aparece en Seguridad › Roles. Crea la role collection
   `Bookshop_Admin`, añade el rol y asígnatela.
4. Prueba `/admin/Books` por el approuter antes y después de cerrar sesión, y
   con la cuenta del punto 1. Explica cada resultado en una frase.
5. Lanza las peticiones de `http/cloud.http` contra `/admin`. Explica el
   resultado con 8.11 y, si es un 403, arréglalo con `authorities`.
