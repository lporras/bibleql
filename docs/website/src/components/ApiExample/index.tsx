import React from "react";
import Tabs from "@theme/Tabs";
import TabItem from "@theme/TabItem";
import CodeBlock from "@theme/CodeBlock";
import Admonition from "@theme/Admonition";
import Translate, { translate } from "@docusaurus/Translate";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";

import examples from "@site/src/examples";
import {
  EXAMPLES,
  GRAPHQL_ENDPOINT,
  SDK,
  SDK_SETUP,
  type DocsLocale,
} from "@site/src/constants";

interface ApiExampleProps {
  /** Key into src/examples — usually the GraphQL query name, e.g. "passage". */
  op: keyof typeof examples | string;
  /** Override the locale's default translation for this one example. */
  translation?: string;
  /**
   * Omit the client-setup preamble from the Ruby and Node tabs. Use on pages that
   * already showed the setup just above the example.
   */
  noSetup?: boolean;
}

/** Fill {{placeholders}} from the locale's example values, plus any override. */
function substitute(source: string, values: Record<string, string>): string {
  return source.replace(/\{\{(\w+)\}\}/g, (whole, key: string) =>
    key in values ? values[key] : whole,
  );
}

/**
 * Build a runnable cURL command from the GraphQL document.
 *
 * The document goes through JSON.stringify, so quotes and newlines are escaped exactly
 * the way the endpoint expects. Writing this by hand is where GraphQL-in-JSON examples
 * usually go wrong.
 */
function toCurl(graphql: string): string {
  const body = JSON.stringify({ query: graphql.replace(/\s+/g, " ").trim() });

  return [
    `curl ${GRAPHQL_ENDPOINT} \\`,
    `  -H "Authorization: Bearer $BIBLEQL_API_KEY" \\`,
    `  -H "Content-Type: application/json" \\`,
    `  --data '${body.replace(/'/g, `'\\''`)}'`,
  ].join("\n");
}

function UnsupportedInSdk({ sdk }: { sdk: "ruby" | "node" }) {
  const { name, repo } = SDK[sdk];

  const title = translate(
    {
      id: "apiExample.unsupported.title",
      message: "Not available in {sdkName} yet",
      description: "Heading shown when an SDK has no method for the documented query",
    },
    { sdkName: name },
  );

  return (
    <Admonition type="info" title={title}>
      <p>
        <Translate
          id="apiExample.unsupported.body"
          description="Explanation shown when an SDK has no method for the documented query"
          values={{
            sdkLink: (
              <a href={repo} target="_blank" rel="noreferrer">
                {name}
              </a>
            ),
            graphqlTab: <strong>GraphQL</strong>,
            curlTab: <strong>cURL</strong>,
          }}
        >
          {
            "This query has no dedicated method in {sdkLink} as of its current release. Use the {graphqlTab} or {curlTab} tab, or send the document with any HTTP client."
          }
        </Translate>
      </p>
    </Admonition>
  );
}

export default function ApiExample({
  op,
  translation,
  noSetup = false,
}: ApiExampleProps): React.ReactElement {
  const { i18n } = useDocusaurusContext();
  const locale = (i18n.currentLocale in EXAMPLES ? i18n.currentLocale : "en") as DocsLocale;

  const example = examples[op];
  if (!example) {
    throw new Error(
      `ApiExample: no example defined for "${op}". Add it to docs/website/src/examples/index.ts.`,
    );
  }

  const values: Record<string, string> = {
    ...EXAMPLES[locale],
    ...(translation ? { translation } : {}),
  };

  const graphql = substitute(example.graphql, values);
  const curl = toCurl(graphql);

  // Prepend client setup so each SDK snippet runs as pasted.
  const withSetup = (snippet: string, sdk: "ruby" | "node") =>
    noSetup ? snippet : `${SDK_SETUP[sdk]}\n\n${snippet}`;

  return (
    <Tabs groupId="api-example" queryString>
      <TabItem value="graphql" label="GraphQL" default>
        <CodeBlock language="graphql">{graphql}</CodeBlock>
      </TabItem>

      <TabItem value="curl" label="cURL">
        <CodeBlock language="bash">{curl}</CodeBlock>
      </TabItem>

      <TabItem value="ruby" label="Ruby">
        {example.ruby ? (
          <CodeBlock language="ruby">
            {withSetup(substitute(example.ruby, values), "ruby")}
          </CodeBlock>
        ) : (
          <UnsupportedInSdk sdk="ruby" />
        )}
      </TabItem>

      <TabItem value="node" label="Node.js">
        {example.node ? (
          <CodeBlock language="typescript">
            {withSetup(substitute(example.node, values), "node")}
          </CodeBlock>
        ) : (
          <UnsupportedInSdk sdk="node" />
        )}
      </TabItem>

      {example.response?.[locale] ? (
        <TabItem value="response" label="Response">
          <CodeBlock language="json">{example.response[locale]}</CodeBlock>
        </TabItem>
      ) : null}
    </Tabs>
  );
}
