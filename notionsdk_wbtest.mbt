// Whitebox tests run within the package scope and reach private helpers.

///|
test "sha256 known vectors" {
  assert_eq(
    bytes_to_hex(sha256_bytes(@utf8.encode("abc"))),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  assert_eq(
    bytes_to_hex(sha256_bytes(@utf8.encode(""))),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "hmac-sha256 known vector" {
  assert_eq(
    bytes_to_hex(
      hmac_sha256(
        @utf8.encode("key"),
        @utf8.encode("The quick brown fox jumps over the lazy dog"),
      ),
    ),
    "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
  )
}

///|
test "webhook signature verification" {
  let body = "{\"type\":\"page.created\"}"
  let token = "s3cret"
  let signature = sign_webhook_payload(body, token)
  assert_eq(
    verify_webhook_signature({
      body,
      signature: Some(signature),
      verification_token: token,
    }),
    true,
  )
  assert_eq(
    verify_webhook_signature({
      body,
      signature: Some(signature),
      verification_token: "other",
    }),
    false,
  )
  assert_eq(
    verify_webhook_signature({
      body: body + "x",
      signature: Some(signature),
      verification_token: token,
    }),
    false,
  )
  assert_eq(
    verify_webhook_signature({
      body,
      signature: None,
      verification_token: token,
    }),
    false,
  )
  assert_eq(
    verify_webhook_signature({
      body,
      signature: Some("deadbeef"),
      verification_token: token,
    }),
    false,
  )
}

///|
test "encode_uri_component matches encodeURIComponent" {
  assert_eq(encode_uri_component("a b/c"), "a%20b%2Fc")
  assert_eq(encode_uri_component("A-Z_a.z!~*'()"), "A-Z_a.z!~*'()")
  assert_eq(encode_uri_component("/"), "%2F")
}

///|
test "serialize_body drops a null start_cursor" {
  let body = Json::object(
    Map([("start_cursor", Json::null()), ("page_size", Json::number(10.0))]),
  )
  assert_eq(serialize_body(Some(body)), Some("{\"page_size\":10}"))
  let empty = Json::object(Map([("start_cursor", Json::null())]))
  assert_eq(serialize_body(Some(empty)), None)
  assert_eq(serialize_body(None), None)
}

///|
test "build_query_string skips nulls and repeats arrays" {
  let query = Json::object(
    Map([
      ("start_cursor", Json::null()),
      ("page_size", Json::number(5.0)),
      ("ids", Json::array([Json::string("a b"), Json::string("c")])),
    ]),
  )
  assert_eq(build_query_string(query), "page_size=5&ids=a%20b&ids=c")
}

///|
test "parse_retry_after_header reads delta seconds" {
  assert_eq(parse_retry_after_header([("retry-after", "2")]), Some(2000))
  assert_eq(parse_retry_after_header([("Retry-After", "0")]), Some(0))
  assert_eq(parse_retry_after_header([]), None)
  assert_eq(parse_retry_after_header([("retry-after", "soon")]), None)
}

///|
test "can_retry follows the idempotency rules" {
  let rate_limited = NotionError::new(
    kind=ApiResponseError,
    code="rate_limited",
    message="",
  )
  assert_eq(can_retry(rate_limited, "post"), true)
  let overload = NotionError::new(
    kind=ApiResponseError,
    code="service_overload",
    message="",
  )
  assert_eq(can_retry(overload, "post"), true)
  let internal = NotionError::new(
    kind=ApiResponseError,
    code="internal_server_error",
    message="",
  )
  assert_eq(can_retry(internal, "get"), true)
  assert_eq(can_retry(internal, "post"), false)
}

///|
test "sse frames split on blank lines" {
  let input = "event: stream.end\ndata: {\"type\":\"stream.end\"}\n\nevent: event.committed\ndata: {\"type\":\"event.committed\"}\n\npartial"
  let chunked = take_sse_frames(input, false)
  assert_eq(chunked.frames.length(), 2)
  assert_eq(chunked.remaining, "partial")
  let completed = take_sse_frames(chunked.remaining, true)
  assert_eq(completed.frames.length(), 0)
}

///|
test "parse_sse_frame reads event and data lines" {
  match parse_sse_frame("event: event.committed\ndata: line1\ndata: line2") {
    Some(frame) => {
      assert_eq(frame.event_name, "event.committed")
      assert_eq(frame.data, "line1\nline2")
    }
    None => abort("expected a frame")
  }
  assert_true(parse_sse_frame(": keep-alive") is None)
}

///|
test "parse_session_stream_event validates type against event name" {
  let frame : SseFrame = {
    event_name: "stream.end",
    data: "{\"type\":\"stream.end\"}",
  }
  let event = parse_session_stream_event(frame)
  assert_eq(object_fields(event).get("type"), Some(Json::string("stream.end")))
  let mismatch : SseFrame = {
    event_name: "stream.end",
    data: "{\"type\":\"event.committed\"}",
  }
  let result = try {
    let _ = parse_session_stream_event(mismatch)
    "no error"
  } catch {
    NotionClientError(e) => e.message
    _ => "other"
  }
  assert_eq(result, "Session stream event does not match its SSE event name.")
}
