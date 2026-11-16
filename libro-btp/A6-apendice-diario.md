# F. Diario del trial

Registro de lo que se ha hecho de verdad en la cuenta trial mientras se
escribía el libro. Sirve para saber qué partes están validadas y para
reproducir el camino.

| Fecha      | Capítulos | Qué se hizo                                                                                                   |
|------------|-----------|---------------------------------------------------------------------------------------------------------------|
| 2026-11-12 | 1–3       | Trial creada en AWS `us10`. Herramientas: `@sap/cds-dk` 10.2.1, `mbt` 1.2.51, `cf` 8.19.0, plugin `multiapps` 3.12.0 (ver `INSTALADO.md`) |
| 2026-11-12 | 2, 4      | `cf login` contra `api.cf.us10-001`; org `7b6c2113trial`, space `dev`, vacío. Entitlements revisados (`hana-cloud`, `hana/hdi-shared`, `xsuaa/application`). Space `sandbox` creado y borrado |
| 2026-11-13 | 5         | El booster de CAP ya no existe en el trial. Ejecutado "SAP HANA Cloud administration tools" → suscripción a HANA Cloud Central + role collection *SAP HANA Cloud Administrator* |
| 2026-11-13 | 5, 6      | Instancia `dest-test` (`destination`/`lite`) + key `key1` creadas desde el cockpit, JSON inspeccionado (capítulo 6), borradas en orden. Cockpit en castellano |
| 2026-11-13 | 7         | Creación de la instancia SAP HANA Cloud `hana-trial` lanzada desde HANA Cloud Central, con "Allow all IPs" y mapping a la org |
| 2026-11-14 | —         | Primera versión del libro. El proyecto `bookshop` de los capítulos 10 y 11 lo generó el asistente en un directorio temporal con cds-dk 10.2.1 solo para capturar los ficheros reales; no se conservó ni se desplegó |
| 2026-11-15 | 6, 9      | Instancia HANA arrancada. `dest-dev` + `key1` creadas dos veces desde el cockpit (la primera borrada en orden). Token OAuth2 pedido con `curl`, API de destinations llamada antes (`[]`) y después de crear `NORTHWIND` en el cockpit, JWT decodificado. Autocompletado de `cf` instalado (ver `INSTALADO.md`) |
| 2026-11-15 | 10        | `bookshop` generado en `~/projects/btp-training-projects/bookshop-cap` con `--add nodejs,typescript,typer,tiny-sample`, repo propio en GitHub (`biorubenfs/bookshop-cap`). `.gitignore` completado a mano. Dos arreglos al `tsconfig` (`@sap/cds` en `types` en vez de `paths`, y `tsconfig.cdsbuild.json` con `files: []`), un commit cada uno. Modelo separado en `db/schema.cds` (Books, Authors) con CSV por tabla; scripts `typer`, `typecheck` y `build`. `npx tsc --noEmit` pasa |
| 2026-11-16 | 10        | Handler `srv/cat-service.ts` (`after READ` de Books, añade "(en oferta)" si `stock > 100`) probado con `cds-tsx watch` contra `/catalog/Books` y commiteado. Capítulo 10 cerrado |
| 2026-11-16 | 11        | `cds add hana,xsuaa,approuter,mta` en `bookshop-cap`. `mta.yaml` idéntico al del libro. Comprobado que `cds add` no instala las dependencias nuevas (`@cap-js/hana` ausente de `node_modules`) y que `default-env.json` del `.gitignore` oculta el de `.deploy/app-router`. Sección 11.2 nueva con el paso a paso |
| 2026-11-16 | 11        | `mbt build` correcto: `gen/srv/srv/cat-service.js` compilado, `gen/db` con tablas, vistas y outbox, `.mtar` de 13 MB. `engines ^24` lo escribe `cds build` en los `package.json` de `gen/`, no está en el del proyecto. Sección 11.5 con la salida real |
| 2026-11-16 | 11        | Primer `cf deploy` de bookshop en `dev`, sin errores. Instancias `bookshop-db` y `bookshop-auth` creadas por el deploy service; tarea del deployer `SUCCEEDED` (contenedor `FE77BBFE…`); `srv` con Node 24.22.1, HANA y auth `xsuaa`; `srv` sin token 401; approuter responde 200 con redirección por script a XSUAA. Visto el `warn` del outbox por arrancar `srv` antes que el deployer. Secciones 11.6 y 11.7 con las salidas reales |
| 2026-11-16 | 7, 11     | Approuter probado en el navegador: `/` da `Cannot GET /`, `/catalog/Books` tras el login muestra los libros con "(en oferta)". Contenedor `bookshop-db` abierto en Database Explorer como *HDI Container* con la key `explorer-key` pegada por *Apply From JSON String* (el login en CF del diálogo no cuajó). Punto 3 del ejercicio del capítulo 7 hecho |
| 2026-11-16 | 7         | DBeaver conectado al contenedor `bookshop-db` con la misma key (`ngdbc` 2.30.12, puerto 443, SSL). Primer intento falló por cerrar la ventana de descarga del driver |
| 2026-11-15 | 7         | Mapping (org + space `dev`) y *Allow all IPs* confirmados. Contenedor de prueba `test-hdi` (`hana`/`hdi-shared`) creado por CLI, borrado y recreado desde el cockpit, con key. Esquemas reales consultados en `SYS.SCHEMAS` como `DBADMIN`: cinco por contenedor (datos, `#DI`, `#OO`, `_DT`, `_RT`), `HAS_PRIVILEGES=FALSE`. Capítulo 7.5 y 7.8 corregidos con ello |

## Pendiente

Por orden del curso:

1. ~~Confirmar la instancia HANA, mapping, conexiones y entrar al contenedor con su key (capítulo 7).~~ Hecho el 15 y el 16.
2. ~~Desplegar bookshop en `dev` (capítulo 11) y sustituir las salidas por las reales.~~ Hecho el 16. Quedan 11.8 (quitar la route pública de `srv`) y 11.9 (redesplegar y deshacer).
3. Scope `Admin`, role collection y prueba de 403 (capítulo 8).
4. `cds import` contra `NORTHWIND` (capítulo 9). La destination ya está creada.
5. Modo híbrido y tests contra HANA (capítulo 12).
6. Romper y diagnosticar (capítulo 13).
7. Space `prod`, `.mtaext`, `btp` CLI (capítulo 14). Antes, ampliar el mapping de HANA a `prod`.

## Estado del entorno

| Elemento                | Estado a 2026-11-15                                        |
|-------------------------|------------------------------------------------------------|
| Subcuenta               | `trial`, `us10`, subdominio `7b6c2113trial`                |
| Org / space             | `7b6c2113trial` / `dev`                                    |
| Apps desplegadas        | MTA `bookshop` 1.0.0 en `dev`: `bookshop-srv`, `bookshop` (approuter), `bookshop-db-deployer` (stopped). Repo `biorubenfs/bookshop-cap` |
| Instancias en el space  | `dest-dev` (`destination`/`lite`) con key `key1`; `test-hdi` (`hana`/`hdi-shared`) con key `key1`, por borrar; `bookshop-db` (`hana`/`hdi-shared`, con key `explorer-key`) y `bookshop-auth` (`xsuaa`/`application`), creadas por la MTA |
| HANA Cloud              | `hana-trial`, arrancada el 15. Mapping confirmado **solo al space `dev`** (org + space): para el space `prod` del capítulo 14 habrá que añadir otro mapping o dejar el Environment Group vacío |
| Suscripciones           | SAP HANA Cloud (`tools`)                                   |
| Destinations            | `NORTHWIND` (HTTP, Internet, NoAuthentication)             |
| Role collections propias| *SAP HANA Cloud Administrator* asignada                    |
| `btp` CLI               | No instalada                                               |
