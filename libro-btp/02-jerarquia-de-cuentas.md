# 2. La jerarquía de cuentas

**Objetivo del capítulo.** Construir el modelo mental más importante del
libro. Sin él, el cockpit es un laberinto: las cosas "no están" porque las
buscas en el nivel equivocado.

## 2.1 El árbol

Todo lo que creas en BTP cuelga de un árbol de cinco niveles:

```
  CUENTA GLOBAL (Global Account)        el contrato con SAP
  │
  ├── DIRECTORIO (Directory)            carpeta opcional: proyecto, departamento
  │   │
  │   ├── SUBCUENTA (Subaccount)        UNA región · sus usuarios · sus servicios
  │   │   │
  │   │   └── ENTORNO: org de CF        una org por subcuenta
  │   │       │
  │   │       ├── SPACE "dev"           apps + instancias de servicio
  │   │       └── SPACE "prod"          apps + instancias de servicio
  │   │
  │   └── SUBCUENTA ...
  │
  └── DIRECTORIO ...
```

| Nivel         | Qué representa                                                          | Quién lo gestiona             | En el trial                     |
|---------------|-------------------------------------------------------------------------|-------------------------------|---------------------------------|
| Cuenta global | El contrato comercial con SAP: entitlements comprados, consumo, facturas | Administradores globales      | Una, creada automáticamente     |
| Directorio    | Carpeta para agrupar subcuentas. Puede tener sus propios admins y entitlements | Administradores globales | No se usa                       |
| Subcuenta     | La unidad de trabajo real. **Una región**, sus usuarios, roles, servicios, destinations y entornos | Subaccount Administrators | `trial`, en `us10`     |
| Org de CF     | Se crea al habilitar Cloud Foundry en la subcuenta. Siempre exactamente una | Org Managers              | `7b6c2113trial`                 |
| Space         | Subdivisión de la org donde viven apps e instancias. Cada space tiene sus miembros | Space Managers / Developers | `dev`                     |

> **Analogía.** Una empresa (cuenta global) con oficinas en varias ciudades
> (subcuentas, una por región). Cada oficina tiene un edificio de Cloud
> Foundry (la org) con varias plantas (spaces). En cada planta trabajan tus
> apps. Pero algunas cosas son de la oficina entera y no de una planta: la
> base de datos, el control de accesos, las conexiones con otras empresas.

## 2.2 La subcuenta es la frontera que importa

De los cinco niveles, el que debes tener siempre en la cabeza es la
**subcuenta**. Todo lo que tiene que ver con *aislamiento* se decide ahí:

- **Región.** Se elige al crearla y no se cambia. Dos subcuentas en regiones
  distintas no comparten nada.
- **Usuarios y role collections.** Un usuario con permisos en `acme-dev` no
  tiene ninguno en `acme-prod` hasta que alguien se los dé.
- **Servicios y suscripciones.** Los entitlements se asignan a la subcuenta,
  el marketplace muestra lo que la subcuenta tiene asignado.
- **Destinations y trust.** Las conexiones a otros sistemas y el proveedor de
  identidad se configuran por subcuenta.

Por eso el patrón habitual en las empresas es **una subcuenta por etapa**:

```
Cuenta global "ACME"
└── Directorio "Proyecto Ventas"
    ├── Subcuenta ventas-dev   (eu10) → org → space dev
    ├── Subcuenta ventas-qa    (eu10) → org → space qa
    └── Subcuenta ventas-prod  (eu10) → org → space prod
```

Cada etapa tiene su propia HANA, sus propios usuarios y sus destinations
apuntando al S/4HANA que corresponda. Un error en `ventas-dev` no puede tocar
nada de `ventas-prod`.

> **En el trial.** Solo hay una subcuenta y no se pueden crear más.
> "Producción" se simulará con un segundo space dentro de la misma org
> (capítulo 14). Es un buen ejercicio, pero recuerda que en una empresa real
> dev y prod **nunca** comparten subcuenta ni instancia de HANA.

## 2.3 Qué vive en cada nivel

Esta es la tabla que resuelve la mayoría de los "¿dónde está?":

```
┌─ SUBCUENTA ───────────────────────────────────────────────────────────┐
│  · suscripciones a apps SaaS (HANA Cloud Central, BAS, Work Zone)     │
│  · la instancia de SAP HANA Cloud (el servidor de base de datos)      │
│  · usuarios, roles y role collections                                 │
│  · destinations y Cloud Connectors                                    │
│  · trust configuration (proveedor de identidad)                       │
│  · entitlements asignados                                             │
│                                                                       │
│  ┌─ ORG DE CLOUD FOUNDRY ─────────────────────────────────────────┐   │
│  │  · miembros de la org (Org Manager, Org Auditor)               │   │
│  │  · cuotas de memoria                                           │   │
│  │                                                                │   │
│  │  ┌─ SPACE "dev" ──────────────────────────────────────────┐    │   │
│  │  │  · aplicaciones (bookshop-srv, bookshop, db-deployer)  │    │   │
│  │  │  · instancias de servicio (bookshop-db, bookshop-auth) │    │   │
│  │  │  · service keys de esas instancias                     │    │   │
│  │  │  · routes (URLs públicas)                              │    │   │
│  │  │  · miembros del space (Space Developer…)               │    │   │
│  │  └────────────────────────────────────────────────────────┘    │   │
│  └────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────┘
```

La regla práctica: **si lo usan personas desde el navegador o afecta a toda la
subcuenta, está arriba. Si lo usa tu código, está en un space.** La excepción
que más confunde es SAP HANA Cloud: el servidor está en la subcuenta, pero los
contenedores HDI que usan las apps están en el space (capítulo 7).

## 2.4 Ejemplo: el trial visto desde el cockpit y desde la CLI

En el cockpit, la ruta de navegación de la parte superior te dice en qué
nivel estás. Es lo primero que hay que mirar cuando algo no aparece:

```
Inicio › Cuenta global trial › Subcuenta trial › Cloud Foundry › Espacios › dev
  └ nivel global ─┘ └─── nivel subcuenta ──┘ └─────── nivel CF ─────────┘
```

> **Cockpit:** Cuenta global › Explorador de cuentas (*Global Account › Account
> Explorer*) muestra el árbol completo de directorios y subcuentas.

Desde la CLI de Cloud Foundry solo se ve la parte de abajo del árbol: orgs y
spaces. La cuenta global y la subcuenta son conceptos de BTP, no de Cloud
Foundry, y para ellas se usa la CLI `btp` (apéndice C).

```bash
cf login -a https://api.cf.us10-001.hana.ondemand.com
```

```
API endpoint: https://api.cf.us10-001.hana.ondemand.com

Email: ********
Password: ********

Authenticating...
OK

Targeted org 7b6c2113trial.
Targeted space dev.

API endpoint:   https://api.cf.us10-001.hana.ondemand.com
API version:    3.209.0
user:           ********
org:            7b6c2113trial
space:          dev
```

Si en la empresa el login es por navegador (single sign-on), el comando es
`cf login -a <endpoint> --sso`: imprime una URL, la abres, copias el código
temporal y lo pegas en el terminal.

```bash
cf orgs            # orgs que puedo ver con este usuario
cf spaces          # spaces de la org actual
cf target          # dónde estoy ahora mismo
```

```
Getting orgs as ********...
name
7b6c2113trial

Getting spaces in org 7b6c2113trial as ********...
name
dev

API endpoint:   https://api.cf.us10-001.hana.ondemand.com
API version:    3.209.0
user:           ********
org:            7b6c2113trial
space:          dev
```

Para cambiar de space sin volver a hacer login:

```bash
cf target -s prod
cf target -o otra-org -s dev
```

## 2.5 Crear y borrar un space

Es la operación de jerarquía que sí harás como desarrollador. Se puede hacer
en el cockpit o en la CLI y el resultado es idéntico.

> **Cockpit:** Subcuenta › Cloud Foundry › Espacios › Crear espacio
> (*Subaccount › Cloud Foundry › Spaces › Create Space*)

```bash
cf create-space sandbox
cf spaces
cf delete-space sandbox -f       # -f evita la pregunta de confirmación
```

```
Creating space sandbox in org 7b6c2113trial as ********...
OK

Assigning role SpaceManager to user ******** in org 7b6c2113trial / space sandbox as ********...
OK

Assigning role SpaceDeveloper to user ******** in org 7b6c2113trial / space sandbox as ********...
OK

TIP: Use 'cf target -o "7b6c2113trial" -s "sandbox"' to target new space
```

Fíjate en el detalle: al crear el space, la CLI te asigna automáticamente los
roles Space Manager y Space Developer en él. Si lo crea otra persona, tendrá
que añadirte (capítulo 8).

> **Trampa.** Borrar un space borra **todo** lo que contiene: apps, instancias
> de servicio con sus datos, service keys y routes. No hay papelera. Antes de
> borrar, `cf apps` y `cf services` para ver qué hay.

## 2.6 Trampas

> **Trampa.** Las role collections de la cuenta global (Global Account
> Administrator, Global Account Viewer) no son las de la subcuenta (Subaccount
> Administrator, SAP HANA Cloud Administrator…). Ser administrador global no
> da permisos automáticos dentro de una subcuenta ni en sus spaces. Cada capa
> se asigna por separado.

> **Trampa.** "No veo el servicio en el marketplace." Nueve de cada diez
> veces es un entitlement que no está asignado a **esta** subcuenta
> (capítulo 3). La décima, estás mirando otra subcuenta.

> **Trampa.** Dos cosas con el mismo nombre en niveles distintos: la
> subcuenta se llama `trial` y la org de CF se llama `7b6c2113trial`. En
> empresas suele ser peor, con org y subcuenta llamadas igual. Mira siempre
> la ruta de navegación.

## Para recordar

- Cuenta global ⊃ directorios ⊃ subcuentas ⊃ una org de CF ⊃ spaces ⊃ apps e
  instancias.
- La subcuenta es la frontera: región, usuarios, roles, servicios,
  destinations.
- Lo que usan personas o afecta a toda la subcuenta vive arriba; lo que usa tu
  código vive en un space.
- Patrón de empresa: una subcuenta por etapa (dev, qa, prod).
- `cf` solo ve orgs y spaces. Para cuenta global y subcuenta está `btp`.

## Ejercicio

1. Identifica en el cockpit el nombre de la cuenta global, la subcuenta, su
   región y su org de CF. Compáralos con la salida de `cf target`.
2. Crea un space `sandbox` desde el cockpit. Compruébalo con `cf spaces`.
   Bórralo desde la CLI y comprueba en el cockpit que ha desaparecido.
3. Dibuja en papel el árbol de tu trial y añade, con otro color, cómo sería el
   de una empresa con tres proyectos y tres etapas cada uno.
