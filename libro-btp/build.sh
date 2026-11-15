#!/usr/bin/env bash
# Construye el libro: concatena los capítulos en un único Markdown y genera el PDF.
# Requisitos (ya presentes en la máquina): python3 con el módulo "markdown" y google-chrome.
# No instala nada.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$HERE/../salida}"
mkdir -p "$OUT"

MD="$OUT/libro-btp.md"
HTML="$OUT/libro-btp.html"
PDF="$OUT/libro-btp.pdf"

# 1. Markdown único (orden: 00..14, luego A1..A6). El bloque YAML inicial del prólogo se omite.
{
  for f in "$HERE"/[0-9][0-9]-*.md "$HERE"/A[0-9]-*.md; do
    if head -1 "$f" | grep -q '^---$'; then
      awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2 {print}' "$f"
    else
      cat "$f"
    fi
    printf '\n\n'
  done
} > "$MD"
echo "Markdown: $MD ($(wc -l < "$MD") líneas)"

# 2. HTML con portada, índice y estilo de impresión.
python3 -I - "$MD" "$HERE/style.css" "$HTML" <<'PY'
import sys, re, datetime, html
import markdown

md_path, css_path, html_path = sys.argv[1:4]
text = open(md_path, encoding="utf-8").read()
css = open(css_path, encoding="utf-8").read()

md = markdown.Markdown(extensions=["tables", "fenced_code", "codehilite", "toc", "sane_lists", "smarty"],
                       extension_configs={"codehilite": {"guess_lang": False, "noclasses": False},
                                          "toc": {"toc_depth": "1-2", "title": ""}})
body = md.convert(text)
toc = md.toc
# Portadillas de parte: los <h1> que empiezan por "Parte " o son "Apéndices"
body = re.sub(r'<h1 id="([^"]*)">(Parte [IVX]+\.[^<]*|Apéndices)</h1>', r'<h1 id="\1" class="parte">\2</h1>', body)

today = datetime.date.today().isoformat()
page = f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<title>SAP BTP y CAP desde cero</title>
<style>{css}</style></head>
<body>
<div class="portada">
  <h1>SAP BTP y CAP desde cero</h1>
  <div class="sub">Cuaderno de referencia para un desarrollador backend</div>
  <div class="meta">Escrito sobre una cuenta trial en AWS us10<br>Versión del {today}</div>
</div>
<div class="toc"><h1>Índice</h1>{toc}</div>
{body}
</body></html>"""
open(html_path, "w", encoding="utf-8").write(page)
print(f"HTML: {html_path}")
PY

# 3. PDF con Chrome headless (sin cabeceras ni pies del navegador).
if command -v google-chrome >/dev/null 2>&1; then
  google-chrome --headless=new --disable-gpu --no-sandbox \
    --no-pdf-header-footer --print-to-pdf="$PDF" "file://$HTML" 2>/dev/null \
    && echo "PDF: $PDF ($(du -h "$PDF" | cut -f1))"
else
  echo "google-chrome no encontrado: se omite el PDF (queda el HTML, imprimible desde cualquier navegador)."
fi
