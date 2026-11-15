---
title: "SAP BTP y CAP desde cero"
subtitle: "Cuaderno de referencia para un desarrollador backend"
author: "Rubén, con ayuda de Claude"
date: "2026-11-14"
---

# Prólogo

Este libro nace de un problema concreto: casi no hay textos que expliquen SAP
Business Technology Platform (BTP) y el SAP Cloud Application Programming Model
(CAP) de forma introductoria y, a la vez, con la profundidad que necesita
alguien que va a trabajar con ellos a diario. La documentación oficial es
extensa pero fragmentada, los tutoriales dan los pasos sin el porqué, y los
cursos de pago presuponen años en el ecosistema SAP.

Está escrito desde el punto de vista de un desarrollador backend que conoce
bases de datos relacionales, APIs REST, OAuth2, Node.js y algo de AWS, pero
que no ha tocado SAP ni ha operado nada en una nube PaaS. Cada concepto se
explica primero en esos términos y después en los de SAP.

## Cómo está organizado

El libro tiene tres partes y seis apéndices.

**Parte I. Fundamentos.** Qué es BTP, cómo se organiza una cuenta, qué es una
región, un entitlement y Cloud Foundry. Es la parte que explica el 80 % de los
"no encuentro esto en el cockpit".

**Parte II. Servicios.** El ciclo de vida de un servicio: instancias,
suscripciones, bindings, service keys. Los cuatro servicios que aparecen en
cualquier proyecto CAP: SAP HANA Cloud, XSUAA, Destination y Connectivity.
Aquí está el capítulo de HANA y HDI, el que más confusión genera.

**Parte III. CAP en BTP.** La anatomía de un proyecto CAP, cómo se traduce a
`mta.yaml`, el despliegue con `cf deploy`, el modo híbrido para probar en
local contra servicios reales, cómo diagnosticar fallos y cómo llevar la app
de desarrollo a producción.

**Apéndices.** Referencia de las tres CLIs (`cf`, `cds`, `btp`), un recetario
de tareas frecuentes con su ruta en el cockpit y su comando equivalente, el
glosario y el diario del trial donde se ha probado todo esto.

## Convenciones

Cada capítulo sigue el mismo esquema: objetivo, conceptos con un diagrama,
ejemplo real sacado de la cuenta trial, la ruta en el cockpit, el comando
equivalente en CLI con su salida, trampas típicas, resumen y ejercicio.

Las rutas del cockpit se escriben así:

> **Cockpit:** Subcuenta › Servicios › Instancias y suscripciones
> (*Subaccount › Services › Instances and Subscriptions*)

El nombre en castellano es el que muestra el cockpit configurado en español;
el nombre en inglés, entre paréntesis, es el que verás en la mayoría de las
empresas y en toda la documentación. Conviene aprender los dos. Los rótulos en
castellano cambian con más frecuencia que los ingleses, así que, ante la duda,
busca el nombre inglés en el buscador del propio cockpit.

Los comandos van en bloques con la salida recortada debajo. Los valores de
ejemplo son los reales de la cuenta trial usada para escribir el libro:

| Dato                    | Valor                                          |
|-------------------------|------------------------------------------------|
| Región                  | `us10` (AWS, Virginia)                         |
| API endpoint de CF      | `https://api.cf.us10-001.hana.ondemand.com`    |
| Subdominio / org CF     | `7b6c2113trial`                                |
| Space                   | `dev`                                          |
| Instancia SAP HANA Cloud| `hana-trial`                                   |
| Proyecto de ejemplo     | `bookshop` (generado con `cds init`)           |

Los recuadros tienen un significado fijo:

> **Idea clave.** Lo esencial del apartado en una o dos frases.

> **Analogía.** El concepto traducido a algo conocido del backend o de AWS.
> Las analogías orientan, pero cuando no encajan gana la definición de BTP.

> **Trampa.** Un error habitual y cómo evitarlo.

> **En el trial.** Diferencias entre la cuenta trial y una cuenta de empresa.

> **Pendiente de validar.** Contenido escrito a partir de la documentación que
> aún no se ha ejecutado en el trial. Al hacerlo, se corrige y se quita el aviso.

## Herramientas usadas

Todo lo que aparece en el libro se ha ejecutado con estas versiones, en Linux:

| Herramienta              | Versión | Para qué                                    |
|--------------------------|---------|---------------------------------------------|
| Node.js                  | 22      | Runtime de CAP y de las CLIs                |
| `@sap/cds-dk`            | 10.2.1  | CLI de CAP: `cds init`, `cds watch`, `cds add`, `cds bind`… |
| `mbt`                    | 1.2.51  | Construye el `.mtar` a partir de `mta.yaml` |
| `cf` CLI                 | 8.19.0  | Habla con Cloud Foundry                     |
| plugin `multiapps`       | 3.12.0  | Añade `cf deploy`, `cf undeploy`, `cf mtas`… |
| `btp` CLI                | —       | Administra cuentas y seguridad (capítulo 14)|

Cómo se instalaron y cómo se desinstalan está en el fichero `INSTALADO.md`
del proyecto.

## Cómo generar el PDF

Los capítulos son ficheros Markdown independientes dentro de `libro-btp/`.
El script `build.sh` los concatena en `libro-btp.md` y genera `libro-btp.pdf`
usando únicamente Python y Google Chrome, que ya estaban en la máquina:

```bash
cd ~/projects/btp/libro-btp
./build.sh          # genera libro-btp.md y libro-btp.pdf en ../salida/
```

Para corregir un capítulo basta editar su fichero y volver a ejecutar el
script.
