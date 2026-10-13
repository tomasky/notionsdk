# kupas/notionsdk

A MoonBit port of [`@notionhq/client`](https://github.com/makenotion/notion-sdk-js)
(the Notion SDK for JavaScript). It keeps the API surface and the request logic
of the original: the same endpoints, the same parameter filtering, the same
headers, the same retry rules, the same error codes and the same webhook
signature scheme.

What changes is the language and the transport. Payload objects travel as
`Json`, and the client never calls the network itself — you hand it a `fetch`
function. That keeps the SDK usable on every runtime and trivial to test.

## Quick start

```moonbit nocheck
///|
fn main {
  let fetch : @notionsdk.Fetch = (url, init) => {
    // Connect a real HTTP stack here (for example one built on
    // moonbitlang/async) and return an HttpResponse.
    @notionsdk.HttpResponse::from_text(
      status=200,
      headers=[],
      body="{\"object\":\"user\",\"id\":\"u1\"}",
    )
  }

  let client = @notionsdk.Client::new(
    options=@notionsdk.ClientOptions::new(
      auth=Some("secret_your_integration_token"),
      fetch=Some(fetch),
    ),
  )

  let me = (client.users().me)({})
  println(me.stringify())
}
```

There is a runnable version of this in `cmd/main`: `moon run cmd/main`.

Resource calls mirror the JavaScript client:

```moonbit nocheck
///|
let page = (client.pages().create)({
  "parent": { "page_id": parent },
  "properties": {},
})

///|
let block = (client.blocks().retrieve)({ "block_id": block_id })

///|
let results = (client.search().search)({ "query": "roadmap" })

///|
let events = (client.sessions().stream)({ "message": "hi" })
```

The resource accessors are `users()`, `pages()`, `blocks()`, `databases()`,
`data_sources()`, `comments()`, `file_uploads()`, `views()`, `search()`,
`agents()`, `async_tasks()`, `plugins()`, `skills()`, `sessions()` and
`oauth()`.

## What maps to what

| TypeScript source | MoonBit file |
| --- | --- |
| `src/Client.ts` | `Client.mbt` |
| `src/api-endpoint-methods.ts` | `api_endpoint_methods.mbt` |
| `src/api-endpoints.ts` + `src/api-endpoints/*.ts` | `api-endpoints/*.mbt` |
| `src/errors.ts` | `errors.mbt` |
| `src/helpers.ts` | `helpers.mbt` |
| `src/utils.ts` | `utils.mbt` |
| `src/logging.ts` | `logging.mbt` |
| `src/constants.ts` | `constants.mbt` |
| `src/fetch-types.ts` | `fetch_types.mbt` |
| `src/webhooks.ts` | `webhooks.mbt` (+ `sha256.mbt`) |

The object *types* in the original are generated and enormous. Rather than
transcribe them, this port carries payloads as `Json`; `api-endpoints/` keeps the
part that drives behavior — the HTTP method, the path, and the path/query/body/
form-data parameter names.

## Documentation

- [`docs/API.md`](docs/API.md) — reference for every method: HTTP verb, path,
  parameters and usage examples.

## Error handling

Every failure is a `NotionClientError` wrapping a `NotionError` with `code`,
`message`, `status`, `headers`, `body`, `additional_data`, `request_id` and
`ray_id`, matching the TypeScript error fields.

```moonbit nocheck
///|
let response = (client.pages().retrieve)({ "page_id": id }) catch {
  @notionsdk.NotionClientError(error) => {
    if error.code == "object_not_found" {
      // handle a missing page
    }
    @notionsdk.Json::null()
  }
  _ => @notionsdk.Json::null()
}
```

Helpers: `is_notion_client_error`, `is_http_response_error`,
`is_api_response_error`, `APIErrorCode::from_string`,
`ClientErrorCode::to_string`.

## Pagination

The JavaScript `for await` helpers collect into arrays here:

```moonbit nocheck
///|
let blocks = @notionsdk.collect_paginated_api(
  args => (client.blocks().children_list)(args),
  { "block_id": parent },
)
```

`collect_data_source_templates` and `collect_all_data_source_rows` are also
provided. The latter reproduces the created_time-window algorithm that walks
past the per-query result limit.

The response type guards from `helpers.ts` are available as well:
`is_full_page`, `is_full_block`, `is_full_database`, `is_full_data_source`,
`is_full_user`, `is_full_comment`, `is_full_view`,
`is_full_page_or_data_source`.

`extract_notion_id`, `extract_page_id`, `extract_database_id` and
`extract_block_id` parse IDs out of URLs.

## Webhooks

```moonbit nocheck
///|
let ok = @notionsdk.verify_webhook_signature({
  body: raw_body,
  signature: Some(header_value),
  verification_token: token,
})
```

`sign_webhook_payload` produces the value Notion would send, so handlers can be
tested without a live subscription. HMAC-SHA256 is implemented in `sha256.mbt`
because MoonBit core ships no digest package.

## Retries and timeouts

The retry rules match the original: rate limits (`rate_limited`, 429) and
service overloads (`service_overload`, 529) are retried for every method; server
errors (`internal_server_error`, `service_unavailable`) only for idempotent
`get`/`delete` requests. Delays use the `retry-after` header in delta-seconds
form, otherwise exponential back-off with jitter. Configure with
`ClientOptions::new(retry=Some(false))`, `max_retries`, `initial_retry_delay_ms`
and `max_retry_delay_ms`.

`timeout_ms` is passed to the transport (a synchronous `Fetch` cannot be
interrupted from the outside). `sleep` and `random` are injectable so retry
behavior can be tested without real waiting or nondeterminism.

## Differences from the JavaScript SDK

- No HTTP stack is bundled; supply `fetch`.
- The transport is synchronous, so `timeout_ms` is a hint to the transport
  rather than a client-side timer.
- Server-sent events from `sessions().stream` are buffered and returned as an
  array instead of yielded as an async iterator.
- HTTP-date `retry-after` values are not parsed; delta-seconds are.
- Browser detection is an explicit `browser_environment` option rather than
  runtime sniffing, so the token guard stays testable.

## Tests

```sh
moon test
```

The suite covers request construction, retries, the browser token guard, path
traversal validation, error parsing, ID extraction, pagination, and SHA-256,
HMAC and webhook signatures against known vectors.
