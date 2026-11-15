# Registro de instalaciones

Herramientas instaladas para el curso de BTP, con el comando usado y cómo desinstalarlas.

## Entorno base (ya existente, no instalado por el curso)

- Node.js v22.22.0 vía nvm (`~/.nvm/versions/node/v22.22.0`)
- npm 10.9.4
- git 2.43.0
- mkdocs 1.6.1 vía pipx (`~/.local/share/pipx/venvs/mkdocs`), instalado antes del curso

## Instalaciones

### 2026-11-12 · @sap/cds-dk 10.2.1

- **Para qué:** CLI de SAP CAP (`cds init`, `cds watch`, `cds add`, `cds bind`, `cds deploy`…).
- **Comando:**
  ```bash
  npm i -g @sap/cds-dk mbt
  ```
  (instalado en el mismo comando que `mbt`)
- **Tipo:** paquete npm global (dentro de la versión de Node activa en nvm).
- **Ubicación:** `~/.nvm/versions/node/v22.22.0/lib/node_modules/@sap/cds-dk`
- **Binarios:** `cds`, `cds-ts`, `cds-tsx` en `~/.nvm/versions/node/v22.22.0/bin/`
- **Desinstalar:**
  ```bash
  npm uninstall -g @sap/cds-dk
  ```

### 2026-11-12 · mbt 1.2.51 (Cloud MTA Build Tool)

- **Para qué:** construir el archivo `.mtar` a partir de `mta.yaml` (`mbt build`).
- **Comando:**
  ```bash
  npm i -g @sap/cds-dk mbt
  ```
  (instalado en el mismo comando que `@sap/cds-dk`)
- **Tipo:** paquete npm global. Su script de instalación descarga el binario Go de mbt dentro de su propia carpeta.
- **Ubicación:** `~/.nvm/versions/node/v22.22.0/lib/node_modules/mbt`
- **Binarios:** `mbt` en `~/.nvm/versions/node/v22.22.0/bin/`
- **Desinstalar:**
  ```bash
  npm uninstall -g mbt
  ```

### 2026-11-12 · cf CLI 8.19.0 (Cloud Foundry CLI)

- **Para qué:** interactuar con Cloud Foundry (`cf login`, `cf apps`, `cf logs`, `cf env`, `cf deploy` con plugin…).
- **Comandos:**
  ```bash
  mkdir -p ~/.local/bin
  curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&version=v8&source=github" | tar -zx -C ~/.local/bin cf8
  ln -sf ~/.local/bin/cf8 ~/.local/bin/cf
  cf version
  ```
- **Tipo:** binario descargado en el home, sin sudo ni apt.
- **Ubicación:**
  - `~/.local/bin/cf8`: binario
  - `~/.local/bin/cf`: enlace simbólico a `cf8`
  - `~/.cf/`: configuración y plugins, que cf crea al usarse (`config.json`, `plugins/`). Guarda la sesión de `cf login`.
- **Desinstalar:**
  ```bash
  cf logout                       # opcional, cierra la sesión antes
  rm ~/.local/bin/cf ~/.local/bin/cf8
  rm -rf ~/.cf
  ```
  Nota: `~/.local/bin` puede contener otras herramientas, así que no se borra la carpeta, solo los dos ficheros.

### 2026-11-12 · Plugin multiapps 3.12.0 (para cf CLI)

- **Para qué:** añade a cf los comandos de MTA: `cf deploy`, `cf undeploy`, `cf mtas`, `cf mta`, `cf bg-deploy`, `cf dmol`…
- **Comando:**
  ```bash
  cf install-plugin multiapps -f
  ```
- **Tipo:** plugin de cf CLI descargado del repositorio oficial CF-Community.
- **Ubicación:** `~/.cf/plugins/multiapps`, registrado en `~/.cf/plugins/config.json`
- **Desinstalar:**
  ```bash
  cf uninstall-plugin multiapps
  ```
  (también desaparece al borrar `~/.cf` al desinstalar la cf CLI)

### 2026-11-15 · mkdocs-material 9.7.1

- **Para qué:** tema Material para MkDocs, con el que se genera la web del libro (`mkdocs serve` / `mkdocs build`). Solo hace falta en local para previsualizar; el workflow de GitHub Pages lo instala por su cuenta en el runner.
- **Comando:**
  ```bash
  pipx inject mkdocs mkdocs-material
  ```
- **Tipo:** paquete Python inyectado en el venv de pipx de mkdocs (no toca el Python del sistema).
- **Ubicación:** `~/.local/share/pipx/venvs/mkdocs/lib/python3.12/site-packages/material`
- **Desinstalar:**
  ```bash
  pipx uninject mkdocs mkdocs-material
  ```

## Pendientes (propuestas, aún no instaladas)

- **btp CLI**: binario descargado de tools.hana.ondemand.com (módulo 10).

## Desinstalar todo lo del curso

```bash
# Paquetes npm globales
npm uninstall -g @sap/cds-dk mbt

# Tema Material de MkDocs (mkdocs en sí ya estaba antes del curso)
pipx uninject mkdocs mkdocs-material

# cf CLI (incluye sus plugins y configuración)
rm ~/.local/bin/cf ~/.local/bin/cf8
rm -rf ~/.cf
```
