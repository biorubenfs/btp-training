# Parte I. Fundamentos

# 1. La nube y SAP BTP

**Objetivo del capítulo.** Tener el vocabulario mínimo de nube para que BTP no
suene a magia, y situar BTP y su cockpit en el mapa de productos SAP.

## 1.1 Tres capas de servicio

Cuando alguien dice "la nube" puede estar hablando de tres cosas distintas:

| Capa | Qué te dan                                             | Qué haces tú                            | Ejemplos                               |
|------|--------------------------------------------------------|-----------------------------------------|----------------------------------------|
| IaaS | Máquinas virtuales, red, disco                         | Instalar y operar todo lo demás         | AWS EC2, Azure VMs                     |
| PaaS | Un sitio donde subir código y servicios ya gestionados | Escribir la app y declarar qué necesita | **SAP BTP**, Heroku, Elastic Beanstalk |
| SaaS | Una aplicación terminada                               | Configurarla y usarla                   | SuccessFactors, S/4HANA Cloud, Jira    |

BTP es PaaS. Nunca verás un servidor, un sistema operativo ni un balanceador.
Subes la app, declaras que necesita una base de datos y un servicio de login,
y la plataforma te los da.

> **Analogía.** Si vienes de AWS, BTP se parece más a Elastic Beanstalk + RDS
> + Cognito que a EC2. Si vienes de Heroku, la sensación es casi la misma:
> `git push` se convierte en `cf deploy`, y los add-ons en instancias de
> servicio.

## 1.2 Ideas que vas a usar todos los días

**Región.** Centro de datos físico donde corre tu aplicación. En BTP se
identifican con códigos como `eu10` (Frankfurt, AWS), `eu20` (Países Bajos,
Azure) o `us10` (Virginia, AWS). La región fija la URL de tus apps y dónde
viven tus datos.

**Hyperscaler.** El proveedor de infraestructura que hay debajo. BTP no tiene
centros de datos propios: corre sobre AWS, Azure, Google Cloud o Alibaba según
la región. Tú nunca lo tocas, pero explica por qué existen tantas regiones y
por qué algunos servicios no están en todas.

**Servicio gestionado.** Una base de datos, una cola o un servicio de
autenticación que alguien opera por ti. El ciclo es siempre el mismo: pides
una instancia, te dan unas credenciales, las usas. Este ciclo es el corazón
del cockpit y ocupa toda la Parte II.

**Multi-tenant.** Un mismo servicio atiende a muchos clientes aislados entre
sí. Muchos servicios de BTP funcionan así, y las apps CAP pueden ser
multi-tenant también. Aparece en las credenciales como `tenantid` y
`tenantmode`.

**Escalado horizontal.** Más copias de la app en lugar de una máquina más
grande. En Cloud Foundry cada copia se llama *instance* de la aplicación, no
confundir con *instancia de servicio*.

**Twelve-factor app.** Un conjunto de reglas que las plataformas PaaS asumen:
la configuración va en variables de entorno, los logs van a la salida
estándar, la app no guarda estado en disco local, arranca rápido y muere
limpio. Cloud Foundry da por hecho que tu app las cumple. CAP las cumple por
defecto.

```
  TU APP (twelve-factor)                 CLOUD FOUNDRY
  ┌──────────────────────────┐           ┌─────────────────────────────┐
  │ lee config de            │ ◀──────── │ inyecta variables de entorno│
  │   process.env            │           │   PORT, VCAP_SERVICES…      │
  │ escribe logs en stdout   │ ────────▶ │ recoge stdout → cf logs     │
  │ no guarda ficheros       │           │ puede matar y recrear el    │
  │ escucha en $PORT         │ ◀──────── │ contenedor en cualquier     │
  └──────────────────────────┘           │ momento                     │
                                         └─────────────────────────────┘
```

> **Para un dev CAP.** Cuando haces `cds watch` en local, CAP usa SQLite en
> memoria y un login simulado. En BTP esos dos huecos los rellenan dos
> servicios gestionados, SAP HANA Cloud y XSUAA. Tu código no cambia. Lo que
> cambia es el *binding* (capítulo 6).

## 1.3 Qué es SAP BTP

SAP Business Technology Platform es la plataforma en la nube de SAP. Sirve
para tres cosas:

1. **Extender** los sistemas SAP (S/4HANA, SuccessFactors) sin tocar su
   núcleo. Es el uso mayoritario y la razón de ser de CAP.
2. **Integrar** sistemas entre sí (Integration Suite).
3. **Construir** aplicaciones nuevas que necesitan hablar con el mundo SAP.

SAP la agrupa en cuatro bloques: desarrollo de aplicaciones y automatización,
integración, datos y analítica, e inteligencia artificial. Como desarrollador
CAP vives en el primero y usas piezas del tercero (HANA).

## 1.4 Qué es el cockpit

El cockpit es la consola web de administración de BTP:

- Trial: `https://cockpit.hanatrial.ondemand.com`
- Productivo: `https://cockpit.btp.cloud.sap`

Desde él gestionas cuentas, das permisos a personas, creas instancias de
servicios, configuras conexiones a otros sistemas y miras el estado de las
aplicaciones.

Lo que **no** es: ni un IDE ni un sistema de despliegue. El código se
despliega desde la línea de comandos o desde un pipeline, y el cockpit te
enseña el resultado. Casi todo lo que haces en el cockpit tiene un comando
equivalente en `cf` o en `btp`, y este libro los da siempre juntos.

> **Idea clave.** El cockpit es la vista; `cf` y `btp` son el control remoto.
> Aprende los dos a la vez: hacer algo en el cockpit y comprobarlo en la CLI
> (o al revés) es la forma más rápida de entender qué ha pasado de verdad.

## 1.5 Los entornos de ejecución

BTP ofrece varios *runtimes* donde ejecutar código. Una subcuenta puede tener
varios habilitados a la vez.

| Entorno           | Qué es                                                                 | Cuándo lo verás                                            |
|-------------------|------------------------------------------------------------------------|------------------------------------------------------------|
| **Cloud Foundry** | PaaS de código abierto. Subes una app y la plataforma se ocupa de contenedores, rutas y escalado | La inmensa mayoría de proyectos CAP. **El foco de este libro** |
| Kyma              | Kubernetes gestionado con extras serverless. Más control, más complejidad | Proyectos con contenedores propios o equipos que ya usan Kubernetes |
| ABAP environment  | Un sistema ABAP en la nube ("Steampunk")                               | Equipos ABAP que extienden S/4HANA. No lo tocarás desde CAP |
| Neo               | El entorno antiguo de BTP, en retirada                                 | Solo proyectos heredados                                   |

## 1.6 Ejemplo: lo que ves al entrar por primera vez

Al abrir el cockpit del trial y entrar en la subcuenta, la vista general
muestra algo así (valores reales de la cuenta usada en el libro):

```
Subcuenta: trial
  Región:          US East (VA)  ·  Proveedor: Amazon Web Services (AWS)
  Subdominio:      7b6c2113trial
  Entornos:        Cloud Foundry  ✔ habilitado
                     Org:          7b6c2113trial
                     API endpoint: https://api.cf.us10-001.hana.ondemand.com
                   Kyma           disponible, no habilitado
```

Tres cosas de esta pantalla las vas a usar constantemente: el **API
endpoint** (para `cf login`), el **subdominio** (aparece en URLs y tokens) y
el nombre de la **org** (para `cf target`).

> **Cockpit:** Subcuenta › Visión general (*Subaccount › Overview*)

Comprobación desde la CLI, sin haber hecho login todavía:

```bash
cf api https://api.cf.us10-001.hana.ondemand.com
```

```
Setting API endpoint to https://api.cf.us10-001.hana.ondemand.com...
OK

API endpoint:   https://api.cf.us10-001.hana.ondemand.com
API version:    3.209.0
Not logged in. Use 'cf login' or 'cf login --sso' to log in.
```

## 1.7 Trampas

> **Trampa.** Confundir "instancia de la aplicación" (una copia de tu app en
> Cloud Foundry, `cf scale -i 2`) con "instancia de servicio" (un recurso
> creado a partir del catálogo, por ejemplo un contenedor HDI). El cockpit usa
> la misma palabra para las dos. Cuando leas "instancia", pregúntate de qué.

> **Trampa.** Buscar en el cockpit un botón de "desplegar". No existe. El
> despliegue se hace con `cf push`, `cf deploy` o `cds up`. El cockpit solo
> muestra el resultado.

## Para recordar

- BTP es PaaS: subes código, declaras servicios, no ves servidores.
- Corre sobre AWS, Azure o GCP según la región. La región fija URLs y datos.
- El cockpit es la vista; `cf` y `btp` son el control.
- Cloud Foundry es el runtime estándar para CAP. Kyma es la alternativa con
  Kubernetes.
- CAP sigue las reglas twelve-factor, por eso encaja en Cloud Foundry sin
  cambiar código entre local y nube.

## Ejercicio

1. Entra en el trial y, en la vista general de la subcuenta, anota región,
   proveedor, subdominio, nombre de la org y API endpoint.
2. Ejecuta `cf api <endpoint>` y comprueba que responde.
3. Abre un proyecto CAP (vale el `bookshop` del capítulo 10) y localiza tres
   cosas que sigan las reglas twelve-factor: de dónde lee la configuración, a
   dónde van los logs y qué pasa con los ficheros.
