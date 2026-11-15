# 4. Cloud Foundry para desarrolladores

**Objetivo del capítulo.** Entender qué le pasa a tu código cuando lo
despliegas en Cloud Foundry, qué ves en el cockpit y cómo lo inspeccionas
desde la CLI. Este capítulo es la base del resto de comandos `cf` del libro.

## 4.1 Qué hace Cloud Foundry con una app

Cloud Foundry (CF) es un PaaS de código abierto. BTP lo usa como runtime
estándar. Cuando le entregas una aplicación, hace siempre lo mismo:

```
   cf push / cf deploy
          │
          ▼
  1. SUBIDA     tu código (o el .mtar) llega al Cloud Controller
          │
          ▼
  2. STAGING    elige un BUILDPACK (nodejs_buildpack para CAP), instala
     ("stage")  dependencias y produce un DROPLET: la imagen ejecutable
          │
          ▼
  3. ARRANQUE   crea N INSTANCIAS (contenedores) del droplet con la memoria
                pedida e inyecta variables de entorno: PORT, VCAP_SERVICES…
          │
          ▼
  4. ROUTE      publica una URL pública y la enruta a las instancias.
                Si la app deja de responder al health check, la marca
                CRASHED y la reinicia.
```

| Término   | Qué es                                                                              |
|-----------|-------------------------------------------------------------------------------------|
| Buildpack | La receta que convierte tu código en algo ejecutable. Detecta `package.json` → Node |
| Droplet   | El resultado del staging: código + dependencias + runtime, listo para arrancar       |
| Instancia (de app) | Un contenedor corriendo el droplet. `cf scale -i 3` → tres copias           |
| Route     | URL pública mapeada a la app. Una app sin route no es accesible desde fuera          |
| Health check | Comprobación periódica. Por defecto, que la app escuche en el puerto `PORT`       |
| Stack     | El sistema operativo base del contenedor (`cflinuxfs4`)                             |

> **Analogía.** Cloud Foundry es a BTP lo que Heroku a AWS. Haces `cf deploy`
> y te olvidas de servidores, sistemas operativos y balanceadores. Buildpack =
> buildpack de Heroku; droplet = slug; route = la URL `*.herokuapp.com`.

> **Para un dev CAP.** CAP lee `VCAP_SERVICES` al arrancar y liga cada servicio
> por su etiqueta: la entrada de tipo `hana` se convierte en tu base de datos
> y la de tipo `xsuaa` en tu autenticación. Por eso en producción no hay
> ninguna configuración apuntando a SQLite: el binding manda. Cuando una app
> CAP arranca y muere con "no database", casi siempre falta un binding.

## 4.2 Qué ves en el cockpit

> **Cockpit:** Subcuenta › Cloud Foundry › Espacios › dev › Aplicaciones
> (*Subaccount › Cloud Foundry › Spaces › dev › Applications*)

La lista muestra cada app con su estado (*Started*, *Stopped*, *Crashed*),
número de instancias, memoria y disco. Al entrar en una app:

| Pestaña                | Qué contiene                                                      | Lo usarás para…                                             |
|------------------------|-------------------------------------------------------------------|-------------------------------------------------------------|
| Visión general         | Estado, instancias corriendo, buildpack, botones Start/Stop/Restart/Restage | Ver si está viva; reiniciarla                     |
| Rutas (*Routes*)       | Las URLs públicas                                                 | Copiar la URL para probar. Ver que `srv` **no** tiene route si va tras un approuter |
| Enlaces de servicio (*Service Bindings*) | Instancias ligadas                              | Comprobar que `srv` ve el contenedor HDI y la XSUAA          |
| Variables de entorno   | Las de usuario y las de sistema, con `VCAP_SERVICES` completo     | Depurar configuración. **Cuidado: aquí se ven secretos**     |
| Registros (*Logs*)     | Los últimos minutos                                               | Primera mirada. Para investigar en serio, la CLI             |
| Eventos (*Events*)     | Quién hizo qué y cuándo                                           | Saber quién reinició la app anoche                           |

## 4.3 La CLI, tu herramienta real

Todo lo anterior se ve mejor y más rápido desde `cf`. Estos son los comandos
que usarás a diario, con su salida en el trial.

### Dónde estoy

```bash
cf target
```

```
API endpoint:   https://api.cf.us10-001.hana.ondemand.com
API version:    3.209.0
user:           ********
org:            7b6c2113trial
space:          dev
```

### Qué hay en el space

```bash
cf apps
```

```
Getting apps in org 7b6c2113trial / space dev as ********...

name                   requested state   processes           routes
bookshop               started           web:1/1             7b6c2113trial-dev-bookshop.cfapps.us10-001.hana.ondemand.com
bookshop-srv           started           web:1/1             7b6c2113trial-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com
bookshop-db-deployer   stopped           web:0/1
```

```bash
cf services
```

```
Getting service instances in org 7b6c2113trial / space dev as ********...

name            offering   plan          bound apps                           last operation     broker
bookshop-auth   xsuaa      application   bookshop, bookshop-srv               create succeeded   xsuaa
bookshop-db     hana       hdi-shared    bookshop-db-deployer, bookshop-srv   create succeeded   hana-broker
```

Estas dos salidas son la foto completa del space. El `db-deployer` en
*stopped* es normal: es una app que arranca, despliega el esquema y termina
(capítulo 11).

> **Pendiente de validar.** Las salidas de `cf apps` y `cf services` con
> bookshop desplegado se sustituirán por las reales tras el primer despliegue.

### Detalle de una app

```bash
cf app bookshop-srv
```

```
Showing health and status for app bookshop-srv in org 7b6c2113trial / space dev as ********...

name:              bookshop-srv
requested state:   started
routes:            7b6c2113trial-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com
last uploaded:     Fri 14 Nov 18:02:11 CET 2026
stack:             cflinuxfs4
buildpacks:
        name                     version   detect output   buildpack name
        nodejs_buildpack         1.8.x     nodejs          nodejs

type:            web
sidecars:
instances:       1/1
memory usage:    256M
     state     since                  cpu    memory          disk           logging
#0   running   2026-11-14T17:02:30Z   0.3%   112.5M of 256M  210.3M of 1G   0B/s
```

Aquí ves de un vistazo: estado, cuántas instancias hay vivas, cuánta memoria
consume frente a la asignada (si está cerca del límite, los reinicios por
memoria están al caer) y qué buildpack se usó.

### Logs

```bash
cf logs bookshop-srv --recent     # lo último que ha escrito
cf logs bookshop-srv              # en vivo, Ctrl+C para salir
```

```
Retrieving logs for app bookshop-srv in org 7b6c2113trial / space dev as ********...

   2026-11-14T17:02:28.11+0100 [STG/0] OUT -----> Installing node 22.x
   2026-11-14T17:02:29.80+0100 [CELL/0] OUT Starting health monitoring of container
   2026-11-14T17:02:31.02+0100 [APP/PROC/WEB/0] OUT [cds] - loaded model from 2 file(s):
   2026-11-14T17:02:31.02+0100 [APP/PROC/WEB/0] OUT   srv/cat-service.cds
   2026-11-14T17:02:31.35+0100 [APP/PROC/WEB/0] OUT [cds] - connect to db > hana {
   2026-11-14T17:02:31.90+0100 [APP/PROC/WEB/0] OUT [cds] - serving CatalogService { path: '/odata/v4/catalog' }
   2026-11-14T17:02:31.91+0100 [APP/PROC/WEB/0] OUT [cds] - server listening on { url: 'http://localhost:8080' }
   2026-11-14T17:02:32.40+0100 [CELL/0] OUT Container became healthy
```

Cada línea lleva un origen entre corchetes:

| Origen            | Quién escribe                                            |
|-------------------|----------------------------------------------------------|
| `[STG/0]`         | El staging (buildpack instalando cosas)                  |
| `[CELL/0]`        | La celda que ejecuta el contenedor: arranque, health check, muerte |
| `[APP/PROC/WEB/0]`| Tu aplicación, instancia 0. Es lo que escribes en stdout |
| `[RTR/0]`         | El router: una línea por petición HTTP, con código y tiempo |
| `[API/0]`         | El Cloud Controller: quién hizo `cf stop`, `cf restart`… |

> **Idea clave.** Si la app muere al arrancar, la causa está en las últimas
> líneas `[APP/…]` antes del primer `[CELL/0] OUT Exit status`. Si muere al
> rato, busca `[CELL/0]` con *out of memory* o `[API/0]` con *crashed*.

### Variables de entorno

```bash
cf env bookshop-srv
```

```
Getting env variables for app bookshop-srv in org 7b6c2113trial / space dev as ********...

System-Provided:
VCAP_SERVICES: {
  "hana": [
    {
      "label": "hana",
      "plan": "hdi-shared",
      "name": "bookshop-db",
      "tags": [ "hana", "database", "relational" ],
      "credentials": {
        "host": "....hana.trial-us10.hanacloud.ondemand.com",
        "port": "443",
        "user": "BOOKSHOP_DB_1_RT",
        "password": "<secreto>",
        "schema": "BOOKSHOP_DB_1",
        ...
      }
    }
  ],
  "xsuaa": [ { "label": "xsuaa", "plan": "application", "name": "bookshop-auth", "credentials": { ... } } ]
}

VCAP_APPLICATION: { "application_name": "bookshop-srv", "space_name": "dev", "uris": [ ... ], ... }

User-Provided:
(ninguna)
```

Esto es exactamente lo que recibe tu proceso Node. CAP recorre
`VCAP_SERVICES` y, por las etiquetas `tags`, decide qué entrada es la base de
datos y cuál la autenticación. El capítulo 6 desmenuza este JSON.

### Controlar el ciclo de vida

```bash
cf stop bookshop-srv
cf start bookshop-srv
cf restart bookshop-srv       # parar y arrancar: nuevas variables de entorno, mismo droplet
cf restage bookshop-srv       # volver a pasar el buildpack: nuevo droplet. Necesario tras cambiar bindings
cf scale bookshop-srv -i 2    # dos instancias
cf scale bookshop-srv -m 512M # más memoria (reinicia la app)
```

Cuándo usar cada uno:

| Cambio                                       | Comando      |
|----------------------------------------------|--------------|
| Nada, solo quiero que arranque de cero       | `restart`    |
| He cambiado una variable con `cf set-env`    | `restart`    |
| He hecho `cf bind-service` o `unbind-service`| `restage`    |
| He subido código nuevo                       | `cf push` / `cf deploy` lo hacen solos |

### Entrar en el contenedor

```bash
cf ssh bookshop-srv
```

```
vcap@a1b2c3d4-...:~$ ls app
node_modules  package.json  srv  gen ...
vcap@a1b2c3d4-...:~$ echo $PORT
8080
vcap@a1b2c3d4-...:~$ exit
```

Útil para ver qué ficheros llegaron de verdad al droplet o probar
conectividad desde dentro (`curl` a la base de datos, por ejemplo). Requiere
que SSH esté permitido en el space y la app (`cf ssh-enabled bookshop-srv`).

### Eventos

```bash
cf events bookshop-srv
```

```
time                          event                      actor      description
2026-11-14T17:02:11.00+0100   audit.app.update           ********   state: STARTED
2026-11-14T17:01:50.00+0100   audit.app.droplet.create   ********
2026-11-14T17:00:02.00+0100   audit.app.update           ********   state: STOPPED
```

Es la pestaña *Eventos* del cockpit. Responde a "¿quién paró esto?".

## 4.4 Roles de Cloud Foundry

Cloud Foundry tiene su propio modelo de permisos, **independiente** de las
role collections de BTP (capítulo 8). Son pocos y claros:

| Rol              | Nivel | Puede                                                        |
|------------------|-------|--------------------------------------------------------------|
| Org Manager      | Org   | Crear y borrar spaces, asignar roles en la org y sus spaces  |
| Org Auditor      | Org   | Ver la org y sus spaces, sin tocar                           |
| Space Manager    | Space | Añadir y quitar miembros del space                           |
| Space Developer  | Space | **Desplegar, parar, arrancar, ligar servicios, ver logs y env.** El que necesitas para trabajar |
| Space Auditor    | Space | Ver el space sin tocar. No ve `cf env` completo              |

> **Cockpit:** Subcuenta › Cloud Foundry › Espacios › dev › Miembros
> (*Spaces › dev › Members*) y Subcuenta › Cloud Foundry › Miembros de la
> organización (*Org Members*).

```bash
cf space-users 7b6c2113trial dev
```

```
Getting users in org 7b6c2113trial / space dev as ********...

SPACE MANAGER
  ********

SPACE DEVELOPER
  ********

SPACE AUDITOR
```

```bash
cf set-space-role compañero@empresa.com 7b6c2113trial dev SpaceDeveloper
cf unset-space-role compañero@empresa.com 7b6c2113trial dev SpaceDeveloper
cf set-org-role compañero@empresa.com 7b6c2113trial OrgManager
```

> **Trampa.** Puedes ser Subaccount Administrator en BTP y no poder desplegar
> en un space porque nadie te hizo Space Developer. Son dos sistemas de
> permisos distintos. Cuando pidas acceso, pide las dos cosas y sé concreto:
> "Space Developer en el space `dev` de la subcuenta `ventas-dev`".

## 4.5 Trampas

> **Trampa.** `cf restart` **no** recoge cambios de bindings. Tras
> `cf bind-service` hay que hacer `cf restage`. El cockpit lo recuerda con un
> aviso; la CLI no.

> **Trampa.** `cf logs --recent` solo guarda unos minutos o unos KB. Si la app
> lleva horas corriendo, lo que buscas ya no está. Para retención real hace
> falta Application Logging o SAP Cloud Logging (capítulo 13).

> **Trampa.** Una app CAP `srv` **con** route pública es accesible sin pasar
> por el approuter. Si no hay autenticación configurada (XSUAA), cualquiera
> puede leer tus datos. En el capítulo 11 se ve cómo quitarle la route.

## Para recordar

- CF recibe código → buildpack → droplet → N instancias con variables de
  entorno → route. Si no responde, *Crashed* y reinicio.
- Los cinco comandos del día a día: `cf apps`, `cf services`, `cf app X`,
  `cf logs X --recent`, `cf env X`.
- `restart` para variables, `restage` para bindings.
- Roles de CF (Space Developer) ≠ role collections de BTP. Hacen falta los dos.
- `[APP/PROC/WEB/0]` son tus logs; `[CELL/0]` es la plataforma hablando de tu
  contenedor.

## Ejercicio

1. Haz `cf login` y ejecuta `cf apps`, `cf services` y `cf target`. Compara
   con lo que ves en el cockpit.
2. Ejecuta `cf space-users` y `cf org-users` sobre tu org. ¿Qué roles tienes?
3. Cuando tengas bookshop desplegado (capítulo 11): párala desde el cockpit,
   comprueba con `cf apps` que está *stopped*, arráncala desde la CLI y mira en
   `cf events` quién hizo cada cosa.
