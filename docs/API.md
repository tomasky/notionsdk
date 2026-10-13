# API Reference

Detailed reference for every method exposed by `kupas/notionsdk`. It mirrors the
JavaScript SDK's client, so the method names, HTTP verbs, paths and parameter
names are the same as `@notionhq/client`.

- [Getting started](#getting-started)
- [How calls work](#how-calls-work)
- [Endpoints by resource](#endpoints-by-resource)
  - [users](#users)
  - [pages](#pages)
  - [blocks](#blocks)
  - [databases](#databases)
  - [dataSources](#datasources)
  - [comments](#comments)
  - [fileUploads](#fileuploads)
  - [views](#views)
  - [search](#search)
  - [agents](#agents)
  - [sessions](#sessions)
  - [asyncTasks](#asynctasks)
  - [plugins / skills](#plugins--skills)
  - [oauth](#oauth)
- [Endpoints only in `api-endpoints`](#endpoints-only-in-api-endpoints)
- [Helpers](#helpers)
- [Errors](#errors)
- [Webhooks](#webhooks)
- [Logging and constants](#logging-and-constants)
- [Compatibility notes](#compatibility-notes)

## Getting started

The library never performs I/O on its own. You inject a `fetch` function and it
returns an [`HttpResponse`](../fetch_types.mbt):

```moonbit
///|
fn transport : @notionsdk.Fetch = (url, init) => {
  // Hand the request to your HTTP stack and wrap the result.
  @notionsdk.HttpResponse::from_text(
    status=200,
    headers=[("content-type", "application/json")],
    body="{\"object\":\"user\",\"id\":\"u1\"}",
  )
}

///|
let client = @notionsdk.Client::new(
  options=@notionsdk.ClientOptions::new(
    auth=Some("secret_..."),
    fetch=Some(transport),
  ),
)
```

`ClientOptions::new` takes:

| Option | Default | Purpose |
| --- | --- | --- |
| `auth` | `None` | Integration token sent as `Authorization: Bearer`. |
| `timeout_ms` | `60000` | Passed to the transport (a synchronous fetch can't be interrupted). |
| `base_url` | `https://api.notion.com` | Root the paths below are appended to. |
| `log_level` | `Warn` | Filter for the logger. |
| `logger` | console logger | Receives `(level, message, extra)`. |
| `notion_version` | `2025-09-03` | Value of the `Notion-Version` header. |
| `fetch` | HTTP client | Transport used to send requests. |
| `retry` | `None` | `Some(false)` disables retries entirely. |
| `max_retries` | `2` | Attempts after the first one. |
| `initial_retry_delay_ms` | `1000` | First back-off delay. |
| `max_retry_delay_ms` | `60000` | Back-off ceiling. |
| `dangerously_allow_browser` | `false` | Allow a token in a browser context. |
| `browser_environment` | `false` | Declare a browser context (guard input). |
| `sleep` | real sleep | Injectable delay function, for tests. |
| `random` | real RNG | Injectable `() -> Double` in `[0,1)`, for jitter. |

## How calls work

Every resource is a struct of functions bound to the client, so a call is
`(client.<resource>().<method>)(args)`:

```moonbit
let me = (client.users().me)({})
let page = (client.pages().create)({ "parent": { "page_id": parent_id } })
```

Rules that apply to every method:

1. **Arguments are a `Json` object.** Keys are the API parameter names; values
   are ordinary `Json`.
2. **Unknown keys are dropped and warned about.** Each endpoint declares its
   path/query/body/form keys; anything else is ignored and reported through the
   logger (`unknown parameters were ignored`).
3. **`null` query values are omitted**, so you can pass
   `"start_cursor": null` for "first page" without building a second object.
4. **Response is `Json`**, the decoded response body (or `Json::null()` for
   empty bodies). Missing required path parameters raise before any request.
5. **Per-request auth.** Passing `"auth": "<token>"` in the arguments uses that
   bearer token for this call only, overriding `ClientOptions.auth`.
6. **Errors raise `NotionClientError`**, see [Errors](#errors).

## Endpoints by resource

### users

Access via `client.users()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `me` | `GET` | `users/me` |
| `retrieve` | `GET` | `users/{user_id}` |
| `list` | `GET` | `users` |

- **`me(args)`** — returns the bot user that owns the token. Takes no
  parameters.
- **`retrieve({ "user_id": id })`** — fetch one user by ID.
- **`list({ "start_cursor": ..., "page_size": ... })`** — paginate workspace
  users. Both query parameters are optional.

```moonbit
let bot = (client.users().me)({})
let user = (client.users().retrieve)({ "user_id": user_id })
let page1 = (client.users().list)({ "page_size": 100 })
let next = @notionsdk.parse_paginated_list(page1).next_cursor
let page2 = (client.users().list)({ "start_cursor": next })
```

### pages

Access via `client.pages()`.

| Method | HTTP | Path | Notes |
| --- | --- | --- | --- |
| `create` | `POST` | `pages` | query `filter_properties` |
| `retrieve` | `GET` | `pages/{page_id}` | query `filter_properties` |
| `update` | `PATCH` | `pages/{page_id}` | query `filter_properties` |
| `move_page` | `POST` | `pages/{page_id}/move` | body `parent` |
| `retrieve_markdown` | `GET` | `pages/{page_id}/markdown` | query `include_transcript` |
| `update_markdown` | `PATCH` | `pages/{page_id}/markdown` | see below |
| `properties_retrieve` | `GET` | `pages/{page_id}/properties/{property_id}` | query `start_cursor`, `page_size` |

- **`create`** — body keys: `parent`, `properties`, `icon`, `cover`, `content`,
  `children`, `markdown`, `allow_async`, `template`, `position`.
- **`update`** — body keys: `archived`, `properties`, `icon`, `cover`,
  `is_locked`, `template`, `erase_content`, `in_trash`, `is_archived`.
- **`move_page`** — reparent a page; body `parent`.
- **`retrieve_markdown`/`update_markdown`** — read and edit a page as markdown.
  `update_markdown` takes `allow_async`, `type`, `insert_content`,
  `replace_content_range`, `update_content`, `replace_content`.
- **`properties_retrieve`** — value of one property, paginated for properties
  that hold a list (for example `relation` or `rollup`).

```moonbit
let created = (client.pages().create)({
  "parent": { "database_id": db_id },
  "properties": { "Name": { "title": [{ "text": { "content": "Hello" } }] } },
})
let page = (client.pages().retrieve)({ "page_id": id })
let updated = (client.pages().update)({
  "page_id": id,
  "properties": { "Status": { "select": { "name": "Done" } } },
})
let moved = (client.pages().move_page)({ "page_id": id, "parent": { "page_id": new_parent } })
let md = (client.pages().retrieve_markdown)({ "page_id": id })
let values = (client.pages().properties_retrieve)({
  "page_id": id,
  "property_id": "r%5B%5D",  // "r[]" style property IDs are percent-encoded
  "page_size": 50,
})
```

### blocks

Access via `client.blocks()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `retrieve` | `GET` | `blocks/{block_id}` |
| `update` | `PATCH` | `blocks/{block_id}` |
| `delete` | `DELETE` | `blocks/{block_id}` |
| `children_list` | `GET` | `blocks/{block_id}/children` |
| `children_append` | `PATCH` | `blocks/{block_id}/children` |
| `meeting_notes_create` | `POST` | `blocks/meeting_notes` |
| `meeting_notes_query` | `POST` | `blocks/meeting_notes/query` |

- **`update`** — accepts `archived`, `in_trash`, `type` and one block payload
  key from `paragraph`, `heading_1` … `heading_4`, `bulleted_list_item`,
  `numbered_list_item`, `quote`, `to_do`, `toggle`, `template`, `callout`,
  `synced_block`, `table`, `table_row`, `column`, `child_database`,
  `link_to_page`, `table_of_contents`, `breadcrumb`, `equation`, `code`,
  `file`, `image`, `video`, `pdf`, `audio`, `bookmark`, `embed`, `divider`,
  `tab`.
- **`children_list`** — query `start_cursor`, `page_size`.
- **`children_append`** — body `after`, `children`, `position`.
- **`meeting_notes_create`** — body `title`, `language`, `options`, `source`,
  `parent`.
- **`meeting_notes_query`** — body `filter`, `sort`, `limit`.

```moonbit
let block = (client.blocks().retrieve)({ "block_id": block_id })
let kids = (client.blocks().children_list)({ "block_id": block_id, "page_size": 100 })
let appended = (client.blocks().children_append)({
  "block_id": block_id,
  "children": [
    { "object": "block",
      "type": "paragraph",
      "paragraph": { "rich_text": [{ "type": "text", "text": { "content": "Hi" } }] } },
  ],
})
let deleted = (client.blocks().delete)({ "block_id": block_id })
```

### databases

Access via `client.databases()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `retrieve` | `GET` | `databases/{database_id}` |
| `update` | `PATCH` | `databases/{database_id}` |
| `create` | `POST` | `databases` |

- **`update`** — body `parent`, `title`, `description`, `is_inline`, `icon`,
  `cover`, `in_trash`, `is_locked`.
- **`create`** — body `parent`, `title`, `description`, `is_inline`,
  `initial_data_source`, `database_type`, `icon`, `cover`.

```moonbit
let db = (client.databases().retrieve)({ "database_id": db_id })
let created = (client.databases().create)({
  "parent": { "page_id": parent_page },
  "title": [{ "text": { "content": "Tasks" } }],
  "initial_data_source": {
    "properties": { "Name": { "title": {} } },
  },
})
```

### dataSources

Access via `client.data_sources()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `retrieve` | `GET` | `data_sources/{data_source_id}` |
| `update` | `PATCH` | `data_sources/{data_source_id}` |
| `query` | `POST` | `data_sources/{data_source_id}/query` |
| `create` | `POST` | `data_sources` |
| `list_templates` | `GET` | `data_sources/{data_source_id}/templates` |

- **`update`** — body `archived`, `title`, `icon`, `properties`, `in_trash`,
  `parent`.
- **`query`** — query `filter_properties`; body `archived`, `sorts`, `filter`,
  `start_cursor`, `page_size`, `in_trash`, `result_type`.
- **`create`** — body `parent`, `properties`, `title`, `icon`.
- **`list_templates`** — query `name`, `start_cursor`, `page_size`.

```moonbit
let rows = (client.data_sources().query)({
  "data_source_id": ds_id,
  "filter": { "property": "Done", "checkbox": { "equals": false } },
  "sorts": [{ "property": "Created", "direction": "descending" }],
  "page_size": 100,
})
```

### comments

Access via `client.comments()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `create` | `POST` | `comments` |
| `list` | `GET` | `comments` |
| `retrieve` | `GET` | `comments/{comment_id}` |
| `update` | `PATCH` | `comments/{comment_id}` |
| `delete` | `DELETE` | `comments/{comment_id}` |

- **`create`** — body `parent`, `rich_text`, `markdown`, `attachments`,
  `display_name`, `discussion_id`.
- **`list`** — query `block_id`, `start_cursor`, `page_size`.
- **`update`** — body `rich_text`, `markdown`.

```moonbit
let comment = (client.comments().create)({
  "parent": { "page_id": page_id },
  "rich_text": [{ "text": { "content": "Looks good" } }],
})
let thread = (client.comments().list)({ "block_id": block_id })
let gone = (client.comments().delete)({ "comment_id": comment_id })
```

### fileUploads

Access via `client.file_uploads()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `create` | `POST` | `file_uploads` |
| `retrieve` | `GET` | `file_uploads/{file_upload_id}` |
| `list` | `GET` | `file_uploads` |
| `send` | `POST` | `file_uploads/{file_upload_id}/send` |
| `complete` | `POST` | `file_uploads/{file_upload_id}/complete` |

- **`create`** — body `mode`, `filename`, `content_type`, `number_of_parts`,
  `external_url`.
- **`list`** — query `status`, `start_cursor`, `page_size`.
- **`send`** — multipart form data: `file` (an object such as
  `{ "filename": ..., "data": ... }`) and `part_number`.

```moonbit
let upload = (client.file_uploads().create)({
  "mode": "single_part",
  "filename": "notes.txt",
  "content_type": "text/plain",
})
let id = ...  // the "id" field of `upload`
(client.file_uploads().send)({
  "file_upload_id": id,
  "file": { "filename": "notes.txt", "data": "hello" },
})
let done = (client.file_uploads().complete)({ "file_upload_id": id })
```

### views

Access via `client.views()`.

| Method | HTTP | Path | Body keys |
| --- | --- | --- | --- |
| `list` | `GET` | `views` | query `database_id`, `data_source_id`, `start_cursor`, `page_size` |
| `create` | `POST` | `views` | `data_source_id`, `name`, `type`, `database_id`, `view_id`, `filter`, `sorts`, `quick_filters`, `create_database`, `configuration`, `position`, `placement` |
| `retrieve` | `GET` | `views/{view_id}` | — |
| `update` | `PATCH` | `views/{view_id}` | `name`, `filter`, `sorts`, `quick_filters`, `configuration` |
| `delete` | `DELETE` | `views/{view_id}` | — |
| `queries_create` | `POST` | `views/{view_id}/queries` | `page_size` |
| `queries_results` | `GET` | `views/{view_id}/queries/{query_id}` | query `start_cursor`, `page_size` |
| `queries_delete` | `DELETE` | `views/{view_id}/queries/{query_id}` | — |

`create`, `update` and `queries_create` filter their own field lists, exactly
like the JavaScript client.

```moonbit
let views = (client.views().list)({ "database_id": db_id })
let query = (client.views().queries_create)({ "view_id": view_id, "page_size": 50 })
let query_id = ...  // the "id" field of `query`
let rows = (client.views().queries_results)({ "view_id": view_id, "query_id": query_id })
```

### search

Access via `client.search()`.

- **`search({ "query": ..., "filter": ..., "sort": ..., "start_cursor": ..., "page_size": ... })`**
  — `POST search`. Filter by `object` (`page` or `data_source`).

```moonbit
let results = (client.search().search)({ "query": "roadmap", "page_size": 25 })
let pages_only = (client.search().search)({ "filter": { "value": "page", "property": "object" } })
```

### agents

Access via `client.agents()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `query` | `POST` | `agents/query` |
| `retrieve` | `GET` | `agents/{agent_id}` (query `verbose`) |
| `delete` | `DELETE` | `agents/{agent_id}` |
| `retrieve_insights` | `GET` | `agents/{agent_id}/insights` (query `start_time`, `end_time`) |
| `update_status` | `PATCH` | `agents/{agent_id}/status` (body `status`) |
| `update_credit_limit` | `PATCH` | `agents/{agent_id}/credit_limit` (body `credit_limit`) |
| `batch` | `POST` | `agents/batch` (body `operations`) |

`query` body keys: `query`, `filter`, `sorts`, `start_cursor`, `page_size`,
`verbose`, `include_deleted`.

```moonbit
let agents = (client.agents().query)({ "query": "support", "page_size": 20 })
let agent = (client.agents().retrieve)({ "agent_id": agent_id, "verbose": true })
let insights = (client.agents().retrieve_insights)({
  "agent_id": agent_id,
  "start_time": "2025-01-01T00:00:00Z",
  "end_time": "2025-02-01T00:00:00Z",
})
(client.agents().update_status)({ "agent_id": agent_id, "status": "paused" })
```

### sessions

Access via `client.sessions()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `retrieve` | `GET` | `sessions/{session_id}` |
| `update` | `POST` | `sessions` |
| `stream` | `POST` | `sessions` (SSE) |
| `cancel` | `POST` | `sessions/{session_id}/cancel` (body `event_id`) |
| `query` | `POST` | `sessions/query` |
| `query_events` | `POST` | `sessions/{session_id}/events/query` |

`update` body keys: `message`, `agent_id`, `session_id`, `attachments`,
`metadata`, `prompt_context`, `actions`, `continue_from`.
`query` body keys: `query`, `filter`, `sorts`, `start_cursor`, `page_size`.
`query_events` body keys: `filter`, `sorts`, `start_cursor`, `page_size`.

**`stream`** is the only method with a different return type: it sends
`Accept: text/event-stream` and returns `Array[Json]` — the parsed server-sent
events (message deltas, tool calls, completion). The synchronous transport
buffers the whole response, so this is not an incremental iterator.

```moonbit
let session = (client.sessions().retrieve)({ "session_id": session_id })
let events = (client.sessions().stream)({
  "message": "Summarize the last sprint",
  "agent_id": agent_id,
})
for event in events {
  println(event.stringify())
}
```

### asyncTasks

Access via `client.async_tasks()`.

- **`retrieve({ "task_id": id })`** — `GET async_tasks/{task_id}`. Polls the
  task created by an async request (`allow_async: true`).

### plugins / skills

Access via `client.plugins()` and `client.skills()`.

| Method | HTTP | Path |
| --- | --- | --- |
| `plugins.list` | `GET` | `ai/plugins` (query `page_size`, `start_cursor`) |
| `plugins.retrieve` | `GET` | `ai/plugins/{id}` |
| `skills.retrieve` | `GET` | `ai/skills/{id}` |

Plugin IDs can be tag IDs containing URL delimiters, so `plugins.retrieve`
percent-encodes its `id` argument before building the path.

```moonbit
let plugins = (client.plugins().list)({ "page_size": 10 })
let plugin = (client.plugins().retrieve)({ "id": plugin_id })
```

### oauth

Access via `client.oauth()`. These endpoints authenticate with HTTP Basic
(`client_id`/`client_secret` in the arguments) instead of a bearer token.

| Method | HTTP | Path | Body keys |
| --- | --- | --- | --- |
| `token` | `POST` | `oauth/token` | `grant_type`, `code`, `redirect_uri`, `external_account`, `refresh_token` |
| `introspect` | `POST` | `oauth/introspect` | `token` |
| `revoke` | `POST` | `oauth/revoke` | `token` |

```moonbit
let token = (client.oauth().token)({
  "client_id": client_id,
  "client_secret": client_secret,
  "grant_type": "authorization_code",
  "code": code,
  "redirect_uri": redirect_uri,
})
```

## Endpoints only in `api-endpoints`

A few endpoint definitions exist in `api-endpoints/` without a bound client
method, matching the JavaScript SDK where they are likewise not part of
`api-endpoint-methods`. Use them through `Client::request` if you need them:

| Definition | HTTP | Path |
| --- | --- | --- |
| `listCustomEmojis` | `GET` | `custom_emojis` (query `name`, `start_cursor`, `page_size`) |
| `listAgents` | `GET` | `agents` |
| `chatWithAgent` | `POST` | `agents/{agent_id}/chat` |
| `continueThread` | `POST` | `threads/{thread_id}/continue` |
| `listThreads` | `GET` | `agents/{agent_id}/threads` |
| `queryThreads` | `POST` | `agents/{agent_id}/threads/query` |
| `listThreadMessages` | `GET` | `threads/{thread_id}/messages` |
| `sendThreadMessage` | `POST` | `threads/{thread_id}/messages` |
| `queryThreadMessages` | `POST` | `threads/{thread_id}/messages/query` |
| `startExternalAgentStubSession` | `POST` | `external_agent_stub/{agent_id}/sessions` |
| `sendExternalAgentStubSessionMessage` | `POST` | `external_agent_stub/{agent_id}/sessions/{session_id}/messages` |
| `listExternalAgentStubSessionEvents` | `GET` | `external_agent_stub/{agent_id}/sessions/{session_id}/events` |
| `createExternalAgentStubVault` | `POST` | `external_agent_stub/{agent_id}/vaults` |
| `updateExternalAgentStubVault` | `PATCH` | `external_agent_stub/{agent_id}/vaults/{vault_id}` |
| `deleteExternalAgentStubVault` | `DELETE` | `external_agent_stub/{agent_id}/vaults/{vault_id}` |
| `updateSessionStream` | `POST` | `sessions` (SSE variant, used by `sessions().stream`) |

## Helpers

### Pagination

The JavaScript `for await` iterators become collectors:

```moonbit
let all_users = @notionsdk.collect_paginated_api(
  args => (client.users().list)(args),
  {},  // starting arguments
)
```

- `collect_paginated_api(call, args)` — drain a `start_cursor`/`next_cursor`
  list endpoint into one array. `iterate_paginated_api` is an alias, kept for
  callers porting `iteratePaginatedAPI`.
- `collect_data_source_templates(call, args)` / `iterate_data_source_templates`
  — the same for templates.
- `collect_all_data_source_rows(call, args)` / `iterate_all_data_source_rows`
  — reproduces the `collectAllDataSourceRows` algorithm: it pages a query
  endpoint while narrowing the `created_time` window until the data source is
  exhausted, working around the per-query result cap.
- `parse_paginated_list(response)` returns a `PaginatedList` with `results`,
  `next_cursor` and `has_more`; `set_start_cursor(args, cursor)` returns a copy
  of the arguments with `start_cursor` set (or removed when `None`).

### Response type guards

`is_full_page`, `is_full_block`, `is_full_database`, `is_full_data_source`,
`is_full_user`, `is_full_comment`, `is_full_view`,
`is_full_page_or_data_source`, plus the rich-text item guards
`is_text_rich_text_item_response`, `is_equation_rich_text_item_response` and
`is_mention_rich_text_item_response`. Each returns `Bool` and checks the
`object` (`type` for rich text) field, mirroring the TypeScript guards.

### ID extraction

`extract_notion_id`, `extract_page_id`, `extract_database_id`,
`extract_block_id` pull IDs out of Notion URLs, for example
`https://www.notion.so/My-Page-668d797c76fa49349b05ad288df2d136` →
`668d797c76fa49349b05ad288df2d136`.

## Errors

All failures raise `NotionClientError(NotionError)`. The error carries the same
fields as the JavaScript SDK:

| Field | Description |
| --- | --- |
| `code` | `APIErrorCode` / `ClientErrorCode` string. |
| `message` | Human-readable message. |
| `status` | HTTP status, when there was a response. |
| `headers` | Response headers. |
| `body` | Raw response body. |
| `additional_data` | Extra details from the API error body. |
| `request_id` / `ray_id` | Notion request identifiers, useful in support tickets. |

```moonbit
let result = try {
  (client.databases().retrieve)({ "database_id": id })
} catch {
  @notionsdk.NotionClientError(error) =>
    if error.code == "object_not_found" {
      @notionsdk.Json::null()
    } else {
      raise error
    }
  _ => @notionsdk.Json::null()
}
```

Predicates and enums: `is_notion_client_error`, `is_http_response_error`,
`is_api_response_error`, `APIErrorCode::from_string`, `ClientErrorCode::to_string`.
Client-side codes include `invalid_request_url`, `invalid_request_error`,
`validation_error`, `missing_version`, `rate_limited`, `unauthorized`,
`restricted_resource`, `notion_client_error`, `object_not_found`,
`conflict_error`, `internal_server_error`, `service_unavailable`,
`service_overload`, and `browser_token_not_allowed`.

### Retries

Rate limits (`rate_limited`, HTTP 429) and overloads (`service_overload`,
HTTP 529) are retried for every method; `internal_server_error` (500) and
`service_unavailable` (503) only for idempotent `get`/`delete` calls. The delay
is `retry-after` in delta-seconds when present, otherwise exponential back-off
with jitter. `timeout_ms` and network failures are retried too. Disable with
`retry=Some(false)`.

## Webhooks

```moonbit
let valid = @notionsdk.verify_webhook_signature({
  body: raw_request_body,
  signature: request_header("X-Notion-Signature"),
  verification_token: subscription_token,
})
```

- `verify_webhook_signature` returns `Bool`, using a constant-time comparison.
- `sign_webhook_payload(body, verification_token)` returns the `sha256=...`
  value Notion would send, so tests don't need a live subscription.

SHA-256 and HMAC-SHA256 are implemented in `sha256.mbt` (`sha256`,
`hmac_sha256`, `bytes_to_hex`) because MoonBit core ships no digest package.

## Logging and constants

- `LogLevel` — `Debug`, `Info`, `Warn`, `Error`.
- `Logger` — `(LogLevel, String, Json) -> Unit`; `make_console_logger(name)`
  builds the default console logger, `LogLevel::to_string`/`from_string`
  convert levels, and `log_level_severity(level)` maps a level to its numeric
  severity for filtering.
- `constants.mbt` holds `default_base_url`, `default_timeout_ms`,
  `default_max_retries`, `default_initial_retry_delay_ms`,
  `default_max_retry_delay_ms`, and the default `Notion-Version`.
- `notionsdk.mbt` exports `sdk_version`.
- `utils.mbt` has `is_object`, `pick`, `get_unknown_params` if you are
  building your own endpoint layer.

## Compatibility notes

- Transport is injected; there is no bundled HTTP client.
- Transport is synchronous, so `timeout_ms` is a hint to the transport rather
  than a client-side timer, and `sessions().stream` returns a buffered array.
- Payloads are `Json`, not generated per-endpoint TypeScript types.
- HTTP-date `Retry-After` values are not parsed (delta-seconds are).
- Browser detection is the explicit `browser_environment` option, so the token
  guard can be tested.
