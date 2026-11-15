# 7. SAP HANA Cloud y HDI

**Objetivo del capítulo.** Deshacer la confusión más común de BTP: qué es
"una instancia de SAP HANA Cloud", qué es un contenedor HDI, qué es un esquema
y por qué tu app nunca toca la base de datos "a mano". Es el capítulo más
largo del libro porque es donde más tiempo se pierde.

## 7.1 La idea en una frase

> **Idea clave.** "Instancia de SAP HANA Database" **no** es la base de datos
> de tu app. Es el **servidor de base de datos entero**, gestionado por SAP,
> uno por subcuenta. Las apps reciben dentro de él un trozo aislado llamado
> **contenedor HDI**, que nace solo al desplegar.

## 7.2 Las cuatro palabras que se confunden

| Término               | Qué es realmente                                                                                   | Equivalente en Postgres                                    |
|-----------------------|----------------------------------------------------------------------------------------------------|------------------------------------------------------------|
| Instancia HANA Cloud  | El servidor: CPU, memoria, disco. Se crea con el entitlement `hana-cloud`. Vive en la subcuenta    | Un servidor Postgres en RDS                                |
| Base de datos         | Una sola por instancia. En HANA Cloud no se crean varias                                           | Una única `database`                                       |
| Esquema               | Espacio de nombres para tablas, como en cualquier SQL: `ESQUEMA.TABLA`                             | Un `schema`                                                |
| Contenedor HDI        | **Dos esquemas + dos usuarios** que HDI crea y gestiona como un paquete. Lo pide la app con el servicio `hana` / `hdi-shared`. Vive en el space | Un schema por app con grants solo a su owner, automatizado |

Un detalle de HANA que cambia la forma de pensar: **cada usuario tiene
automáticamente un esquema con su mismo nombre**. El esquema `DBADMIN` no es
"el contenedor de todo", es solo el esquema personal del administrador y
normalmente está vacío. Los contenedores HDI están **al mismo nivel** que él,
no dentro.

```
SUBCUENTA trial
└── Instancia SAP HANA Cloud "hana-trial"     ← el servidor (servicio hana-cloud)
     │                                           creado en HANA Cloud Central
     └── Base de datos (una sola)
          ├── esquemas SYS, _SYS_BI…           ← sistema
          ├── esquema DBADMIN                  ← el personal del admin, vacío
          │
          ├── esquema BOOKSHOP_DB_1            ┐  contenedor HDI "bookshop-db"
          ├── esquema BOOKSHOP_DB_1#DI         │  (servicio hana / hdi-shared,
          ├── usuario BOOKSHOP_DB_1_RT         │   vive en el space dev;
          ├── usuario BOOKSHOP_DB_1_DT         │   todo esto lo crea HDI junto)
          └── usuario BOOKSHOP_DB_1#OO         ┘
          │
          └── esquemas y usuarios de otra app  ← otro contenedor, aislado:
                                                  no ve las tablas de bookshop
```

Qué hay dentro de un contenedor:

- **Esquema de runtime** (`BOOKSHOP_DB_1`): aquí viven las tablas. El nombre
  lo genera HDI, no lo eliges tú.
- **Esquema de despliegue** (`BOOKSHOP_DB_1#DI`): guarda los ficheros
  `.hdbtable` y el estado de lo ya desplegado. Es la tabla de migraciones
  aplicadas.
- **Usuarios técnicos**: `_RT` (runtime, lo usa la app para leer y escribir),
  `_DT` (design time, lo usa el deployer para crear tablas) y `#OO` (object
  owner, el dueño de los objetos). Los únicos con permisos sobre esos
  esquemas. La app recibe `_RT` por binding; el deployer recibe `_DT`.

Son esquemas normales de HANA. Si entras con `DBADMIN` al Database Explorer
los ves listados junto al resto. La diferencia con un esquema creado a mano es
que HDI es su dueño, tú no tienes grants sobre ellos y no debes tocarlos
directamente.

> **Analogía.** Un servidor Postgres con una única database, donde cada app
> tiene su schema y solo su owner tiene permisos sobre él. HDI automatiza ese
> patrón y lo hace obligatorio. El aislamiento no lo da el esquema en sí, lo
> dan los permisos atados a los usuarios del contenedor.

## 7.3 ¿Necesito "dos bases de datos"?

| Qué necesito                                          | Qué creo                                        | Entitlement                      |
|-------------------------------------------------------|-------------------------------------------------|----------------------------------|
| Dos apps con datos aislados (caso normal)             | Dos contenedores HDI en la misma instancia      | `hana` / `hdi-shared`, dos veces |
| Dos entornos con recursos separados (dev y prod)      | Dos instancias HANA Cloud, una por subcuenta    | `hana-cloud`, dos veces          |
| Dos "databases" en el sentido Postgres                | No existe en HANA Cloud                         | —                                |

> **En el trial.** Solo cabe **una instancia** de HANA Cloud. Cuando se
> despliegue bookshop en el space `prod` (capítulo 14), tendrá un segundo
> contenedor HDI dentro de la misma instancia `hana-trial`. En una empresa,
> dev y prod tendrían instancias distintas en subcuentas distintas.

| Pieza                | Equivalente conocido         | Quién lo crea                             | ¿Sale en `cf services`?      |
|----------------------|------------------------------|-------------------------------------------|------------------------------|
| Instancia HANA Cloud | Servidor Postgres en RDS     | El admin, una vez, en HANA Cloud Central  | No: vive en la subcuenta     |
| Contenedor HDI       | Schema con su usuario owner  | La app al desplegar (`cf deploy`)         | Sí: vive en el space         |
| Tablas y vistas      | Lo que crean las migraciones | CAP, desde el modelo `.cds`               | —                            |

## 7.4 Crear la instancia de HANA Cloud

Es el único paso manual, se hace una vez por subcuenta, y lo hace quien
tenga la role collection *SAP HANA Cloud Administrator*.

> **Cockpit:** Subcuenta › Instancias y suscripciones › SAP HANA Cloud › Ir a
> la aplicación (abre **SAP HANA Cloud Central**) › Crear instancia (*Create
> Instance*) › SAP HANA Cloud, SAP HANA Database.

Las decisiones del asistente que importan:

| Pantalla               | Qué elegir                                              | Por qué                                                                        |
|------------------------|---------------------------------------------------------|--------------------------------------------------------------------------------|
| Tipo                   | SAP HANA Cloud, SAP HANA Database                       | Es la base de datos relacional. Data Lake es otra cosa                         |
| Nombre                 | `hana-trial`                                            | Cualquiera. Aparecerá en HANA Cloud Central y en los mapeos                    |
| Contraseña DBADMIN     | Una fuerte, guardada fuera del repo                     | Es el superusuario del servidor. No la usará ninguna app                       |
| Tamaño                 | El mínimo (trial: fijo)                                 | En empresa, se factura por hora encendida                                      |
| Conexiones permitidas  | **Allow all IP addresses**                              | Si solo permites IPs de BTP, tu portátil no podrá conectar en modo híbrido     |
| Instance mapping       | Org `7b6c2113trial`, space `dev` (o solo la org)        | Sin esto, las apps no pueden crear contenedores. Ver 7.6                        |

La creación tarda unos minutos. Después, la instancia aparece en HANA Cloud
Central con estado *Running* y en el cockpit, en *Instancias y suscripciones*,
como instancia del servicio `SAP HANA Cloud` (entorno *Other*).

> **En el trial.** La instancia **se para automáticamente cada noche**. Cada
> día, antes de trabajar: HANA Cloud Central › la instancia › ⋮ › *Start*.
> Si está parada, todo lo demás falla con errores de conexión que no mencionan
> que esté parada.

## 7.5 HDI: qué es exactamente

**HDI** (HANA Deployment Infrastructure) es ese paquete de esquemas aislados
más un **mecanismo de despliegue**. No escribes `CREATE TABLE`: CAP genera
ficheros declarativos (`.hdbtable`, `.hdbview`, `.hdbindex`…) y HDI calcula y
aplica las diferencias contra lo que anotó en el esquema `#DI`. Es como tener
un sistema de migraciones dentro de la propia base de datos.

Lo que genera `cds build --production` para el modelo de bookshop:

```
gen/db/
├── package.json              # depende de @sap/hdi-deploy
├── src/
│   ├── .hdiconfig            # qué plugin HDI maneja cada extensión
│   ├── .hdinamespace
│   ├── gen/
│   │   ├── CatalogService.Books.hdbtable
│   │   └── data/
│   │       ├── CatalogService.Books.csv
│   │       └── CatalogService.Books.hdbtabledata
│   └── undeploy.json         # qué puede borrarse al desplegar
└── ...
```

```sql
-- gen/db/src/gen/CatalogService.Books.hdbtable
COLUMN TABLE CatalogService_Books (
  ID INTEGER NOT NULL,
  title NVARCHAR(5000),
  author NVARCHAR(5000),
  PRIMARY KEY(ID)
)
```

Fíjate: es casi SQL, pero sin `CREATE`. Describe el estado deseado. HDI
compara con el `#DI`, y si la tabla existe con otra columna, hace el `ALTER`
él. Si borras una entidad del modelo, la tabla **no** se borra a menos que
esté listada en `undeploy.json` (o uses `--auto-undeploy`), para que no
pierdas datos por accidente.

### Qué crea de verdad un contenedor

Consultado en `SYS.SCHEMAS` como `DBADMIN` justo después de
`cf create-service hana hdi-shared test-hdi` y de una `cf create-service-key`
(contenedor de prueba creado en el trial el 2026-11-15):

| Esquema                       | Creado por      | Qué es                                                                                   |
|-------------------------------|-----------------|------------------------------------------------------------------------------------------|
| `BA43A1B0…`                   | la instancia    | El esquema de **datos**: aquí van las tablas y vistas que despliega CAP                   |
| `BA43A1B0…#DI`                | la instancia    | El esquema de **despliegue**: los ficheros desplegados, su estado y los procedimientos HDI |
| `BA43A1B0…#OO`                | la instancia    | El **object owner**: el usuario técnico dueño de todas las tablas del esquema de datos     |
| `BA43A1B0…_<sufijo>_DT`       | la service key  | Usuario *design time*, el que usa el deployer. Su esquema personal está vacío              |
| `BA43A1B0…_<sufijo>_RT`       | la service key  | Usuario *runtime*, el que usa la app. Su esquema personal está vacío                       |

Tres cosas que se deducen de la tabla:

1. El nombre del esquema **no** es el de la instancia (`test-hdi`,
   `bookshop-db`), sino un identificador hexadecimal generado. El nombre de
   la instancia solo existe en Cloud Foundry.
2. Los usuarios `_DT` y `_RT` nacen con **cada key o binding**, no con el
   contenedor. Dos keys = dos parejas de usuarios con sufijos distintos. Al
   borrar la key desaparecen, y las tablas siguen intactas. Aparecen como
   esquemas porque en HANA cada usuario tiene automáticamente un esquema con
   su nombre (`DBADMIN` también).
3. `HAS_PRIVILEGES` es `FALSE` para `DBADMIN` en los cinco. El contenedor es
   un recinto cerrado: se entra con las credenciales de la key, no con las
   del administrador.

## 7.6 Cómo nace el contenedor al desplegar

Una app CAP necesita como mínimo un contenedor HDI, y las tablas van en su
esquema de runtime. Pero **nada de eso se crea a mano**. En el proyecto solo
tocas dos cosas:

- **El modelo**, en ficheros `.cds`: entidades con sus campos.
- **La dependencia**, en `mta.yaml`: un `resource` de tipo
  `com.sap.xs.hdi-container` con `service: hana`, `service-plan: hdi-shared`.

A partir de ahí la cadena es automática:

```
 .cds ──cds build──▶ gen/db/*.hdbtable ──cf deploy──▶ broker hana crea el contenedor
                                                        (2 esquemas + 3 usuarios)
                                                               │
                                                      bookshop-db-deployer (app efímera)
                                                      entra como _DT y pasa los
                                                      .hdbtable a HDI
                                                               │
                                                      HDI crea/modifica tablas en
                                                      BOOKSHOP_DB_1 y anota en #DI
                                                               │
                                                      bookshop-srv recibe el usuario
                                                      _RT por binding y empieza a leer
```

1. `cds build --production` traduce el modelo a `.hdbtable` y `.hdbview` en
   `gen/db`.
2. `cf deploy` ve que el `mta.yaml` requiere una instancia `bookshop-db` de
   `hana` / `hdi-shared` y la pide al broker. Si no existe, la crea: ahí
   nacen los esquemas y usuarios.
3. El **db deployer** (`bookshop-db-deployer`, módulo `type: hdb`) es una app
   que arranca, se conecta con el usuario `_DT`, le pasa los `.hdbtable` a HDI
   y termina. HDI calcula las diferencias y las aplica en el esquema de
   runtime, anotando el estado en `#DI`. Por eso el deployer aparece como
   *stopped* en el cockpit: ha hecho su trabajo.
4. `bookshop-srv` recibe las credenciales de `_RT` por binding y empieza a
   leer y escribir.

El orden mental es el inverso a "primero creo el contenedor y luego las
tablas": describes el modelo, declaras la dependencia, y el contenedor con sus
tablas aparece como consecuencia del despliegue. El único paso manual previo
es el instance mapping.

> **Lo que verás en el cockpit.** Tras el primer deploy, en el space aparece
> una instancia `bookshop-db` del servicio `hana`, plan `hdi-shared`. Esa
> entrada **es** el contenedor. Si la borras, se van los esquemas, los
> usuarios y los datos.

## 7.7 El instance mapping

El servidor HANA vive en la subcuenta, pero los contenedores HDI se piden
desde un space de Cloud Foundry. El **mapping** conecta los dos: le dice al
broker `hana` de una org (y opcionalmente un space) "crea los contenedores en
esta instancia".

```
Instancia HANA "hana-trial"  ──mapping──▶  org 7b6c2113trial / space dev
                                             └─ aquí ya se pueden crear
                                                contenedores HDI
```

> **Cockpit:** HANA Cloud Central › instancia › ⋮ › Manage Configuration ›
> Instance Mapping. Se puede mapear a la org entera (todos los spaces) o a un
> space concreto. Para el ejercicio de "prod" del capítulo 14 hará falta que
> el mapping cubra la org o los dos spaces.

Sin mapping, el despliegue falla al crear el contenedor con un error del
broker parecido a:

```
Service broker error: Service broker hana-broker failed with: no HANA database found for ...
```

## 7.8 Mirar dentro: Database Explorer

Para ver las tablas de verdad hay dos caminos.

**Como administrador**, con `DBADMIN`: HANA Cloud Central › instancia › ⋮ ›
Open in SAP HANA Database Explorer. Cuidado con una trampa: el navegador de
objetos (Catalog › Schemas y el buscador *Search Schemas*) **solo lista los
esquemas sobre los que tu usuario tiene privilegios**, y `DBADMIN` no los
tiene sobre los contenedores. Buscar ahí el esquema de la key no devuelve
nada. Para ver que existen hay que preguntar al catálogo del sistema desde la
consola SQL (icono *SQL* arriba a la izquierda):

```sql
SELECT SCHEMA_NAME, SCHEMA_OWNER, HAS_PRIVILEGES, CREATE_TIME
FROM SYS.SCHEMAS
ORDER BY CREATE_TIME DESC;
```

Los `_SYS_*`, `SAP_*` y `BROKER_*` son de sistema. Cada grupo con el mismo
prefijo hexadecimal (`XXXX`, `XXXX#DI`, `XXXX#OO` y los `_DT`/`_RT`) es un
contenedor. `DBADMIN` ve que están, pero no puede abrirlos ni leer sus tablas.
Y aunque se diera privilegios a sí mismo, no debe escribir en ellos: HDI no
se enteraría y el siguiente deploy podría fallar.

**Como la app**, con el usuario del contenedor: crea una service key de
`bookshop-db` y añade la conexión al Database Explorer con esas credenciales.
Verás solo el esquema de runtime, exactamente lo que ve tu código.

```bash
cf create-service-key bookshop-db explorer-key
cf service-key bookshop-db explorer-key      # host, port, user, password, schema
```

Desde la terminal, la forma más rápida de comprobar que las tablas están es
el propio CAP en modo híbrido (capítulo 12):

```bash
cds bind -2 bookshop-db
cds watch --profile hybrid
curl localhost:4004/odata/v4/catalog/Books
```

## 7.9 Las tres instancias y los tres nombres

Para fijar ideas, las palabras "instancia" que aparecen en una app CAP con
HANA, y qué es cada una:

| Lo que ves                                   | Qué es                                            | Dónde                                    |
|----------------------------------------------|---------------------------------------------------|------------------------------------------|
| Instancia `hana-trial` (SAP HANA Cloud)      | El servidor                                       | Subcuenta; HANA Cloud Central            |
| Instancia `bookshop-db` (hana / hdi-shared)  | El contenedor HDI: esquemas + usuarios             | Space `dev`; `cf services`               |
| Instancia `#0` de `bookshop-srv`             | Un contenedor de Cloud Foundry corriendo tu app   | Space `dev`; `cf app bookshop-srv`       |

## 7.10 Trampas

> **Trampa.** Buscar las tablas en el esquema `DBADMIN`. Están en
> `BOOKSHOP_DB_1`, al lado, no dentro.

> **Trampa.** Crear tablas a mano en el esquema del contenedor. El siguiente
> deploy fallará o las ignorará. Todo cambio de esquema pasa por el modelo
> `.cds` y por el deployer.

> **Trampa.** Borrar la instancia `bookshop-db` "para limpiar". Es el
> contenedor: se van los datos. Para redesplegar de cero sin perder la
> instancia basta con `cf deploy` otra vez.

> **Trampa.** En el trial, empezar el día sin arrancar la HANA. El deployer
> falla con un error de conexión genérico y `bookshop-srv` se queda en
> *Crashed* con "connection refused" o "Cannot connect".

> **Trampa.** Elegir "solo IPs de BTP" al crear la instancia. Funciona para
> las apps desplegadas y falla para `cds watch --profile hybrid` desde tu
> portátil. Se puede cambiar después en *Manage Configuration*.

## Para recordar

- Instancia HANA Cloud = servidor con una única base de datos (subcuenta).
  Contenedor HDI = dos esquemas + usuarios técnicos de una app (space).
- `hana-cloud` lo pide el admin una vez para el servidor. `hana/hdi-shared` lo
  consume cada app al desplegar para tener su contenedor.
- El esquema `DBADMIN` es el personal del admin. Los contenedores están a su
  lado, no dentro.
- La app nunca usa `DBADMIN`: usa `_RT` de su contenedor. El deployer usa `_DT`.
- "Dos bases de datos" = dos contenedores en la misma instancia.
- El contenedor y sus tablas los crea el deploy a partir del modelo `.cds`. Tú
  no creas nada a mano, salvo el mapping.
- Mapping a la org/space, "allow all IPs" y arrancarla cada día en el trial.

## Ejercicio

1. En HANA Cloud Central, localiza el estado de `hana-trial`, el mapping y las
   conexiones permitidas. Párala y arráncala.
2. Abre el Database Explorer como `DBADMIN` y lista los esquemas. Anota cuáles
   son de sistema y cuáles de contenedores (tras el primer deploy).
3. Tras desplegar bookshop (capítulo 11), crea una key de `bookshop-db`,
   conéctate con ella en el Database Explorer y compara lo que ves con lo que
   veías como `DBADMIN`.
