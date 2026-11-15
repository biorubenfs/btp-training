---
title: Inicio
---

# SAP BTP y CAP desde cero

**Cuaderno de referencia para un desarrollador backend.** Escrito capítulo a
capítulo mientras se hace el curso con una cuenta trial de SAP BTP en AWS us10.

Explica SAP Business Technology Platform (BTP) y el SAP Cloud Application
Programming Model (CAP) desde el punto de vista de alguien que conoce bases de
datos relacionales, APIs REST, OAuth2 y Node.js, pero que no ha tocado SAP ni
ha operado nada en una nube PaaS. Cada concepto se explica primero en esos
términos y después en los de SAP.

[Empezar por el prólogo](00-prologo.md){ .md-button .md-button--primary }
[Descargar el libro en PDF](libro-btp.pdf){ .md-button }

## Cómo está organizado

| Parte | Capítulos | De qué va |
|---|---|---|
| I. Fundamentos | 1 a 4 | Qué es BTP, cómo se organiza una cuenta, regiones, entitlements y Cloud Foundry |
| II. Servicios | 5 a 9 | Instancias, suscripciones, bindings, HANA Cloud, seguridad y destinations |
| III. CAP en BTP | 10 a 14 | Anatomía de un proyecto CAP, MTA, modo híbrido, operación y paso a producción |
| Apéndices | A a F | Referencias de `cf`, `cds` y `btp`, recetario, glosario y diario del curso |

## Convenciones

- `> **Idea clave.**` resume lo esencial de una sección.
- `> **Trampa.**` avisa de algo que cuesta descubrir por uno mismo.
- `> **En el trial.**` indica diferencias con una cuenta de pago.
- `> **Pendiente de validar.**` marca lo que aún no se ha comprobado en la cuenta trial.
- Las rutas del cockpit van en castellano primero y en inglés entre paréntesis.

El texto fuente está en Markdown en el
[repositorio de GitHub](https://github.com/biorubenfs/btp-training/tree/main/libro-btp),
desde donde se genera tanto esta web como el PDF.
