# 8. Seguridad: usuarios, roles y XSUAA

**Objetivo del capítulo.** Entender quién puede entrar, con qué roles, y cómo
una línea en `xs-security.json` acaba siendo una casilla en el cockpit y un
`403` o un `200` en tu app.

## 8.1 Dos preguntas distintas

| Pregunta         | Nombre         | Quién responde                                                         | Dónde se configura                        |
|------------------|----------------|------------------------------------------------------------------------|-------------------------------------------|
| ¿Quién eres?     | Autenticación  | Un **proveedor de identidad** (IdP). Por defecto, SAP ID Service (tu usuario de sap.com). Las empresas conectan SAP Cloud Identity Services (IAS), federado con Azure AD u otro | Subcuenta › Seguridad › Configuración de confianza (*Trust Configuration*) |
| ¿Qué puedes hacer? | Autorización | **XSUAA**, con scopes y roles agrupados en role collections asignadas a usuarios | Subcuenta › Seguridad › Roles / Colecciones de roles / Usuarios |

> **Analogía.** El IdP es el DNI: certifica quién eres. XSUAA es la lista de
> invitados de cada sala: dice dónde puedes entrar. En AWS, Cognito hace las
> dos cosas; en BTP están separadas y se nota en el cockpit.

## 8.2 De la pieza más pequeña a la más grande

```
  SCOPE  ──▶  ROLE  ──▶  ROLE COLLECTION  ──▶  USUARIO
 permiso      agrupa      agrupa roles,          la recibe,
 atómico      scopes      incluso de apps        directamente o vía
 ("Admin")    (desde un   distintas.             grupos del IdP
 definido     role        ES LO ÚNICO QUE
 por la app   template)   SE ASIGNA
```

| Pieza           | Quién la define                                 | Dónde se ve                                      |
|-----------------|-------------------------------------------------|--------------------------------------------------|
| Scope           | Tu app, en `xs-security.json`                   | Dentro del rol, en Seguridad › Roles              |
| Role template   | Tu app, en `xs-security.json`                   | Seguridad › Roles (un rol por template al desplegar) |
| Role            | Se genera al desplegar la instancia XSUAA       | Seguridad › Roles, con el nombre de la app como prefijo |
| Role collection | Un administrador, o tu `xs-security.json`       | Seguridad › Colecciones de roles                  |
| Asignación      | Un administrador                                | Seguridad › Usuarios › (usuario) › Colecciones de roles |

## 8.3 Las tres capas de permisos

Hay tres sistemas de permisos independientes, cada uno gestionado en un sitio
distinto. Es la parte más confusa al principio.

| Capa          | Ejemplos                                                                              | Dónde se gestiona                                              |
|---------------|---------------------------------------------------------------------------------------|----------------------------------------------------------------|
| Cuenta global | Global Account Administrator, Global Account Viewer                                   | Cockpit, nivel cuenta global › Seguridad                       |
| Subcuenta     | Subaccount Administrator, Subaccount Viewer, SAP HANA Cloud Administrator, Destination Administrator, **las de tus apps** (`Bookshop_Admin`) | Cockpit, dentro de la subcuenta › Seguridad |
| Cloud Foundry | Org Manager, Space Developer, Space Manager, Auditor                                  | Cockpit › org o space › Miembros. **No son role collections**  |

> **Trampa.** Ser administrador de la cuenta global **no** da permisos dentro
> de una subcuenta, ni en sus spaces. Cada capa se asigna por separado. En el
> trial SAP lo hace todo por ti; en una empresa, el primer día tendrás que
> pedir que te añadan en las tres.

Qué pedir el primer día en una empresa, para aprender sin romper nada:

- *Subaccount Viewer* en la subcuenta de desarrollo (ver todo, tocar nada).
- *Space Developer* en el space `dev` (desplegar).
- Más adelante, *Subaccount Administrator* solo en dev.

## 8.4 La cadena completa, de tu fichero al usuario

```
  xs-security.json ──deploy──▶ instancia XSUAA ──▶ Roles ──▶ Role Collection ──▶ Usuario
  scopes +                     bookshop-auth        Seguridad   Bookshop_Admin      Seguridad
  role-templates                                    › Roles     (la crea alguien)   › Usuarios
                                                                                        │
                                                                                        ▼
                                              el approuter pide a XSUAA un JWT con los scopes
                                              del usuario ──▶ CAP evalúa @requires / @restrict
```

### Paso 1: declarar scopes y roles en `xs-security.json`

Cuando se ejecuta `cds add xsuaa`, el fichero nace vacío:

```json
{
  "scopes": [],
  "attributes": [],
  "role-templates": []
}
```

Para bookshop añadimos un scope y un rol de administrador. El `$XSAPPNAME` es
un marcador que XSUAA sustituye por el nombre real de la app, que en el
`mta.yaml` generado es `bookshop-${org}-${space}`:

```json
{
  "xsappname": "bookshop",
  "tenant-mode": "dedicated",
  "scopes": [
    { "name": "$XSAPPNAME.Admin", "description": "Administrar el catálogo" }
  ],
  "attributes": [],
  "role-templates": [
    {
      "name": "Admin",
      "description": "Administrador de bookshop",
      "scope-references": ["$XSAPPNAME.Admin"]
    }
  ],
  "role-collections": [
    {
      "name": "Bookshop_Admin",
      "description": "Administradores de bookshop",
      "role-template-references": ["$XSAPPNAME.Admin"]
    }
  ]
}
```

La sección `role-collections` es opcional: si la pones, el deploy crea la
colección y te ahorra el paso 3. Es lo recomendable para que el proyecto sea
reproducible.

> **Pendiente de validar.** En CAP, `cds add xsuaa` más `cds build` pueden
> generar los scopes a partir de las anotaciones `@requires` del modelo. Se
> comprobará qué genera cds-dk 10.2.1 al desplegar bookshop.

### Paso 2: usar el scope en el modelo CAP

```cds
// srv/admin-service.cds
using { CatalogService } from './cat-service';

@requires: 'Admin'
service AdminService {
  entity Books as projection on CatalogService.Books;
}
```

| Anotación                        | Efecto                                                                  |
|----------------------------------|-------------------------------------------------------------------------|
| `@requires: 'Admin'`             | Solo tokens con el scope `Admin` pueden llamar al servicio. Si no, `403` |
| `@requires: 'authenticated-user'`| Cualquier usuario autenticado. Sin token, `401`                          |
| `@restrict: [{ grant: 'READ', to: 'Viewer' }, { grant: '*', to: 'Admin' }]` | Permisos por operación y rol         |
| `@restrict: [{ grant: '*', to: 'Admin', where: 'createdBy = $user' }]` | Permisos por fila                          |

CAP traduce "rol" a "scope del token". El nombre `Admin` en el modelo
corresponde al `$XSAPPNAME.Admin` del `xs-security.json`.

### Paso 3: desplegar y comprobar que el rol existe

Tras `cf deploy`:

> **Cockpit:** Subcuenta › Seguridad › Roles (*Security › Roles*). Filtra por
> `bookshop`: aparece el rol `Admin` con la aplicación `bookshop-7b6c2113trial-dev!t12345`.

El sufijo `!t12345` es el identificador que XSUAA añade a cada instancia. Es
normal y no se configura.

### Paso 4: role collection y asignación

> **Cockpit:** Subcuenta › Seguridad › Colecciones de roles › Crear
> (*Role Collections › Create*) › nombre `Bookshop_Admin` › Editar › Añadir rol
> › aplicación `bookshop-…`, rol `Admin` › Guardar.
>
> **Cockpit:** Subcuenta › Seguridad › Usuarios › (tu usuario) › Asignar
> colección de roles (*Assign Role Collection*) › `Bookshop_Admin`.

Con la `btp` CLI (capítulo 14):

```bash
btp create security/role-collection Bookshop_Admin --description "Administradores de bookshop"
btp add security/role Admin --to-role-collection Bookshop_Admin \
    --of-app bookshop-7b6c2113trial-dev!t12345 --of-role-template Admin
btp assign security/role-collection Bookshop_Admin --to-user mi@correo.com --of-idp sap.default
```

> **Pendiente de validar.** Comandos tomados de la referencia de `btp`. Se
> ejecutarán cuando se instale la CLI.

### Paso 5: el token

Cuando el usuario entra por el approuter, este lo redirige a XSUAA, XSUAA al
IdP, y de vuelta el approuter recibe un JWT con los scopes de las role
collections del usuario. Lo reenvía a `bookshop-srv` en la cabecera
`Authorization: Bearer …`. CAP valida la firma con la `verificationkey` y
compara los scopes con `@requires`.

```
  navegador ──▶ approuter ──302──▶ XSUAA ──302──▶ IdP (login) ──▶ XSUAA ──▶ approuter
                   │                                                             │
                   │  guarda la sesión; en cada petición añade                   │
                   │  Authorization: Bearer <JWT con scopes>                     │
                   ▼                                                             │
              bookshop-srv ◀─────────────────────────────────────────────────────┘
              @requires: 'Admin' → mira si el JWT trae bookshop-…!t12345.Admin
```

> **Trampa.** Asignas la role collection, recargas la app y sigue dando 403.
> El token en sesión es el viejo, sin el nuevo scope. **Cierra sesión y
> vuelve a entrar.** Es el error más repetido de todo BTP.

## 8.5 401 frente a 403

| Código | Significa                                        | Causa habitual                                                                          | Dónde mirar                                 |
|--------|--------------------------------------------------|-----------------------------------------------------------------------------------------|---------------------------------------------|
| 401    | No sé quién eres                                 | Llamas a `srv` directamente por su route, sin token. O el approuter no tiene XSUAA ligada | Service Bindings del approuter; `xs-app.json` |
| 403    | Sé quién eres y no puedes                        | Rol existe pero no te asignaron la role collection, o token viejo                       | Seguridad › Usuarios; cerrar sesión          |

## 8.6 Role collections de la plataforma

Aparte de las de tus apps, hay colecciones predefinidas que dan permisos sobre
el propio cockpit:

| Role collection                 | Permite                                                             |
|---------------------------------|---------------------------------------------------------------------|
| Subaccount Administrator        | Todo en la subcuenta: servicios, usuarios, destinations             |
| Subaccount Viewer               | Ver todo, tocar nada. **La que pedir para aprender**                |
| SAP HANA Cloud Administrator    | HANA Cloud Central: crear, parar, arrancar, mapear instancias       |
| Destination Administrator       | Crear y editar destinations                                         |
| Cloud Connector Administrator   | Gestionar Cloud Connectors                                          |
| Global Account Administrator    | Nivel cuenta global: entitlements, subcuentas, directorios          |

## 8.7 El proveedor de identidad en la empresa

> **Cockpit:** Subcuenta › Seguridad › Configuración de confianza (*Trust
> Configuration*). Lista los IdPs conectados. En el trial solo está *SAP ID
> Service* (`sap.default`).

En una empresa suele haber dos: `sap.default` y el tenant de IAS corporativo
(`accounts.sap.com` o un dominio propio). Consecuencias prácticas:

- Tu usuario puede aparecer **dos veces** en Seguridad › Usuarios: uno por
  cada IdP. Las role collections se asignan a uno de los dos y el otro no las
  ve. Si tienes 403 "sin motivo", comprueba con qué IdP entraste.
- Con IAS, las role collections se pueden asignar a **grupos** del IdP en
  lugar de a personas: Seguridad › Colecciones de roles › (colección) › Grupos.
  Es la forma escalable.

## 8.8 Trampas

> **Trampa.** Token viejo tras asignar la role collection. Cerrar sesión.

> **Trampa.** Dos usuarios con el mismo correo, de IdPs distintos. Asignar la
> colección al que usas para entrar.

> **Trampa.** Confundir roles de CF (Space Developer, para desplegar) con role
> collections de BTP (para usar apps y el cockpit). Hacen falta los dos y se
> piden en sitios distintos.

> **Trampa.** Cambiar `xs-security.json` y redesplegar: XSUAA actualiza
> scopes y roles, pero las role collections que creó alguien a mano no se
> tocan. Si renombras un role template, la colección se queda con el viejo.

## Para recordar

- Autenticación (IdP, Trust Configuration) ≠ autorización (XSUAA, roles).
- Scope ⊂ role ⊂ role collection → usuario. Solo se asignan role collections.
- Tres capas independientes: cuenta global, subcuenta y Cloud Foundry.
- `xs-security.json` → deploy → rol en Seguridad › Roles → role collection →
  usuario → token → `@requires`.
- 401 = sin token (approuter). 403 = sin rol (role collection o token viejo).
- ¿403 tras asignar? Cerrar sesión y volver a entrar.

## Ejercicio

1. En bookshop, añade el scope y el role template `Admin` del apartado 8.4 y
   anota `@requires: 'Admin'` en un servicio de administración. Redespliega.
2. Comprueba que el rol aparece en Seguridad › Roles. Crea la role collection
   `Bookshop_Admin`, añade el rol y asígnatela.
3. Prueba el servicio antes y después de cerrar sesión. Explica el resultado
   en una frase.
