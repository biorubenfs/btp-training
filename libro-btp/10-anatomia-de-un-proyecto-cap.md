# Parte III. CAP en BTP

# 10. Anatomía de un proyecto CAP

**Objetivo del capítulo.** Conocer las piezas de un proyecto CAP y saber qué
fichero se convierte en qué cosa del cockpit. A partir de aquí todo se hace
con el proyecto `bookshop` generado con cds-dk 10.2.1.

## 10.1 Qué es CAP en dos párrafos

El SAP Cloud Application Programming Model (CAP) es un framework para
construir servicios de negocio. Describes el **modelo de datos** y los
**servicios** en un lenguaje declarativo (CDS), y CAP genera por ti la base
de datos, una API OData (o REST) con filtros, paginación, expansión y
validaciones, y la integración con los servicios de BTP: HANA, XSUAA,
destinations, mensajería. La lógica de negocio se escribe en Node.js (o Java)
como *handlers* que se enganchan a eventos del servicio.

La promesa que lo hace encajar en BTP es: **el mismo código corre en local con
SQLite y login simulado, y en la nube con HANA y XSUAA**. Lo que cambia entre
los dos es la configuración, y la configuración viene del binding.

> **Analogía.** CAP es a Node.js lo que Spring Data REST + Spring Security a
> Java, con un lenguaje de modelado (CDS) que sustituye a las anotaciones JPA
> y a los DTOs. Si vienes de Django, piensa en modelos + Django REST Framework
> con el admin ya montado.

## 10.2 Crear el proyecto

```bash
mkdir -p ~/projects/btp-training-projects
cd ~/projects/btp-training-projects
cds init bookshop --add nodejs,typescript,typer,tiny-sample
mv bookshop bookshop-cap          # opcional: la carpeta puede llamarse como quieras
cd bookshop-cap
npm install
cds-tsx watch
```

`cds init bookshop` crea la carpeta `bookshop` y usa ese nombre como `name`
del `package.json` y, más adelante, como `ID` de la MTA. La carpeta se puede
renombrar después sin tocar nada más; en este curso vive en
`~/projects/btp-training-projects/bookshop-cap` y tiene su propio repositorio
en GitHub, con un commit por cada cambio. `cds init` todavía no instala nada:
solo escribe ficheros. Cada *facet* de `--add` añade los suyos:

| Facet         | Qué añade                                                                                                   | Para qué                                                                   |
|---------------|-------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| `nodejs`      | `@sap/cds` y `@cap-js/sqlite` en `package.json`, `"type": "module"`, `start: cds-serve`, `jsconfig.json`, `eslint.config.mjs`, `.vscode/` | El runtime. Sin él, cds-dk 10 crea un proyecto "sin lenguaje" |
| `typescript`  | `typescript`, `tsx`, `@cap-js/cds-types`, `@types/node` y `tsconfig.json`                                   | Handlers en `.ts`. `cds-types` son los tipos de la API de CAP; `tsx` ejecuta `.ts` sin compilar (`cds-tsx watch`) |
| `typer`       | `@cap-js/cds-typer`, la entrada `imports` de `package.json` y `@cds-models` en `.gitignore`                 | Genera tipos TypeScript **a partir del modelo CDS**: `Books` y `Authors` son tipos, no `any` |
| `tiny-sample` | `srv/cat-service.cds` y `db/data/CatalogService.Books.csv`                                                  | Un servicio con una entidad y cuatro libros, para arrancar con algo        |

Antes del primer commit conviene completar el `.gitignore`, porque el que
genera cds-dk 10.2.1 solo lleva `@cds-models`:

```bash
cat >> .gitignore <<'EOF'
node_modules/
gen/
mta_archives/
*.mtar
.cdsrc-private.json
default-env.json
EOF
```

| Entrada                   | Por qué no va a git                                            |
|---------------------------|----------------------------------------------------------------|
| `node_modules/`           | Se regenera con `npm install`                                  |
| `gen/`                    | Salida de `cds build`                                          |
| `mta_archives/`, `*.mtar` | Salida de `mbt build`                                          |
| `.cdsrc-private.json`     | Bindings del modo híbrido: contiene credenciales (capítulo 12) |
| `default-env.json`        | Copia local de `VCAP_SERVICES`: credenciales                   |

La diferencia entre `typescript` y `typer` es la que más confunde. El primero
tipa **lo que ya existe en CAP** (`cds.ApplicationService`, `this.after`,
`req.data`). El segundo tipa **lo que tú modelas**: lee los `.cds` y escribe
en `@cds-models/` un `index.js` y un `index.d.ts` por namespace con una clase
por entidad (`Book`/`Books`, `Author`/`Authors`). Se importan con
`#cds-models/...`, que es el alias que `typer` dejó en `imports`. Es código
generado, por eso va en `.gitignore`.

> **Trampa.** `cds-typer` solo genera los tipos con `cds watch` **si
> `@cds-models/` no existe todavía**; después de cambiar el modelo no los
> regenera, aunque el servidor reinicie. Hay que lanzarlo a mano, y por eso
> conviene un script: `"typer": "cds-typer '*'"` en `package.json`, que se
> ejecuta con `npm run typer` tras cada cambio en los `.cds`.

> **Trampa.** En cds-dk 10, `cds init` sin `--add nodejs` crea un proyecto
> "sin runtime" y te pide elegir después. El tutorial del curso, de versiones
> anteriores, no lo menciona.

> **Trampa.** Con `typescript` hay que arrancar con `cds-tsx watch`, no con
> `cds watch`. El binario `cds-tsx` es el mismo `cds` lanzado a través de
> `tsx`, que compila los `.ts` en memoria. Con `cds watch` a secas, Node
> intenta cargar los `.ts` con su propio *type stripping* y en cuanto hay un
> handler falla con `ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`.

### Dos arreglos al `tsconfig` antes de arrancar

La plantilla de TypeScript de cds-dk 10.2.1 tiene dos fallos, comprobados con
`@cap-js/cds-types` 0.18.0 y TypeScript 7.0.2. Van cada uno en su commit.

**1. El chequeo de tipos no encuentra `@sap/cds`.** El `tsconfig.json`
mapea `@sap/cds` al directorio `./node_modules/@cap-js/cds-types` en
`paths`. Con `moduleResolution: NodeNext` y `"type": "module"`, TypeScript
no resuelve un directorio, y `npx tsc --noEmit` (y con él `cds build`) falla
con `TS7016: Could not find a declaration file for module '@sap/cds'`.

La tentación es apuntar el `paths` al fichero,
`.../cds-types/dist/cds-types.d.ts`. **No lo hagas**: `tsx` también aplica
los `paths` en tiempo de ejecución, así que `import cds from '@sap/cds'`
cargaría el `.d.ts` en lugar del módulo real y el servidor muere con
`TypeError: Class extends value undefined is not a constructor or null` en
cuanto hay un handler. Comprobado.

El arreglo correcto no toca `paths`. El fichero de tipos empieza con
`declare module '@sap/cds' { ... }`, una declaración *ambiente*: basta con
que TypeScript lo lea para que el módulo quede tipado, sin redirigir ningún
import. Se quita la entrada `@sap/cds` de `paths` y se declara el paquete en
`types` (al poner `types` se pierde la inclusión automática de `@types/*`,
por eso hay que listar también `node`):

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "sourceMap": true,
    "allowJs": true,
    "paths": {
      "#cds-models/*": ["./@cds-models/*"]
    },
    "types": ["node", "@cap-js/cds-types"]
  },
  "exclude": ["app"]
}
```

**2. El build de producción no compila los handlers.** El `tsconfig.json`
lleva `noEmit: true`, correcto en local porque `tsx` ejecuta los `.ts` sin
compilar. Pero `cds build --production` (capítulo 11) necesita JavaScript en
`gen/srv`, y el plugin de build de cds-typer lo obtiene de un fichero aparte,
`tsconfig.cdsbuild.json`, que cds-dk no genera. Sin él, el build termina sin
error y `gen/srv` sale **sin ningún handler**: la app se despliega sin tu
lógica y nadie avisa.

```bash
cat > tsconfig.cdsbuild.json <<'EOF'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "noEmit": false,
    "sourceMap": false,
    "rootDir": ".",
    "outDir": "gen/srv"
  },
  "include": ["srv"],
  "files": []
}
EOF
```

`rootDir: "."` es obligatorio: sin él el compilador aplana la salida y el
handler acaba en `gen/srv/cat-service.js` en vez de en
`gen/srv/srv/cat-service.js`, que es donde CAP lo busca (junto al `csn.json`).
`"files": []` también: mientras `srv/` no tenga ningún `.ts` (como ahora, que
solo hay el `.cds`), `tsc` falla con `TS18003: No inputs were found` y tumba
el build. Un `files` vacío le dice que la lista puede estar vacía.

Comprobación de que ambos están bien: `npx tsc --noEmit` no imprime nada.

```
> bookshop@1.0.0 start:dev
> cds-tsx watch

cds serve all --with-mocks --in-memory?
( live reload enabled for browsers )

        ___________________________

[cds] - loaded model from 1 file(s):

  srv/cat-service.cds

[cds] - using bindings from: { registry: '~/.cds/services' }
[cds] - connect to db > sqlite { url: ':memory:' }
  > init from db/data/CatalogService.Books.csv
/> successfully deployed to in-memory database.

[cds] - using auth strategy { kind: 'mocked' }
[cds] - serving CatalogService {
  at: [ '/odata/v4/catalog' ],
  decl: 'srv/cat-service.cds:1'
}
[cds] - server listening on { url: 'http://localhost:4004' }
[cds] - server v10.2.2 launched in 838 ms
[cds] - [ terminate with ^C ]
```

| Línea                                   | Qué dice                                                                                              |
|-----------------------------------------|-------------------------------------------------------------------------------------------------------|
| `cds serve all --with-mocks --in-memory?` | `watch` es un alias de esto: sirve todos los servicios, simula los que falten y usa SQLite en memoria |
| `using bindings from: { registry: '~/.cds/services' }` | El registro de bindings del modo híbrido (capítulo 12). Aquí solo contiene el puerto 4004 |
| `connect to db > sqlite { url: ':memory:' }` | El perfil `development`: base de datos SQLite en memoria, se rellena del CSV en cada arranque    |
| `using auth strategy { kind: 'mocked' }` | Login simulado con usuarios de prueba (`alice`, `bob`). En BTP aquí pondrá `xsuaa`               |
| `serving CatalogService { at, decl }`  | El servicio y en qué fichero y línea está declarado                                                   |

Tras el primer arranque aparece la carpeta `@cds-models/` con un
subdirectorio por namespace (`CatalogService/`, `cds/` y `_/` para los tipos
comunes), cada uno con `index.js` e `index.d.ts`. Es `cds-typer` haciendo su
trabajo, solo esta primera vez (ver la trampa de 10.2).

En `http://localhost:4004/odata/v4/catalog/Books` ya hay una API OData con
cinco libros. Nada de esto ha tocado BTP todavía.

## 10.3 Estructura de carpetas

```
bookshop/
├── db/                      modelo de datos y datos iniciales
│   └── data/
│       └── CatalogService.Books.csv
├── srv/                     servicios (API) y handlers
│   └── cat-service.cds
├── app/                     UIs (Fiori), vacío por ahora
├── @cds-models/             tipos generados por cds-typer (NO va a git)
├── package.json             dependencias + configuración de CAP (cds.requires)
├── tsconfig.json            opciones de TypeScript (lo crea cds add typescript)
├── .cdsrc.json              configuración alternativa (opcional)
├── .cdsrc-private.json      bindings del modo híbrido (NO va a git)
├── mta.yaml                 descriptor de despliegue (lo crea cds add mta)
├── xs-security.json         scopes y roles (lo crea cds add xsuaa)
├── .deploy/app-router/      el approuter (lo crea cds add approuter)
└── gen/                     salida de cds build (NO va a git)
    ├── db/                  artefactos HDI para el deployer
    └── srv/                 la app Node lista para subir
```

Convención: `db/` para entidades, `srv/` para servicios que las exponen,
`app/` para interfaces. CAP carga todos los `.cds` de las tres carpetas.

## 10.4 El modelo: CDS

El `tiny-sample` mete entidad y servicio en el mismo fichero. En un proyecto
real se separan:

```cds
// db/schema.cds
namespace sap.capire.bookshop;
using { managed, cuid } from '@sap/cds/common';

entity Books : cuid, managed {
  title  : String(111) @mandatory;
  stock  : Integer default 0;
  price  : Decimal(9,2);
  author : Association to Authors;
}

entity Authors : cuid, managed {
  name  : String(111);
  books : Association to many Books on books.author = $self;
}
```

```cds
// srv/cat-service.cds
using { sap.capire.bookshop as my } from '../db/schema';

service CatalogService @(path: '/catalog') {
  @readonly entity Books   as projection on my.Books;
  @readonly entity Authors as projection on my.Authors;
}
```

| Construcción              | Qué hace                                                                    |
|---------------------------|-----------------------------------------------------------------------------|
| `namespace`               | Prefijo de todos los nombres. La tabla será `SAP_CAPIRE_BOOKSHOP_BOOKS`     |
| `entity`                  | Una tabla                                                                   |
| `: cuid, managed`         | Aspectos reutilizables: `ID: UUID` y `createdAt/By`, `modifiedAt/By`        |
| `Association to`          | Clave foránea con navegación (`author_ID` en la tabla, `author` en la API)  |
| `service` + `projection`  | Expone una vista de la entidad. La API es `/catalog/Books`                  |
| `@(path: '/catalog')`     | Fija la URL del servicio. Sin ella CAP la calcula: `/odata/v4/catalog`      |
| `@readonly`, `@mandatory` | Anotaciones: CAP las aplica como validaciones y permisos                    |

Los datos iniciales van en CSV con el nombre completo de la entidad:
`db/data/sap.capire.bookshop-Books.csv`. Se cargan en SQLite al arrancar y
en HANA al desplegar (vía `.hdbtabledata`). Las columnas son las de la tabla,
no las de la API: la asociación `author` se rellena por su clave foránea,
`author_ID`. El CSV del `tiny-sample` (`CatalogService.Books.csv`, con un
`author` de texto libre) deja de encajar con el modelo nuevo y `Books` sale
vacía sin ningún error; se sustituye por dos ficheros:

```csv
# db/data/sap.capire.bookshop-Authors.csv
ID,name
7a2b9b3e-0001-4000-8000-000000000001,Emily Brontë
7a2b9b3e-0001-4000-8000-000000000002,Charlotte Brontë
7a2b9b3e-0001-4000-8000-000000000003,Edgar Allan Poe
7a2b9b3e-0001-4000-8000-000000000004,Richard Carpenter
```

```csv
# db/data/sap.capire.bookshop-Books.csv
ID,title,stock,price,author_ID
7a2b9b3e-0002-4000-8000-000000000001,Wuthering Heights,12,11.11,7a2b9b3e-0001-4000-8000-000000000001
7a2b9b3e-0002-4000-8000-000000000002,Jane Eyre,11,12.34,7a2b9b3e-0001-4000-8000-000000000002
7a2b9b3e-0002-4000-8000-000000000003,The Raven,333,13.13,7a2b9b3e-0001-4000-8000-000000000003
7a2b9b3e-0002-4000-8000-000000000004,Eleonora,555,14,7a2b9b3e-0001-4000-8000-000000000003
7a2b9b3e-0002-4000-8000-000000000005,Catweazle,22,15,7a2b9b3e-0001-4000-8000-000000000004
```

Los `ID` son UUID porque `cuid` los define así; en SQLite colaría cualquier
texto, en HANA es un `NVARCHAR(36)`. Se usan valores fijos y legibles para
que las pruebas (`/catalog/Books/<ID>`) sean reproducibles.

> **Nota.** Al poner `@(path: '/catalog')` la API pasa de
> `/odata/v4/catalog/Books` a `/catalog/Books`. No se pierde nada: sigue
> siendo OData v4 y `$metadata`, `$filter`, `$select` o `$expand` funcionan
> igual. La ruta por defecto es `/<protocolo>/<versión>/<nombre del servicio
> sin "Service", en minúsculas>`, porque un servicio puede servirse por varios
> protocolos a la vez (`@protocol: ['odata', 'rest']` lo publicaría también en
> `/rest/catalog`). Con `@path` eliges tú la URL pública. Muchos proyectos
> reales no la anotan y se quedan con `/odata/v4/...`; es igual de válido.

## 10.5 La lógica: handlers

**El `.cds` declara. El `.ts` actúa.** Es la división central de CAP y
conviene tenerla clara antes de escribir una línea.

`srv/cat-service.cds` es una descripción, no código que se ejecute. Dice
"existe un servicio `CatalogService`, en `/catalog`, con dos entidades de
solo lectura que son vistas de las tablas de `db/`". A partir de ahí CAP
genera él solo todo lo genérico: las consultas SQL, la API OData con
`$filter` y `$expand`, el `$metadata`, las validaciones de `@mandatory`, el
rechazo de escrituras por `@readonly`. Si no existiera ningún handler, la
API funcionaría igual.

`srv/cat-service.ts` es lo que no se puede describir: la lógica de negocio.
CAP lo encuentra porque **tiene el mismo nombre que el `.cds`**, y lo que
hace es engancharse a los eventos del servicio. No implementa la lectura, la
lectura la hace CAP; solo la decora.

> **Analogía.** El `.cds` equivale a las entidades JPA más los controladores
> REST que Spring Data REST genera por ti. El `.ts` son los pocos `@Service`
> donde de verdad escribías algo.

```ts
// srv/cat-service.ts  (mismo nombre que el .cds, CAP lo asocia solo)
import cds from '@sap/cds'
import { Books } from '#cds-models/CatalogService'

export default class CatalogService extends cds.ApplicationService {
  init() {
    // después de leer: enriquecer el resultado
    this.after('READ', Books, (books) => {
      for (const b of books ?? []) {
        if (b.stock && b.stock > 100) b.title += ' (en oferta)'
      }
    })
    return super.init()
  }
}
```

Al guardar, `cds-tsx watch` reinicia y junto al `decl` del servicio aparece
el handler:

```
[cds] - serving CatalogService {
  at: [ '/catalog' ],
  decl: 'srv/cat-service.cds:3',
  impl: 'srv/cat-service.ts'
}
```

Y la API ya lo refleja: `curl 'http://localhost:4004/catalog/Books?$select=title,stock'`
devuelve `The Raven (en oferta)` y `Eleonora (en oferta)`, los dos con stock
mayor de 100, y los demás sin tocar.

| Fase      | Cuándo                                    | Para qué                                                        |
|-----------|-------------------------------------------|-----------------------------------------------------------------|
| `before`  | Antes de que CAP ejecute la operación     | Validar, rellenar campos, rechazar (`req.reject(400, '...')`)   |
| `on`      | Sustituye la operación por defecto        | Lógica propia, ir a un sistema externo en vez de a la BD (capítulo 9, `NORTHWIND`) |
| `after`   | Después, con el resultado en la mano      | Enriquecer, filtrar                                             |

Qué aporta TypeScript aquí:

- `import { Books } from '#cds-models/CatalogService'` trae la clase que
  `cds-typer` generó a partir del `.cds`. Dentro del `after`, `b.stock` y
  `b.title` tienen tipo, y `npm run typecheck` falla si escribes `b.precio`.
  En JavaScript ese error se vería en producción.
- El parámetro `books` puede ser `undefined` en el tipado (`strict`), por eso
  el `books ?? []`.
- `init()` no necesita `async`: devuelve lo que devuelve `super.init()`.

Qué pasa con cada fichero en el despliegue (capítulo 11):

| Fichero              | En `gen/srv`                       | Cómo llega                                             |
|----------------------|------------------------------------|--------------------------------------------------------|
| `srv/cat-service.cds`| `srv/csn.json`                     | Compilado por `cds build` junto con el resto del modelo |
| `srv/cat-service.ts` | `srv/cat-service.js`               | Compilado por `tsc` con `tsconfig.cdsbuild.json`        |

Por eso el arreglo 2 de la sección 10.2 importa tanto: sin él, en BTP
estaría el `.cds` (y por tanto la API) pero no el `.ts`, y nadie avisaría.

## 10.6 La configuración: `cds.requires`

Es el puente entre el código y BTP. Vive en `package.json` bajo la clave
`cds`, y se puede dividir por **perfil**:

```json
"cds": {
  "requires": {
    "db": "sqlite",
    "auth": "mocked",
    "[production]": {
      "db": "hana",
      "auth": "xsuaa"
    },
    "[hybrid]": {
      "db": "hana",
      "auth": "xsuaa"
    }
  }
}
```

| Perfil         | Cuándo se activa                                 | db                | auth               |
|----------------|--------------------------------------------------|-------------------|--------------------|
| `development`  | Por defecto (`cds watch`)                        | SQLite en memoria | `mocked` (usuarios de prueba) |
| `hybrid`       | `cds watch --profile hybrid` (capítulo 12)       | HANA real vía `cds bind` | XSUAA real vía `cds bind` |
| `production`   | `NODE_ENV=production`, que Cloud Foundry pone solo | HANA vía `VCAP_SERVICES` | XSUAA vía `VCAP_SERVICES` |

Lo que generó `cds add hana,xsuaa` en nuestro `package.json`:

```json
"dependencies": {
  "@cap-js/hana": "^3",
  "@sap/cds": "^10",
  "@sap/xssec": "^4"
},
"devDependencies": {
  "@cap-js/sqlite": "^3",
  "@sap/cds-dk": "^10"
},
"cds": {
  "requires": {
    "[production]": { "auth": "xsuaa" }
  }
}
```

Fíjate en que **no** hay `db: hana` explícito. En CAP 9 y 10 basta con tener
`@cap-js/hana` en dependencias: el plugin se registra solo como base de datos
en producción. Para verlo resuelto:

```bash
cds env requires.db                       # perfil development
cds env requires.db --profile production  # qué usará en la nube
```

```
{
  impl: '@cap-js/sqlite',
  credentials: { url: ':memory:' },
  kind: 'sqlite'
}

{
  impl: '@cap-js/hana',
  kind: 'hana',
  ...
}
```

> **Idea clave.** `cds env` es tu mejor amigo cuando algo "no coge" la
> configuración. Muestra la configuración efectiva tras mezclar valores por
> defecto, `package.json`, `.cdsrc.json`, perfiles y variables de entorno.

### Utilidad: SQLite en fichero, con datos que sobreviven a los reinicios

Con la configuración por defecto, la base de datos local vive **dentro del
proceso de Node**, en memoria. Cada arranque crea una base vacía y la rellena
con los CSV. Eso tiene tres consecuencias que sorprenden la primera vez:

| Lo que ves                                              | Por qué                                                                 |
|---------------------------------------------------------|-------------------------------------------------------------------------|
| Un libro creado por POST no aparece en el CSV           | El CSV es la semilla: se lee al arrancar y nunca se escribe             |
| Ese libro desaparece al reiniciar (o al guardar un fichero con `cds watch`) | La base en memoria se tira y se recrea desde los CSV |
| Todos los libros tienen `createdAt` de hace un momento  | El CSV no trae esas columnas; `managed` las rellena al insertar cada arranque |

Y una cuarta: no hay fichero ni puerto, así que **ningún cliente externo**
(DBeaver, SQLite Viewer) puede abrirla.

La solución es apuntar el perfil `development` a un fichero:

```json
"cds": {
  "requires": {
    "[production]": { "auth": "xsuaa" },
    "[development]": {
      "db": { "kind": "sqlite", "credentials": { "url": "db.sqlite" } }
    }
  }
}
```

```bash
npx cds deploy --to sqlite:db.sqlite   # crea las tablas y carga los CSV
echo 'db.sqlite*' >> .gitignore        # datos locales, fuera del repo
cds env requires.db                    # debe decir url: 'db.sqlite'
```

> **Trampa.** `cds deploy --to sqlite:db.sqlite` crea el fichero pero en
> cds-dk 10.2.1 **no toca `package.json`**. Sin el bloque `[development]`,
> el servidor sigue usando la memoria y el fichero queda huérfano.

Con el fichero, el arranque ya no recarga los CSV (desaparece la línea
`init from db/data/...` del log): lo creado por POST sigue ahí tras parar y
arrancar, también con `cds-tsx watch`. Comprobado en bookshop. En DBeaver
basta una conexión de tipo SQLite con la ruta al fichero, sin usuario. Verás
la tabla real `sap_capire_bookshop_Books` y una vista por servicio que la
expone (`CatalogService_Books`, `AdminService_Books`), igual que en el
contenedor HDI.

| Quiero…                                   | Haz                                                    |
|-------------------------------------------|--------------------------------------------------------|
| Volver a los datos de los CSV             | `npx cds deploy --to sqlite:db.sqlite` (borra lo tuyo) |
| Aplicar un cambio del modelo (`.cds`)     | Lo mismo: el fichero no se actualiza solo              |
| Volver a la memoria                       | Quita el bloque `[development]`                        |

> **Trampa.** Añadir un campo al modelo y no redesplegar el fichero. El
> servidor arranca sin quejarse, pero la primera lectura falla con
> `no such column: ... isbn`: la tabla del fichero es la vieja. Repite
> `cds deploy`, sabiendo que recarga los CSV y pierdes lo creado a mano.

> **Para un dev CAP.** En HANA pasa algo parecido: el deployer carga los CSV
> **en cada despliegue**, no al arrancar `srv`. Lo creado por POST persiste
> entre reinicios, pero un redespliegue puede pisar las filas de las tablas
> que tienen CSV.

## 10.7 De fichero a cockpit

La tabla que resume el capítulo y anticipa el siguiente:

| Fichero del proyecto                 | Lo que produce al desplegar                      | Dónde se ve en el cockpit                                      |
|--------------------------------------|--------------------------------------------------|----------------------------------------------------------------|
| `db/*.cds`                           | Tablas en el contenedor HDI                      | Instancias › `bookshop-db` › key › Database Explorer           |
| `srv/*.cds` + `srv/*.ts`             | La app `bookshop-srv`                            | Cloud Foundry › Espacios › dev › Aplicaciones                  |
| `xs-security.json`                   | Scopes y roles en la instancia XSUAA             | Seguridad › Roles                                              |
| `mta.yaml` › `modules`               | Una app de CF por módulo                         | Aplicaciones                                                   |
| `mta.yaml` › `resources`             | Una instancia de servicio por recurso            | Instancias y suscripciones; `cf services`                      |
| `mta.yaml` › `requires`              | Bindings                                         | Aplicación › Enlaces de servicio                               |
| `.deploy/app-router/xs-app.json`     | Las rutas que el approuter reenvía a `srv`       | Aplicaciones › `bookshop` › Rutas                              |
| `package.json` › `cds.requires`      | Qué servicio usa CAP para db y auth              | Variables de entorno › `VCAP_SERVICES` (lo que CAP lee)        |

## 10.8 Trampas

> **Trampa.** `cds init` sin `--add nodejs` en cds-dk 10. Proyecto sin runtime.

> **Trampa.** Editar `.cds` y no ver el cambio: `cds watch` reinicia solo,
> pero si cambiaste `package.json` hay que pararlo y arrancarlo a mano.

> **Trampa.** Subir `gen/`, `.cdsrc-private.json` o `mta_archives/` a git. El
> `.gitignore` que escribe cds-dk 10.2.1 solo contiene `@cds-models` (lo pone
> la facet `typer`); ni siquiera excluye `node_modules`. Hay que completarlo a
> mano antes del primer commit (ver 10.2).

> **Trampa.** Nombrar el CSV sin el namespace completo. Debe ser
> `sap.capire.bookshop-Books.csv` (namespace, guion, entidad), si no CAP lo
> ignora en silencio.

## Para recordar

- CAP: modelo en CDS → base de datos + API OData + integración con BTP. La
  lógica va en handlers `before/on/after`.
- Mismo código en local (SQLite, mocked) y en nube (HANA, XSUAA). Cambia la
  configuración, por perfiles en `cds.requires`.
- `cds env` muestra la configuración efectiva. Úsalo antes de culpar a BTP.
- Cada fichero del proyecto tiene una pantalla del cockpit donde se
  materializa (tabla 10.7).

## Ejercicio

1. Crea bookshop con `cds init bookshop --add nodejs,tiny-sample`, arráncalo
   y prueba `/odata/v4/catalog/Books?$filter=author eq 'Edgar Allan Poe'`.
2. Separa el modelo en `db/schema.cds` y `srv/cat-service.cds` como en 10.4,
   con `Authors`. Renombra el CSV y añade uno para autores.
3. Añade el handler `before CREATE` de 10.5 y pruébalo con `curl -X POST`.
4. Ejecuta `cds env requires --profile production` y explica cada clave.
