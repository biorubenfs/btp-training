# C. Referencia de la CLI de BTP (`btp`)

> **Pendiente de validar.** La `btp` CLI aún no está instalada en la máquina
> del libro. Esta referencia está tomada de la documentación oficial y se
> contrastará con la salida real en el capítulo 14.

## C.1 Instalación

Binario único, sin dependencias, descargado de SAP Development Tools
(`tools.hana.ondemand.com/#cloud-btpcli`). En Linux:

```bash
mkdir -p ~/.local/bin
tar -xzf btp-cli-linux-amd64-*.tar.gz
mv linux-amd64/btp ~/.local/bin/
btp --version
```

Configuración en `~/.config/btp` (o `~/.btp`). Desinstalar: borrar el binario
y esa carpeta.

## C.2 Estructura de los comandos

```
btp [opciones globales] <acción> <grupo>/<objeto> [parámetros]
```

| Acción      | Significado                          |
|-------------|--------------------------------------|
| `list`      | Listar                               |
| `get`       | Detalle de uno                       |
| `create`    | Crear                                |
| `update`    | Modificar                            |
| `delete`    | Borrar                               |
| `assign` / `unassign` | Asignar entitlements o role collections |
| `enable`    | Habilitar un entorno                 |
| `subscribe` / `unsubscribe` | Suscripciones             |
| `add` / `remove` | Añadir roles a colecciones, etc.|

| Grupo       | Objetos                                                                 |
|-------------|-------------------------------------------------------------------------|
| `accounts`  | `global-account`, `directory`, `subaccount`, `entitlement`, `environment-instance`, `subscription`, `available-region`, `label` |
| `security`  | `role-collection`, `role`, `user`, `trust`, `app`, `api-credential`     |
| `services`  | `offering`, `plan`, `instance`, `binding`, `broker`, `platform`        |

## C.3 Sesión

```bash
btp login --sso                 # navegador
btp login                       # pide URL de la CLI, subdominio de la cuenta global, usuario, contraseña
btp logout
btp --info                      # dónde estoy: cuenta global, subcuenta objetivo
btp target --subaccount <id>    # fija la subcuenta para los comandos siguientes
btp target --global-account     # vuelve al nivel global
```

## C.4 Cuentas

```bash
btp list accounts/subaccount
btp get  accounts/subaccount <id>
btp list accounts/available-region
btp create accounts/subaccount --display-name sandbox --subdomain acme-sandbox --region eu10
btp delete accounts/subaccount <id>
btp list accounts/entitlement                   # de la cuenta global
btp list accounts/entitlement --subaccount <id> # de una subcuenta
btp assign accounts/entitlement --to-subaccount <id> --for-service hana --plan hdi-shared --enable
btp assign accounts/entitlement --to-subaccount <id> --for-service hana-cloud --plan hana --amount 1
btp list accounts/environment-instance          # orgs de CF, Kyma…
btp create accounts/environment-instance --environment cloudfoundry --service cloudfoundry --plan standard --display-name acme-org
btp list accounts/subscription
btp subscribe accounts/subaccount --to-app sapappstudio --plan standard-edition
```

## C.5 Seguridad

```bash
btp list security/role-collection
btp get  security/role-collection "Subaccount Administrator"
btp create security/role-collection Bookshop_Admin --description "Administradores de bookshop"
btp list security/role                          # roles de apps y plataforma en la subcuenta
btp add  security/role Admin --to-role-collection Bookshop_Admin \
         --of-app bookshop-7b6c2113trial-dev!t12345 --of-role-template Admin
btp list security/user
btp get  security/user mi@correo.com --of-idp sap.default
btp assign   security/role-collection Bookshop_Admin --to-user mi@correo.com --of-idp sap.default
btp unassign security/role-collection Bookshop_Admin --to-user mi@correo.com --of-idp sap.default
btp assign   security/role-collection Bookshop_Admin --to-group "ventas-admins" --of-idp <ias-origin>
btp list security/trust                         # proveedores de identidad conectados
```

## C.6 Servicios (también desde `btp`)

```bash
btp list services/offering
btp list services/plan --offering-name hana
btp list services/instance                      # instancias de la subcuenta (incluye las de Other)
btp create services/instance --offering-name destination --plan-name lite --name dest-test
btp create services/binding --name key1 --instance-name dest-test
btp get services/binding --name key1 --show-parameters
```

Estos comandos operan sobre el *Service Manager* de BTP, que ve instancias de
todos los entornos. Para las del space de CF, `cf services` es más directo.

## C.7 Salida para scripts

```bash
btp --format json list accounts/subaccount | jq '.value[] | {displayName, region, subdomain}'
btp --format json list security/role-collection | jq -r '.[].name'
```

## C.8 `btp` frente a `cf`

| Quiero…                                   | Herramienta  |
|-------------------------------------------|--------------|
| Ver o asignar entitlements                | `btp`        |
| Crear una subcuenta o un directorio       | `btp`        |
| Crear o asignar role collections          | `btp`        |
| Ver suscripciones                         | `btp`        |
| Desplegar, ver logs, escalar              | `cf`         |
| Instancias, keys y bindings de un space   | `cf` (o `btp services/…`) |
| Crear o borrar spaces                     | `cf`         |
| Roles de CF (Space Developer)             | `cf`         |
