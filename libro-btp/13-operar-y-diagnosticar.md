# 13. Operar y diagnosticar

**Objetivo del capítulo.** Tener un método para cuando algo falla: qué mirar,
en qué orden y con qué comando. Y los hábitos que distinguen a quien "usa BTP"
de quien lo entiende.

## 13.1 El método

Cuando algo no funciona, el orden de preguntas es siempre el mismo:

```
  1. ¿Está la app viva?            cf apps · cf app X
        │ no → 2                    │ sí → 3
  2. ¿Por qué murió?               cf logs X --recent   (últimas líneas APP/… antes de Exit)
        │ falta binding / no DB     │ excepción al arrancar  │ memoria
        ▼                           ▼                        ▼
     cf env X                    el código                 cf app X (memory) · cf scale -m
     cf services (¿existe?)      cds env --profile production
  3. ¿Responde?                    curl a la route · cf logs X (en vivo, mirar [RTR])
        │ 401 → approuter / token  │ 403 → role collection / token viejo  │ 500 → logs APP
  4. ¿Es la plataforma?            HANA parada · entitlement · cuota · destination · Cloud Connector
```

## 13.2 Fallos típicos y su diagnóstico

| Síntoma                                       | Causa habitual                                                         | Dónde se ve                                                    |
|-----------------------------------------------|------------------------------------------------------------------------|----------------------------------------------------------------|
| El deploy falla creando el servicio `hana`    | Entitlement `hdi-shared` sin asignar, HANA parada, o sin instance mapping | Subcuenta › Derechos; HANA Cloud Central; error del broker  |
| `db-deployer` termina con error               | Error en artefactos HDI o en CSV (clave duplicada, tipo incorrecto). **Es tu modelo, no la plataforma** | `cf logs bookshop-db-deployer --recent`; `cf dmol -i <op>` |
| `srv` pasa a *Crashed* en bucle               | Excepción al arrancar, falta un binding, memoria insuficiente          | `cf logs srv --recent`; `cf app srv` muestra la memoria        |
| Staging falla: *no match found for node*      | `engines.node` pide una versión que el buildpack no tiene              | Logs `[STG]`; `package.json`                                   |
| 401 al abrir la app                           | Approuter sin XSUAA ligada, `xs-app.json` mal, o llamas a `srv` directo | Enlaces de servicio del approuter                             |
| 403 en un endpoint                            | Role collection no asignada o token viejo                              | Seguridad › Usuarios; cerrar sesión                            |
| Error llamando a un sistema externo           | Destination mal configurada o Cloud Connector desconectado             | Conectividad › Destinos; Cloud Connectors                      |
| *memory quota exceeded* al desplegar          | Cuota de la org agotada                                                | `cf org-quota`; bajar `memory` en `mta.yaml`                   |
| *A newer version is already deployed*         | `version` del `mta.yaml` no sube                                       | `cf mtas`; `--version-rule ALL`                                |
| La app funciona pero no sale en el launchpad  | Work Zone no configurado o el usuario no tiene el rol del site         | Suscripción a Build Work Zone                                  |
| Todo iba bien ayer y hoy nada conecta (trial) | **La HANA se paró por la noche**                                       | HANA Cloud Central › Start                                     |

## 13.3 Leer los logs con criterio

```bash
cf logs bookshop-srv --recent | grep -v RTR        # quitar el ruido del router
cf logs bookshop-srv --recent | grep -E "ERR|Error|rror"
cf logs bookshop-srv | grep RTR                     # solo peticiones HTTP, en vivo
```

Una línea del router:

```
[RTR/0] OUT 7b6c…-dev-bookshop-srv.cfapps.us10-001.hana.ondemand.com - [2026-11-14T17:10:02.1Z]
  "GET /odata/v4/catalog/Books HTTP/1.1" 200 0 1843 "-" "curl/8.5" "10.0.1.2:4521" "10.0.2.9:61002"
  x_forwarded_for:"83.x.x.x" ... response_time:0.041 ... app_id:"a1b2…" app_index:"0"
```

Te da código HTTP, bytes, tiempo de respuesta y qué instancia (`app_index`)
atendió. Para un 500 intermitente, correlaciona `app_index` con los logs
`[APP/PROC/WEB/<index>]`.

Logs de un deploy que falló:

```bash
cf mta-ops                         # lista operaciones con su ID y estado
cf dmol -i <operation-id>          # descarga todos los logs de esa operación
```

Logs de CAP más detallados, sin redesplegar:

```bash
cf set-env bookshop-srv DEBUG "cds,hana"     # o DEBUG=all
cf restart bookshop-srv
cf logs bookshop-srv
cf unset-env bookshop-srv DEBUG && cf restart bookshop-srv
```

> **Trampa.** `cf logs --recent` tiene memoria corta. Para retención hace
> falta ligar Application Logging (`application-logs` / `lite`) o SAP Cloud
> Logging, que dan un Kibana/OpenSearch con histórico y búsqueda.

## 13.4 Inspeccionar la configuración real

```bash
cf env bookshop-srv                          # lo que recibe el proceso
cf ssh bookshop-srv -c "env | grep -i cds"   # variables dentro del contenedor
cf ssh bookshop-srv -c "cat app/package.json"
cf ssh bookshop-srv -c "ls app/srv app/db"   # ¿llegó el modelo?
```

Y desde el proyecto, qué cree CAP que va a usar en producción:

```bash
cds env requires --profile production
```

Si `cds env` dice `kind: sqlite` en producción, el deploy fallará por falta
de base de datos aunque el binding esté. Suele ser una dependencia que no
está en `dependencies` sino en `devDependencies`.

## 13.5 Tareas de operación corrientes

| Tarea                                 | Cockpit                                                      | CLI                                                           |
|---------------------------------------|--------------------------------------------------------------|---------------------------------------------------------------|
| Reiniciar una app                     | Aplicaciones › app › Reiniciar                               | `cf restart bookshop-srv`                                     |
| Escalar                               | Aplicaciones › app › Instancias / Memoria                    | `cf scale bookshop-srv -i 2 -m 512M`                          |
| Parar todo para no gastar             | Aplicaciones › seleccionar › Parar                           | `cf stop bookshop; cf stop bookshop-srv`                      |
| Ver quién tocó qué                    | Aplicaciones › app › Eventos                                 | `cf events bookshop-srv`                                      |
| Rotar una credencial                  | Instancia › Claves › borrar y crear                          | `cf delete-service-key … ; cf create-service-key …` + `restage` de apps que la usen |
| Ver versiones desplegadas             | —                                                            | `cf mtas`; `cf revisions bookshop-srv`                        |
| Volver a la versión anterior de una app | —                                                          | `cf rollback bookshop-srv --version N`                        |
| Ejecutar un script puntual en la app  | —                                                            | `cf run-task bookshop-srv --command "node scripts/fix.js"`    |

> **Pendiente de validar.** `cf revisions` y `cf rollback` dependen de que
> las *revisions* estén habilitadas en la plataforma. Se comprobará en el trial.

## 13.6 Costes

| Qué cuesta                               | Cómo                                                   | Qué hacer en dev                                            |
|------------------------------------------|--------------------------------------------------------|-------------------------------------------------------------|
| SAP HANA Cloud                           | Por hora encendida, lo más caro de un proyecto CAP     | Apagarla por la noche. En el trial lo hace SAP por ti       |
| Apps de Cloud Foundry                    | Por memoria **asignada**, no usada                      | `memory: 256M` si cabe; una instancia en dev                |
| Instancias de servicio                   | La mayoría de planes `lite`/`hdi-shared` son gratis o casi | Borrar las que no se usan                                |
| Suscripciones                            | Algunas por usuario                                    | Pedir solo las necesarias                                   |

> **Cockpit:** Subcuenta › Análisis de uso (*Usage Analytics*) y, a nivel
> cuenta global, el consumo por servicio. Antes de crear algo en la subcuenta
> de la empresa, mira su plan en el Discovery Center y pregunta.

## 13.7 Hábitos

- **Prefijo de proyecto en todo**: `bookshop-db`, `bookshop-auth`,
  `bookshop-srv`. El cockpit lista todo junto; sin prefijos es un caos.
- **Antes de tocar algo que no es tuyo**, mira *Eventos* o los audit logs.
  Sabrás si alguien más está trabajando en ello.
- **Nunca copies un `clientsecret`** de `VCAP_SERVICES` a un chat o ticket.
  Usa service keys con nombre y bórralas al terminar.
- **Pide roles concretos**: "Space Developer en el space `dev` de
  `ventas-dev`, y Subaccount Viewer en `ventas-dev`".
- **Arranca el día con `cf target`** para saber dónde estás, y en el trial con
  la HANA.
- **Un cambio, un deploy.** Si cambias modelo, seguridad y approuter a la vez
  y falla, no sabrás qué fue.
- **Lee el error completo.** Los errores del broker y del deploy service
  suelen decir exactamente qué falta; el reflejo de "reintentar" los oculta.

## Para recordar

- Método: ¿viva? → ¿por qué murió? → ¿responde? → ¿es la plataforma?
- Los cinco comandos: `cf apps`, `cf app X`, `cf logs X --recent`, `cf env X`,
  `cf services`. Para deploys: `cf mta-ops` y `cf dmol`.
- 401 approuter/token, 403 rol/token viejo, 500 logs de la app, *Crashed*
  binding/memoria/código.
- En el trial, lo primero que se comprueba es si la HANA está arrancada.
- HANA se paga por hora, apps por memoria asignada.

## Ejercicio

1. Rompe bookshop a conciencia: mete un CSV con una clave duplicada y
   despliega. Encuentra el error usando **solo** el cockpit. Repite usando
   **solo** la CLI. Anota qué pantallas y comandos usaste.
2. Baja `memory` de `bookshop-srv` a `128M` en `mta.yaml`, despliega y observa
   qué pasa en `cf app` y `cf logs`. Restaura.
3. Activa `DEBUG=cds` con `cf set-env`, haz tres peticiones y lee los logs.
   Desactívalo.
