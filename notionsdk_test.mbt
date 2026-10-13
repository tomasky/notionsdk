// Blackbox tests run against the package's public API.

///|
/// Builds a client, binding the optional `options` label for readability in the
/// tests below.
fn make_client(options : @notionsdk.ClientOptions) -> @notionsdk.Client {
  @notionsdk.Client::new(options~)
}

///|
/// Builds a fake transport that records what the client sent and replies with a
/// fixed body.
fn recording_fetch(
  urls : Array[String],
  bodies : Array[String?],
  headers_seen : Array[Array[(String, String)]],
  status : Int,
  response_body : String,
) -> @notionsdk.Fetch {
  (url, init) => {
    urls.push(url)
    bodies.push(init.body)
    headers_seen.push(init.headers)
    @notionsdk.HttpResponse::from_text(status~, headers=[], body=response_body)
  }
}

///|
test "constants match the TypeScript SDK" {
  assert_eq(@notionsdk.default_base_url, "https://api.notion.com")
  assert_eq(@notionsdk.default_timeout_ms, 60000)
  assert_eq(@notionsdk.default_max_retries, 2)
  assert_eq(@notionsdk.default_initial_retry_delay_ms, 1000)
  assert_eq(@notionsdk.default_max_retry_delay_ms, 60000)
  assert_eq(@notionsdk.min_view_column_width, 32)
}

///|
test "request builds url, headers and body" {
  let urls : Array[String] = []
  let bodies : Array[String?] = []
  let headers_seen : Array[Array[(String, String)]] = []
  let client = make_client(
    @notionsdk.ClientOptions::new(
      auth=Some("secret-token"),
      log_level=@notionsdk.Error,
      fetch=Some(
        recording_fetch(
          urls, bodies, headers_seen, 200, "{\"object\":\"user\",\"id\":\"u1\"}",
        ),
      ),
    ),
  )
  let response = client.request(
    @notionsdk.RequestParameters::new(
      path="users/u1",
      http_method="get",
      query=Some({ "page_size": 10, "start_cursor": null, "ids": ["a b", "c"] }),
      body=Some({ "start_cursor": null, "name": "x" }),
    ),
  )
  assert_eq(urls[0].has_prefix("https://api.notion.com/v1/users/u1?"), true)
  assert_eq(urls[0].contains("page_size=10"), true)
  assert_eq(urls[0].contains("ids=a%20b"), true)
  assert_eq(urls[0].contains("ids=c"), true)
  assert_eq(urls[0].contains("start_cursor"), false)
  let headers = headers_seen[0]
  assert_eq(
    @notionsdk.get_response_header(headers, "authorization"),
    Some("Bearer secret-token"),
  )
  assert_eq(
    @notionsdk.get_response_header(headers, "Notion-Version"),
    Some("2025-09-03"),
  )
  assert_eq(bodies[0], Some("{\"name\":\"x\"}"))
  match response {
    Json::Object(fields) =>
      assert_eq(fields.get("id"), Some(Json::string("u1")))
    _ => abort("unreachable")
  }
}

///|
test "endpoint methods filter arguments and build the path" {
  let urls : Array[String] = []
  let bodies : Array[String?] = []
  let headers_seen : Array[Array[(String, String)]] = []
  let client = make_client(
    @notionsdk.ClientOptions::new(
      auth=Some("t"),
      log_level=@notionsdk.Error,
      fetch=Some(
        recording_fetch(urls, bodies, headers_seen, 200, "{\"ok\":true}"),
      ),
    ),
  )
  let _ = (client.users().retrieve)({ "user_id": "u1", "bogus": true })
  assert_eq(urls[0], "https://api.notion.com/v1/users/u1")
  let _ = (client.blocks().children_list)({ "block_id": "b1", "page_size": 5 })
  assert_eq(urls[1], "https://api.notion.com/v1/blocks/b1/children?page_size=5")
  let _ = (client.oauth().token)({
    "grant_type": "authorization_code",
    "code": "c",
    "client_id": "id",
    "client_secret": "secret",
  })
  let headers = headers_seen[2]
  assert_eq(
    @notionsdk.get_response_header(headers, "authorization"),
    Some("Basic aWQ6c2VjcmV0"),
  )
}

///|
test "plugins retrieve percent-encodes the id" {
  let urls : Array[String] = []
  let client = make_client(
    @notionsdk.ClientOptions::new(
      auth=Some("t"),
      log_level=@notionsdk.Error,
      fetch=Some(recording_fetch(urls, [], [], 200, "{}")),
    ),
  )
  let _ = (client.plugins().retrieve)({ "id": "a/b c" })
  assert_eq(urls[0], "https://api.notion.com/v1/ai/plugins/a%2Fb%20c")
}

///|
test "retries rate limited requests using the retry-after header" {
  let attempts : Array[Int] = []
  let sleeps : Array[Int] = []
  let fetch : @notionsdk.Fetch = (_url, _init) => {
    attempts.push(attempts.length())
    if attempts.length() == 1 {
      @notionsdk.HttpResponse::from_text(
        status=429,
        headers=[("content-type", "application/json"), ("retry-after", "1")],
        body="{\"object\":\"error\",\"status\":429,\"code\":\"rate_limited\",\"message\":\"rate limited\"}",
      )
    } else {
      @notionsdk.HttpResponse::from_text(
        status=200,
        headers=[],
        body="{\"ok\":true}",
      )
    }
  }
  let client = make_client(
    @notionsdk.ClientOptions::new(
      auth=Some("t"),
      log_level=@notionsdk.Error,
      fetch=Some(fetch),
      sleep=Some(ms => sleeps.push(ms)),
    ),
  )
  let _ = client.request(
    @notionsdk.RequestParameters::new(path="users/me", http_method="get"),
  )
  assert_eq(attempts.length(), 2)
  assert_eq(sleeps, [1000])
}

///|
test "non-idempotent server errors are not retried" {
  let attempts : Array[Int] = []
  let fetch : @notionsdk.Fetch = (_url, _init) => {
    attempts.push(attempts.length())
    @notionsdk.HttpResponse::from_text(
      status=500,
      headers=[("content-type", "application/json")],
      body="{\"object\":\"error\",\"status\":500,\"code\":\"internal_server_error\",\"message\":\"boom\"}",
    )
  }
  let client = make_client(
    @notionsdk.ClientOptions::new(
      auth=Some("t"),
      log_level=@notionsdk.Error,
      fetch=Some(fetch),
      sleep=Some(_ms => ()),
    ),
  )
  let result = try {
    let _ = client.request(
      @notionsdk.RequestParameters::new(path="pages", http_method="post"),
    )
    "no error"
  } catch {
    @notionsdk.NotionClientError(e) => e.name()
    _ => "other"
  }
  assert_eq(result, "APIResponseError")
  assert_eq(attempts.length(), 1)
}

///|
test "browser token guard blocks auth" {
  let client = make_client(
    @notionsdk.ClientOptions::new(
      auth=Some("secret"),
      browser_environment=true,
      log_level=@notionsdk.Error,
      fetch=Some(recording_fetch([], [], [], 200, "{}")),
    ),
  )
  let result = try {
    let _ = client.request(
      @notionsdk.RequestParameters::new(path="users/me", http_method="get"),
    )
    "no error"
  } catch {
    @notionsdk.NotionClientError(e) => e.name()
    _ => "other"
  }
  assert_eq(result, "BrowserTokenNotAllowedError")
}

///|
test "validate_request_path rejects traversal" {
  let result = try {
    @notionsdk.validate_request_path("blocks/../users")
    "no error"
  } catch {
    @notionsdk.NotionClientError(e) => e.name()
    _ => "other"
  }
  assert_eq(result, "InvalidPathParameterError")
  let encoded = try {
    @notionsdk.validate_request_path("blocks/%2e%2e/users")
    "no error"
  } catch {
    @notionsdk.NotionClientError(e) => e.name()
    _ => "other"
  }
  assert_eq(encoded, "InvalidPathParameterError")
}

///|
test "build_request_error parses api error bodies" {
  let response = @notionsdk.HttpResponse::from_text(
    status=404,
    headers=[("x-notion-request-id", "req-1")],
    body="",
  )
  let error = @notionsdk.build_request_error(
    response, "{\"object\":\"error\",\"status\":404,\"code\":\"object_not_found\",\"message\":\"not found\"}",
  )
  let @notionsdk.NotionClientError(e) = error
  assert_eq(e.name(), "APIResponseError")
}

///|
test "helpers extract notion ids" {
  assert_eq(
    @notionsdk.extract_page_id(
      "https://www.notion.so/My-Page-abc123def456789012345678901234ab",
    ),
    Some("abc123de-f456-7890-1234-5678901234ab"),
  )
  assert_eq(
    @notionsdk.extract_notion_id("abc123def456789012345678901234ab"),
    Some("abc123de-f456-7890-1234-5678901234ab"),
  )
  assert_eq(
    @notionsdk.extract_block_id(
      "https://notion.so/page#block-abc123def456789012345678901234ab",
    ),
    Some("abc123de-f456-7890-1234-5678901234ab"),
  )
  assert_eq(@notionsdk.extract_notion_id("not a notion url"), None)
}

///|
test "helpers identify full page objects" {
  let full : Json = {
    "object": "page",
    "id": "p",
    "url": "https://notion.so/p",
    "created_time": "2024-01-01T00:00:00.000Z",
  }
  let partial : Json = { "object": "page", "id": "p" }
  assert_eq(@notionsdk.is_full_page(full), true)
  assert_eq(@notionsdk.is_full_page(partial), false)
  assert_eq(@notionsdk.is_full_page_or_data_source(full), true)
}

///|
test "collect_paginated_api walks every page" {
  let pages : Array[Json] = [
    {
      "object": "list",
      "results": [{ "id": "a" }],
      "next_cursor": "c1",
      "has_more": true,
    },
    {
      "object": "list",
      "results": [{ "id": "b" }],
      "next_cursor": null,
      "has_more": false,
    },
  ]
  let calls : Array[Json] = []
  let list_fn : (Json) -> Json raise = args => {
    calls.push(args)
    pages[calls.length() - 1]
  }
  let results = @notionsdk.collect_paginated_api(list_fn, { "page_size": 1 })
  assert_eq(results.length(), 2)
  assert_eq(calls.length(), 2)
  assert_eq(
    @notionsdk.set_start_cursor(calls[1], None).stringify(),
    "{\"page_size\":1}",
  )
}
