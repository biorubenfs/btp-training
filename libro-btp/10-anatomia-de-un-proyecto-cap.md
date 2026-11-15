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
cds init bookshop --add nodejs,tiny-sample
cd bookshop
npm install
cds watch
```

> **Trampa.** En cds-dk 10, `cds init` sin `--add nodejs` crea un proyecto
> "sin runtime" y te pide elegir después. El tutorial del curso, de versiones
> anteriores, no lo menciona.

```
cds serve all --with-mocks --in-memory?
live reload enabled for browsers

        ___________________________

[cds] - loaded model from 1 file(s):

  srv/cat-service.cds

[cds] - connect to db > sqlite { url: ':memory:' }
  > init from db/data/CatalogService.Books.csv
/> successfully deployed to in-memory database.

[cds] - serving CatalogService { path: '/odata/v4/catalog' }

[cds] - server listening on { url: 'http://localhost:4004' }
[cds] - launched at 11/14/2026, 1:30:12 PM, version: 10.2.2, in: 412.573ms
[cds] - [ terminate with ^C ]
```

En `http://localhost:4004/odata/v4/catalog/Books` ya hay una API OData con
cuatro libros. Nada de esto ha tocado BTP todavía.

## 10.3 Estructura de carpetas

```
bookshop/
├── db/                      modelo de datos y datos iniciales
│   └── data/
│       └── CatalogService.Books.csv
├── srv/                     servicios (API) y handlers
│   └── cat-service.cds
├── app/                     UIs (Fiori), vacío por ahora
├── package.json             dependencias + configuración de CAP (cds.requires)
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
| `@readonly`, `@mandatory` | Anotaciones: CAP las aplica como validaciones y permisos                    |

Los datos iniciales van en CSV con el nombre completo de la entidad:
`db/data/sap.capire.bookshop-Books.csv`. Se cargan en SQLite al arrancar y
en HANA al desplegar (vía `.hdbtabledata`).

## 10.5 La lógica: handlers

```js
// srv/cat-service.js  (mismo nombre que el .cds, CAP lo asocia solo)
import cds from '@sap/cds'

export default class CatalogService extends cds.ApplicationService {
  async init() {
    const { Books } = this.entities

    // antes de crear: validar
    this.before('CREATE', Books, req => {
      if (req.data.stock < 0) req.reject(400, 'El stock no puede ser negativo')
    })

    // después de leer: enriquecer
    this.after('READ', Books, books => {
      for (const b of books) if (b.stock > 100) b.title += ' (en oferta)'
    })

    return super.init()
  }
}
```

| Fase      | Cuándo                                    | Para qué                                   |
|-----------|-------------------------------------------|--------------------------------------------|
| `before`  | Antes de que CAP ejecute la operación     | Validar, rellenar campos, rechazar          |
| `on`      | Sustituye la operación por defecto        | Lógica propia, llamar a un sistema externo  |
| `after`   | Después, con el resultado                 | Enriquecer, filtrar                         |

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

## 10.7 De fichero a cockpit

La tabla que resume el capítulo y anticipa el siguiente:

| Fichero del proyecto                 | Lo que produce al desplegar                      | Dónde se ve en el cockpit                                      |
|--------------------------------------|--------------------------------------------------|----------------------------------------------------------------|
| `db/*.cds`                           | Tablas en el contenedor HDI                      | Instancias › `bookshop-db` › key › Database Explorer           |
| `srv/*.cds` + `srv/*.js`             | La app `bookshop-srv`                            | Cloud Foundry › Espacios › dev › Aplicaciones                  |
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
> `.gitignore` que crea `cds init` ya los excluye; no lo borres.

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
