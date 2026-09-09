---
title: Referencia de la API
slug: /api-reference
description: Referencia completa del esquema GraphQL de BibleQL, generada desde el propio esquema.
---

# Referencia de la API

Todo lo que hay en las páginas siguientes se genera directamente desde el esquema GraphQL de
BibleQL, así que siempre coincide con lo que la API acepta y devuelve de verdad. Nada de esto
se escribe a mano.

El esquema se exporta desde la aplicación Rails con `bundle exec rake docs:schema` y se guarda
en el repositorio como `docs/generated/schema.graphql`; CI falla si queda desactualizado. Si un
campo aparece aquí, existe en producción.

## Cómo leer estas páginas

- **Queries** — los 14 puntos de entrada. Cada uno lista sus argumentos, valores por defecto y
  tipo de retorno.
- **Objetos** — las formas que se devuelven. `Verse` y `Passage` cubren la mayoría de las
  respuestas.
- **Enums** y **Escalares** — el pequeño conjunto de valores restringidos, como `Testament`.

Toda petición necesita una API key. Si aún no tienes una, empieza por
[Autenticación](/getting-started/authentication).

:::info Esta sección está en inglés
Las páginas de referencia se generan a partir de las descripciones del esquema GraphQL, que
están en inglés y se regeneran con cada cambio de la API. Traducirlas quedaría desactualizado
de inmediato, así que se mantienen en su idioma original a propósito.

Las [guías](/guides/translations) y todo lo demás sí están traducidos al español.
:::

:::tip ¿Buscas explicaciones en lugar de firmas?
La referencia te dice *qué* es cada campo. Las [guías](/guides/translations) explican *por qué*
y *cuándo* usarlos, con ejemplos ejecutables en GraphQL, cURL, Ruby y Node.js.
:::

:::note Un marcador conocido
`Mutation.testField` es andamiaje sobrante del generador original de Rails. BibleQL es una API
de solo lectura: no hay mutations admitidas. Consulta
[Comportamiento de la API](/reference/api-behavior) para la lista completa de rarezas que
conviene conocer.
:::
