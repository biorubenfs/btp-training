# libro-btp

Libro de referencia sobre SAP BTP y CAP, escrito capítulo a capítulo en
Markdown mientras se hace el curso con la cuenta trial.

## Estructura

```
00-prologo.md                         cómo leer el libro, convenciones, herramientas
01..04                                Parte I  · Fundamentos
05..09                                Parte II · Servicios
10..14                                Parte III· CAP en BTP
A1..A6                                Apéndices: cf, cds, btp, recetario, glosario, diario
style.css                             estilo de impresión (A4)
build.sh                              genera ../salida/libro-btp.{md,html,pdf}
index.md                              portada de la versión web (no entra en el PDF)
web.css                               ajustes de estilo solo para la web
```

## Generar el libro

```bash
./build.sh                 # salida en ../salida/
./build.sh /otra/carpeta   # o donde se indique
```

Usa solo `python3` (módulo `markdown`) y `google-chrome` en modo headless,
que ya estaban instalados. Si falta Chrome, deja el HTML, que se imprime a
PDF desde cualquier navegador.

## Versión web

La misma carpeta alimenta el sitio <https://biorubenfs.github.io/btp-training/>
(MkDocs + Material, configurado en `../mkdocs.yml`). Se publica solo en cada
push a `main` mediante `.github/workflows/pages.yml`, que además ejecuta
`build.sh` y deja el PDF descargable desde la portada.

```bash
mkdocs serve      # desde la raíz del repo: vista previa en http://127.0.0.1:8000
```

Al añadir un capítulo nuevo hay que darlo de alta en la sección `nav` de
`mkdocs.yml`; `build.sh` lo recoge solo por el prefijo numérico.

## Convenciones de edición

- Un fichero por capítulo. El número del prefijo fija el orden.
- Diagramas en ASCII, máximo 80 columnas, dentro de bloques de código.
- Recuadros: `> **Idea clave.**`, `> **Analogía.**`, `> **Trampa.**`,
  `> **En el trial.**`, `> **Pendiente de validar.**`, `> **Cockpit:**`.
- Rutas del cockpit: castellano primero, inglés entre paréntesis en cursiva.
- Al validar algo en el trial: sustituir la salida reconstruida por la real y
  quitar el recuadro *Pendiente de validar*. Anotar la fecha en el diario (A6).
