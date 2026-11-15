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
| 2026-11-14 | —         | Proyecto `bookshop` generado con cds-dk 10.2.1 para capturar los ficheros reales de los capítulos 10 y 11. Primera versión del libro |

## Pendiente

Por orden del curso:

1. Confirmar la instancia HANA *Running*, mapping y conexiones (capítulo 7).
2. Desplegar bookshop en `dev` (capítulo 11) y sustituir las salidas marcadas
   *Pendiente de validar* por las reales.
3. Scope `Admin`, role collection y prueba de 403 (capítulo 8).
4. Destination `NORTHWIND` y `cds import` (capítulo 9).
5. Modo híbrido y tests contra HANA (capítulo 12).
6. Romper y diagnosticar (capítulo 13).
7. Space `prod`, `.mtaext`, `btp` CLI (capítulo 14).

## Estado del entorno

| Elemento                | Estado a 2026-11-14                                        |
|-------------------------|------------------------------------------------------------|
| Subcuenta               | `trial`, `us10`, subdominio `7b6c2113trial`                |
| Org / space             | `7b6c2113trial` / `dev`                                    |
| Apps desplegadas        | Ninguna                                                    |
| Instancias en el space  | Ninguna                                                    |
| HANA Cloud              | `hana-trial`, creación lanzada el 13; comprobar estado     |
| Suscripciones           | SAP HANA Cloud (`tools`)                                   |
| Role collections propias| *SAP HANA Cloud Administrator* asignada                    |
| `btp` CLI               | No instalada                                               |
