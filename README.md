# btp-training

Curso de SAP BTP y CAP hecho sobre una cuenta trial, y el libro que sale de él.

- **Web:** https://biorubenfs.github.io/btp-training/ (navegable, con búsqueda; se publica sola en cada push a `main`)
- **PDF:** enlazado desde la portada de la web, o generado en local con `libro-btp/build.sh`

## Contenido

```
libro-btp/      capítulos en Markdown (uno por fichero), build.sh para el PDF, web.css e index.md para la web
mkdocs.yml      orden de capítulos, tema y búsqueda del sitio web
.github/        workflow que construye la web y el PDF y los publica en GitHub Pages
INSTALADO.md    registro de herramientas instaladas para el curso y cómo quitarlas
apuntes-btp.md  apuntes previos al libro
```

## Trabajar en local

```bash
mkdocs serve          # vista previa en http://127.0.0.1:8000 con recarga automática
libro-btp/build.sh    # genera salida/libro-btp.{md,html,pdf}
```

Para `mkdocs serve` hace falta `mkdocs` con el tema Material (ver INSTALADO.md).
