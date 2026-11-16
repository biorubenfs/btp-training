# 14. De desarrollo a producción

**Objetivo del capítulo.** Llevar bookshop a un entorno "prod" con el mismo
`.mtar` y configuración distinta, entender cómo lo hacen las empresas, y
conocer la CLI `btp` para la parte de cuentas y seguridad.

## 14.1 El landscape de una empresa

El estándar es **una subcuenta por entorno**, dentro de un directorio por
proyecto:

```
Cuenta global ACME
└── Directorio "Ventas"
    ├── ventas-dev   (eu10)  HANA propia · S4_SALES → S/4 de desarrollo · devs con Space Developer
    ├── ventas-qa    (eu10)  HANA propia · S4_SALES → S/4 de calidad    · testers con role collections de negocio
    └── ventas-prod  (eu10)  HANA propia · S4_SALES → S/4 productivo    · nadie despliega a mano
```

Reglas que se cumplen siempre:

- **Nunca** se comparte una instancia de HANA entre entornos.
- Las destinations se llaman **igual** en todas las subcuentas y apuntan a
  sistemas distintos. Así la app no cambia.
- El **mismo `.mtar`** se despliega en las tres. Lo que cambia por entorno va
  en un **extension descriptor** (`.mtaext`).
- A prod no despliega una persona desde su portátil: lo hace un pipeline de
  CI/CD o **Cloud Transport Management** (cTMS), que mueve el `.mtar` de una
  subcuenta a la siguiente con aprobación.

> **En el trial.** Una sola subcuenta y una sola HANA. Se simula prod con un
> **segundo space** `prod` en la misma org. Comparte HANA (contenedor
> distinto), XSUAA (instancia distinta) y usuarios. Sirve para practicar el
> `.mtaext` y la separación de spaces; no sirve para practicar la separación
> de subcuentas, que es la real.

## 14.2 Extension descriptors (`.mtaext`)

Un `.mtaext` sobrescribe parámetros del `mta.yaml` sin tocarlo. Uno por
entorno:

```yaml
# .deploy/prod.mtaext
_schema-version: 3.3.0
ID: bookshop.prod
extends: bookshop

modules:
  - name: bookshop-srv
    parameters:
      instances: 2
      memory: 512M
  - name: bookshop
    parameters:
      memory: 256M

resources:
  - name: bookshop-auth
    parameters:
      config:
        xsappname: bookshop-prod
```

```yaml
# .deploy/dev.mtaext
_schema-version: 3.3.0
ID: bookshop.dev
extends: bookshop

modules:
  - name: bookshop-srv
    parameters:
      instances: 1
      memory: 256M
```

```bash
mbt build                                                      # un solo .mtar
cf target -s dev  && cf deploy mta_archives/bookshop_1.0.0.mtar -e .deploy/dev.mtaext
cf target -s prod && cf deploy mta_archives/bookshop_1.0.0.mtar -e .deploy/prod.mtaext

# equivalente con cds:
cds up --to cf --overlay .deploy/prod.mtaext
```

Lo que puede ir en un `.mtaext`: parámetros de módulos (memoria, instancias,
routes), parámetros de recursos (nombres, configuración de XSUAA),
propiedades (variables de entorno). Lo que **no** debe ir: secretos. Para eso
están las destinations, Credential Store o variables inyectadas por el
pipeline.

> **Pendiente de validar.** El ejercicio completo de `prod` en el trial se
> ejecutará al final del curso. Esta sección se completará con las salidas
> reales.

## 14.3 El ejercicio "prod" en el trial, paso a paso

1. **Space.** `cf create-space prod` (o cockpit › Espacios › Crear).
2. **Instance mapping.** En HANA Cloud Central, que el mapping de `hana-trial`
   cubra la org entera o añada el space `prod`. Sin esto, el contenedor de
   prod no se puede crear.
3. **Entitlements.** Son de la subcuenta, así que ya valen para `prod`.
4. **`.mtaext`** de prod como en 14.2.
5. **Deploy.** `cf target -s prod && cf deploy … -e .deploy/prod.mtaext`.
6. **Comprobar.** `cf apps`, `cf services` en `prod`: segundo contenedor
   `bookshop-db` (distinto esquema `BOOKSHOP_DB_2` o similar, en la misma
   HANA), segunda XSUAA.
7. **Roles.** En Seguridad › Roles aparecerá un segundo rol `Admin` de la app
   `bookshop-prod…`. Hace falta otra role collection (`Bookshop_Admin_Prod`)
   o añadir ese rol a la existente. Es la demostración de que la XSUAA de
   prod es otra.
8. **Quitar la route pública de `srv`** en prod (capítulo 11.8) y comprobar
   que solo se entra por el approuter.

Resultado: dos entornos aislados a nivel de Cloud Foundry, con la misma HANA
debajo. En una empresa, los pasos 2 y 3 los haría el administrador en la
subcuenta de prod y el paso 5 lo haría el pipeline.

## 14.4 CI/CD en dos líneas

Un pipeline de despliegue a BTP hace exactamente lo que has hecho a mano:

```yaml
# .github/workflows/deploy.yml (esquema)
- run: npm ci
- run: npm test
- run: npx mbt build
- run: cf login -a $CF_API -u $CF_USER -p $CF_PASSWORD -o $CF_ORG -s $CF_SPACE
- run: cf deploy mta_archives/*.mtar -e .deploy/$ENV.mtaext -f
```

`cds add pipeline` (Jenkins/Piper) o `cds add github-actions` generan un
esqueleto. En empresas SAP es frecuente ver **SAP Continuous Integration and
Delivery** (servicio de BTP) o Jenkins con la librería Piper. Para prod, en
lugar de `cf deploy` directo, el pipeline sube el `.mtar` a **Cloud Transport
Management** y alguien aprueba el transporte.

Las credenciales del pipeline (`CF_USER`/`CF_PASSWORD`) deberían ser un
**usuario técnico** con Space Developer solo en el space destino, no una
persona.

## 14.5 La CLI de BTP

El cockpit tiene una hermana de línea de comandos, `btp`, que administra la
parte de **cuentas, entitlements y seguridad**: lo que `cf` no ve. No
sustituye a `cf`, la complementa.

```
   btp                                   cf
   cuenta global, directorios,           orgs, spaces, apps,
   subcuentas, entitlements,             instancias de servicio,
   suscripciones, role collections,      bindings, keys, routes,
   usuarios, trust                       logs, ssh
```

Instalación: binario descargado de `tools.hana.ondemand.com`, sin
dependencias. Se registra en `INSTALADO.md` como el resto.

```bash
btp login --sso                          # o sin --sso: pide subdominio de la cuenta global, usuario y contraseña
btp list accounts/subaccount
btp target --subaccount <id>             # a partir de aquí los comandos aplican a esa subcuenta
btp list accounts/entitlement
btp list accounts/subscription
btp list security/role-collection
btp get  security/role-collection "Subaccount Administrator"
btp list security/user
btp assign security/role-collection "Bookshop_Admin" --to-user mi@correo.com --of-idp sap.default
btp unassign security/role-collection "Bookshop_Admin" --to-user mi@correo.com --of-idp sap.default
btp --format json list accounts/subaccount    # salida para scripts
```

La estructura es siempre `btp <acción> <grupo>/<objeto> [opciones]`. Acciones:
`list`, `get`, `create`, `update`, `delete`, `assign`, `unassign`, `enable`,
`subscribe`. Grupos: `accounts`, `security`, `services`.

> **Pendiente de validar.** La `btp` CLI se instalará en el último módulo del
> curso. Los comandos están tomados de la referencia oficial y se contrastarán
> con la salida real.

Para qué sirve de verdad a un desarrollador:

- Comprobar en segundos si un entitlement está asignado sin navegar por el
  cockpit.
- Asignarse (o asignar a un usuario técnico de tests) una role collection
  desde un script de setup.
- Automatizar la creación de una subcuenta de pruebas con sus entitlements,
  roles y una org de CF, para una demo o un entorno efímero.

## 14.6 Trampas

> **Trampa.** Compartir HANA entre dev y prod "porque es un trial". En
> empresa, jamás. Y recuérdalo cuando el trial te lo haga parecer normal.

> **Trampa.** Meter secretos en un `.mtaext` y subirlo a git. Destinations,
> Credential Store o secretos del pipeline.

> **Trampa.** Desplegar a prod con el usuario personal desde el portátil.
> Aunque funcione, nadie sabe luego qué versión hay. Pipeline o cTMS.

> **Trampa.** Reutilizar la role collection `Bookshop_Admin` de dev para prod.
> Si están en la misma subcuenta (trial), son apps XSUAA distintas y hay que
> añadir ambos roles o crear otra colección. En subcuentas distintas, cada una
> tiene las suyas y hay que crearlas en cada una.

## Para recordar

- Empresa: una subcuenta por entorno, HANA propia, destinations con el mismo
  nombre, mismo `.mtar` + `.mtaext` por entorno, pipeline o cTMS para prod.
- Trial: segundo space `prod`, mismo `.mtar`, `-e prod.mtaext`, mapping de la
  HANA a la org.
- `.mtaext` sobrescribe parámetros, nunca lleva secretos.
- `btp` administra cuentas y seguridad; `cf` administra el runtime. Juntas
  cubren todo el cockpit.

## Ejercicio

1. Crea el space `prod`, ajusta el mapping y despliega bookshop con un
   `prod.mtaext` que ponga dos instancias de `srv`. Comprueba con
   `cf target -s prod && cf mta bookshop`.
2. Comprueba en el Database Explorer que hay dos contenedores en la misma
   HANA y en Seguridad › Roles que hay dos roles `Admin` de apps distintas.
3. Instala la `btp` CLI (apuntándolo en `INSTALADO.md`), haz login, lista
   entitlements y role collections y asígnate `Bookshop_Admin` desde la CLI.
4. Escribe en diez líneas cómo sería este mismo despliegue en tu empresa: qué
   haría el admin, qué haría el pipeline y qué harías tú.
