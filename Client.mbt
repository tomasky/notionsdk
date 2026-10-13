///|
/// The Notion API client, ported from `src/Client.ts`.
///
/// The client owns request construction (URL, headers, body), authentication,
/// logging, retries and SSE parsing. It is transport-agnostic: supply a `fetch`
/// function in `ClientOptions` to connect an HTTP stack.

///|
/// Options for configuring a `Client`.
pub(all) struct ClientOptions {
  /// Public API integration token, used when a request does not pass `auth`.
  auth : String?
  /// Request timeout handed to the transport, in milliseconds.
  timeout_ms : Int
  /// Base URL of the API, without the `/v1/` suffix.
  base_url : String
  /// Minimum severity a message must have to be logged.
  log_level : LogLevel
  /// Sink for log messages; defaults to a console logger.
  logger : Logger?
  /// Value of the `Notion-Version` header.
  notion_version : String
  /// Transport. The SDK bundles no HTTP stack, so pass one to make requests.
  fetch : Fetch?
  /// `Some(false)` disables automatic retries entirely.
  retry : Bool?
  /// Maximum number of retry attempts.
  max_retries : Int
  /// Initial delay between retries in milliseconds.
  initial_retry_delay_ms : Int
  /// Maximum delay between retries in milliseconds.
  max_retry_delay_ms : Int
  /// Allow sending a token from a browser-like environment.
  dangerously_allow_browser : Bool
  /// Whether the client considers itself to be running in a browser. The
  /// TypeScript SDK sniffs `globalThis`; here it is an explicit option so the
  /// token guard remains testable.
  browser_environment : Bool
  /// Sleep function used between retries. Defaults to a no-op so retries can be
  /// tested without real delays.
  sleep : ((Int) -> Unit)?
  /// Source of jitter for retry back-off. Defaults to the core RNG.
  random : (() -> Double)?
}

///|
/// Builds `ClientOptions`, applying the SDK defaults.
pub fn ClientOptions::new(
  auth? : String? = None,
  timeout_ms? : Int = default_timeout_ms,
  base_url? : String = default_base_url,
  log_level? : LogLevel = Warn,
  logger? : Logger? = None,
  notion_version? : String = "2025-09-03",
  fetch? : Fetch? = None,
  retry? : Bool? = None,
  max_retries? : Int = default_max_retries,
  initial_retry_delay_ms? : Int = default_initial_retry_delay_ms,
  max_retry_delay_ms? : Int = default_max_retry_delay_ms,
  dangerously_allow_browser? : Bool = false,
  browser_environment? : Bool = false,
  sleep? : ((Int) -> Unit)? = None,
  random? : (() -> Double)? = None,
) -> ClientOptions {
  {
    auth,
    timeout_ms,
    base_url,
    log_level,
    logger,
    notion_version,
    fetch,
    retry,
    max_retries,
    initial_retry_delay_ms,
    max_retry_delay_ms,
    dangerously_allow_browser,
    browser_environment,
    sleep,
    random,
  }
}

///|
/// Authentication for a single request.
pub(all) enum RequestAuth {
  /// Bearer token (`auth` passed as a string in the TypeScript SDK).
  Bearer(String)
  /// OAuth client credentials (`auth` passed as an object).
  Basic(client_id~ : String, client_secret~ : String)
}

///|
/// A request to send.
pub(all) struct RequestParameters {
  path : String
  http_method : String
  query : Json?
  body : Json?
  form_data_params : Json?
  headers : Array[(String, String)]
  auth : RequestAuth?
}

///|
/// Builds `RequestParameters`.
pub fn RequestParameters::new(
  path~ : String,
  http_method~ : String,
  query? : Json? = None,
  body? : Json? = None,
  form_data_params? : Json? = None,
  headers? : Array[(String, String)] = [],
  auth? : RequestAuth? = None,
) -> RequestParameters {
  { path, http_method, query, body, form_data_params, headers, auth, }
}

///|
/// A parsed server-sent event frame.
pub(all) struct SseFrame {
  event_name : String
  data : String
}

///|
/// The result of consuming an SSE buffer.
pub(all) struct SseFrames {
  frames : Array[SseFrame]
  remaining : String
}

///|
/// The Notion API client.
pub struct Client {
  priv auth : String?
  priv log_level : LogLevel
  priv logger : Logger
  priv prefix_url : String
  priv timeout_ms : Int
  priv notion_version : String
  priv fetch : Fetch
  priv user_agent : String
  priv max_retries : Int
  priv initial_retry_delay_ms : Int
  priv max_retry_delay_ms : Int
  priv dangerously_allow_browser : Bool
  priv browser_environment : Bool
  priv sleep : (Int) -> Unit
  priv random : () -> Double
}

///|
/// The `Notion-Version` a client uses when none is configured.
pub let default_notion_version : String = "2025-09-03"

///|
/// Creates a client.
pub fn Client::new(options? : ClientOptions = ClientOptions::new()) -> Client {
  let retry_disabled = options.retry is Some(false)
  let rand = match options.random {
    Some(r) => r
    None => {
      let rng = @random.Rand::new()
      () => rng.double()
    }
  }
  {
    auth: options.auth,
    log_level: options.log_level,
    logger: match options.logger {
      Some(l) => l
      None => make_console_logger("notionhq-client")
    },
    prefix_url: options.base_url + "/v1/",
    timeout_ms: options.timeout_ms,
    notion_version: options.notion_version,
    fetch: match options.fetch {
      Some(f) => f
      None => default_fetch
    },
    user_agent: "notionhq-client/5.27.0",
    max_retries: if retry_disabled {
      0
    } else {
      options.max_retries
    },
    initial_retry_delay_ms: if retry_disabled {
      0
    } else {
      options.initial_retry_delay_ms
    },
    max_retry_delay_ms: if retry_disabled {
      0
    } else {
      options.max_retry_delay_ms
    },
    dangerously_allow_browser: options.dangerously_allow_browser,
    browser_environment: options.browser_environment,
    sleep: match options.sleep {
      Some(s) => s
      None => _ms => ()
    },
    random: rand,
  }
}

///|
/// Sends a request and returns the parsed JSON response body.
pub fn Client::request(self : Client, args : RequestParameters) -> Json raise {
  let { path, http_method, query, body, form_data_params, auth, headers, } = args
  // The TypeScript client rejects a configured token at construction time when
  // it detects a browser. Detection is an explicit option here, so the same
  // guard is applied before the first request leaves.
  if self.auth is Some(_) {
    self.assert_token_allowed_here()
  }
  validate_request_path(path)
  self.log(
    Info,
    "request start",
    Json::object(
      Map([
        ("http_method", Json::string(http_method)),
        ("path", Json::string(path)),
      ]),
    ),
  )
  let url = self.build_request_url(path, query)
  let body_as_json_string = serialize_body(body)
  let base_headers = self.build_request_headers(
    headers, auth, body_as_json_string,
  )
  let (request_headers, request_body) = match form_data_params {
    Some(params) =>
      match params {
        Json::Object(fields) if !fields.is_empty() =>
          build_multipart_form_data(params, base_headers, self.random)
        _ => (base_headers, body_as_json_string)
      }
    None => (base_headers, body_as_json_string)
  }
  self.execute_with_retry(url, path, http_method, request_headers, request_body)
}

///|
/// Opens an SSE response and returns each parsed event.
///
/// The TypeScript client streams frames as they arrive. This port reads the
/// transport's full body first and then splits it, which is equivalent for the
/// events the sessions stream delivers.
pub fn Client::stream_request(
  self : Client,
  args : RequestParameters,
  parse_event : (SseFrame) -> Json raise,
) -> Array[Json] raise {
  let { path, http_method, query, body, auth, headers, .. } = args
  validate_request_path(path)
  self.log(
    Info,
    "stream request start",
    Json::object(
      Map([
        ("http_method", Json::string(http_method)),
        ("path", Json::string(path)),
      ]),
    ),
  )
  let url = self.build_request_url(path, query)
  let body_as_json_string = serialize_body(body)
  let request_headers = self.build_request_headers(
    headers, auth, body_as_json_string,
  )
  let response = self.execute_with_retry_raw(
    url, http_method, request_headers, body_as_json_string,
  )
  self.log(
    Info,
    "stream request opened",
    Json::object(
      Map([
        ("http_method", Json::string(http_method)),
        ("path", Json::string(path)),
      ]),
    ),
  )
  let frames = take_sse_frames((response.text)(), true).frames
  let events : Array[Json] = []
  for frame in frames {
    events.push(parse_event(frame))
  }
  events
}

// ---------------------------------------------------------------------------
// Request construction
// ---------------------------------------------------------------------------

///|
/// Builds the full URL with query parameters.
fn Client::build_request_url(
  self : Client,
  path : String,
  query : Json?,
) -> String {
  let url = self.prefix_url + path
  let query_string = match query {
    Some(q) => build_query_string(q)
    None => ""
  }
  if query_string.is_empty() {
    url
  } else {
    url + "?" + query_string
  }
}

///|
/// Serializes the request body to a JSON string if non-empty.
fn serialize_body(body : Json?) -> String? {
  match body {
    None => None
    Some(Json::Object(fields)) => {
      let serialized : Map[String, Json] = Map([])
      fields.each((key, value) => {
        if key == "start_cursor" && value is Json::Null {
          ()
        } else {
          serialized.set(key, value)
        }
      })
      if serialized.is_empty() {
        None
      } else {
        Some(Json::object(serialized).stringify())
      }
    }
    Some(value) => Some(value.stringify())
  }
}

///|
/// Builds the request headers including auth and content-type.
fn Client::build_request_headers(
  self : Client,
  custom_headers : Array[(String, String)],
  auth : RequestAuth?,
  body_as_json_string : String?,
) -> Array[(String, String)] raise {
  let headers : Array[(String, String)] = []
  for pair in custom_headers {
    headers.push(pair)
  }
  for pair in self.build_auth_header(auth) {
    set_header(headers, pair.0, pair.1)
  }
  set_header(headers, "Notion-Version", self.notion_version)
  // Firefox and Safari send a custom user-agent, which the API's CORS preflight
  // does not allow, so browser requests omit it.
  if !self.browser_environment {
    set_header(headers, "user-agent", self.user_agent)
  }
  match body_as_json_string {
    Some(_) => set_header(headers, "content-type", "application/json")
    None => ()
  }
  headers
}

///|
/// Builds the authorization header based on the auth type.
fn Client::build_auth_header(
  self : Client,
  auth : RequestAuth?,
) -> Array[(String, String)] raise {
  match auth {
    None => self.auth_as_headers(None)
    Some(a) => {
      self.assert_token_allowed_here()
      match a {
        Bearer(token) => self.auth_as_headers(Some(token))
        Basic(client_id~, client_secret~) => {
          let credential = client_id + ":" + client_secret
          let encoded = @base64.encode(@utf8.encode(credential))
          [("authorization", "Basic " + encoded)]
        }
      }
    }
  }
}

///|
/// Turns an API key or access token into a headers array, falling back to the
/// client's configured token.
fn Client::auth_as_headers(
  self : Client,
  auth : String?,
) -> Array[(String, String)] {
  let value = match auth {
    Some(a) => Some(a)
    None => self.auth
  }
  match value {
    Some(token) => [("authorization", "Bearer " + token)]
    None => []
  }
}

///|
/// Replaces or appends a header (case-insensitive on the name).
fn set_header(
  headers : Array[(String, String)],
  name : String,
  value : String,
) -> Unit {
  let lower = name.to_lower()
  let mut found = false
  for i = 0; i < headers.length(); i = i + 1 {
    if headers[i].0.to_lower() == lower {
      headers[i] = (name, value)
      found = true
    }
  }
  if !found {
    headers.push((name, value))
  }
}

///|
/// Serializes a JSON object into a query string, skipping null values the same
/// way the TypeScript client's `URLSearchParams` loop does.
fn build_query_string(query : Json) -> String {
  match query {
    Json::Object(fields) => {
      let parts : Array[String] = []
      fields.each((key, value) => {
        match value {
          Json::Null => ()
          Json::Array(items) =>
            for item in items {
              parts.push(
                encode_uri_component(key) +
                "=" +
                encode_uri_component(scalar_to_string(item)),
              )
            }
          other =>
            parts.push(
              encode_uri_component(key) +
              "=" +
              encode_uri_component(scalar_to_string(other)),
            )
        }
      })
      parts.join("&")
    }
    _ => ""
  }
}

///|
/// Renders a scalar JSON value as the string a query parameter would carry.
fn scalar_to_string(value : Json) -> String {
  match value {
    Json::String(s) => s
    Json::Number(d, ..) => @endpoints.number_to_string(d)
    Json::True => "true"
    Json::False => "false"
    Json::Null => ""
    other => other.stringify()
  }
}

///|
/// Builds the request body and headers for a multipart/form-data request.
fn build_multipart_form_data(
  params : Json,
  headers : Array[(String, String)],
  random : () -> Double,
) -> (Array[(String, String)], String?) {
  let boundary = "----MoonBitNotionBoundary" +
    (random() * 1000000000.0).to_int().to_string()
  let out : StringBuilder = StringBuilder()
  match params {
    Json::Object(fields) =>
      fields.each((key, value) => {
        match value {
          Json::String(text) => {
            out.write_string("--" + boundary + "\r\n")
            out.write_string(
              "Content-Disposition: form-data; name=\"" + key + "\"\r\n\r\n",
            )
            out.write_string(text)
            out.write_string("\r\n")
          }
          Json::Object(parts) => {
            let filename = match parts.get("filename") {
              Some(Json::String(name)) => name
              _ => "file"
            }
            let data = match parts.get("data") {
              Some(Json::String(text)) => text
              Some(other) => other.stringify()
              None => ""
            }
            out.write_string("--" + boundary + "\r\n")
            out.write_string(
              "Content-Disposition: form-data; name=\"" +
              key +
              "\"; filename=\"" +
              filename +
              "\"\r\n",
            )
            out.write_string("Content-Type: application/octet-stream\r\n\r\n")
            out.write_string(data)
            out.write_string("\r\n")
          }
          Json::Number(d, ..) => {
            out.write_string("--" + boundary + "\r\n")
            out.write_string(
              "Content-Disposition: form-data; name=\"" + key + "\"\r\n\r\n",
            )
            out.write_string(@endpoints.number_to_string(d))
            out.write_string("\r\n")
          }
          _ => ()
        }
      })
    _ => ()
  }
  out.write_string("--" + boundary + "--\r\n")
  set_header(
    headers,
    "content-type",
    "multipart/form-data; boundary=" + boundary,
  )
  (headers, Some(out.to_string()))
}

///|
/// Percent-encodes a string the way `encodeURIComponent` does.
pub fn encode_uri_component(value : String) -> String {
  let bytes = @utf8.encode(value)
  let parts : Array[String] = []
  for byte in bytes {
    let code = byte.to_int()
    if is_unreserved(code) {
      parts.push(String::make(1, byte_to_char(code)))
    } else {
      parts.push("%" + hex_byte(byte))
    }
  }
  parts.join("")
}

///|
/// Whether a byte is an `encodeURIComponent` unreserved character.
fn is_unreserved(code : Int) -> Bool {
  (code >= 65 && code <= 90) || // A-Z
  (code >= 97 && code <= 122) || // a-z
  (code >= 48 && code <= 57) || // 0-9
  code == 45 || // -
  code == 95 || // _
  code == 46 || // .
  code == 33 || // !
  code == 126 || // ~
  code == 42 || // *
  code == 39 || // '
  code == 40 || // (
  code == 41 // )
}

///|
/// Converts an ASCII byte code to a character.
fn byte_to_char(code : Int) -> Char {
  code.unsafe_to_char()
}

///|
/// Renders a byte as two lower-case hex digits.
fn hex_byte(byte : Byte) -> String {
  let digits = "0123456789ABCDEF"
  let value = byte.to_int()
  let hi = value / 16
  let lo = value % 16
  digits[hi:hi + 1].to_owned() + digits[lo:lo + 1].to_owned()
}

// ---------------------------------------------------------------------------
// Execution, retries and logging
// ---------------------------------------------------------------------------

///|
/// Executes the request with retry logic.
fn Client::execute_with_retry(
  self : Client,
  url : String,
  path : String,
  http_method : String,
  headers : Array[(String, String)],
  body : String?,
) -> Json raise {
  let mut attempt = 0
  while true {
    try {
      return self.execute_single_request(url, path, http_method, headers, body)
    } catch {
      NotionClientError(e) => {
        self.log_request_error(e, attempt)
        if attempt < self.max_retries && can_retry(e, http_method) {
          let delay_ms = self.calculate_retry_delay(e, attempt)
          self.log(
            Info,
            "retrying request",
            Json::object(
              Map([
                ("http_method", Json::string(http_method)),
                ("path", Json::string(path)),
                ("attempt", Json::number((attempt + 1).to_double())),
                ("delayMs", Json::number(delay_ms.to_double())),
              ]),
            ),
          )
          (self.sleep)(delay_ms)
          attempt = attempt + 1
          continue
        } else {
          raise NotionClientError(e)
        }
      }
      other => raise other
    }
  } nobreak {
    Json::null()
  }
}

///|
/// Executes the request with retry logic, returning the raw response. Used by
/// the streaming path, which needs the response before reading its body.
fn Client::execute_with_retry_raw(
  self : Client,
  url : String,
  http_method : String,
  headers : Array[(String, String)],
  body : String?,
) -> HttpResponse raise {
  let mut attempt = 0
  while true {
    try {
      return self.execute_single_request_raw(url, http_method, headers, body)
    } catch {
      NotionClientError(e) => {
        self.log_request_error(e, attempt)
        if attempt < self.max_retries && can_retry(e, http_method) {
          let delay_ms = self.calculate_retry_delay(e, attempt)
          (self.sleep)(delay_ms)
          attempt = attempt + 1
          continue
        } else {
          raise NotionClientError(e)
        }
      }
      other => raise other
    }
  } nobreak {
    HttpResponse::from_text(status=0, headers=[], body="")
  }
}

///|
/// Executes a single HTTP request (no retry).
fn Client::execute_single_request(
  self : Client,
  url : String,
  path : String,
  http_method : String,
  headers : Array[(String, String)],
  body : String?,
) -> Json raise {
  let response = self.execute_single_request_raw(
    url, http_method, headers, body,
  )
  let response_text = (response.text)()
  let response_json : Json = @json.parse(response_text) catch {
    _ =>
      raise NotionClientError(
        unknown_http_response_error(
          status=response.status,
          headers=response.headers,
          body=response_text,
          message=Some("Failed to parse the Notion API response as JSON."),
        ),
      )
  }
  self.log(
    Info,
    "request success",
    Json::object(
      Map([
        ("http_method", Json::string(http_method)),
        ("path", Json::string(path)),
        ("requestId", json_request_id(response_json)),
      ]),
    ),
  )
  response_json
}

///|
/// Performs the transport call and turns non-ok responses into errors.
fn Client::execute_single_request_raw(
  self : Client,
  url : String,
  http_method : String,
  headers : Array[(String, String)],
  body : String?,
) -> HttpResponse raise {
  let response = (self.fetch)(url, {
    http_method: http_method.to_upper(),
    headers,
    body,
    timeout_ms: self.timeout_ms,
    agent: None,
  })
  if !response.ok {
    raise build_request_error(response, (response.text)())
  }
  response
}

///|
/// Logs a request error with the appropriate detail level.
fn Client::log_request_error(
  self : Client,
  error : NotionError,
  attempt : Int,
) -> Unit {
  self.log(
    Warn,
    "request fail",
    Json::object(
      Map([
        ("code", Json::string(error.code)),
        ("message", Json::string(error.message)),
        ("attempt", Json::number(attempt.to_double())),
        (
          "requestId",
          match error.request_id {
            Some(id) => Json::string(id)
            None => Json::null()
          },
        ),
      ]),
    ),
  )
  if error.kind is ApiResponseError || error.kind is UnknownHTTPResponseError {
    self.log(
      Debug,
      "failed response body",
      Json::object(Map([("body", Json::string(error.body))])),
    )
  }
}

///|
/// Extracts `request_id` from a response object if present.
fn json_request_id(obj : Json) -> Json {
  match obj {
    Json::Object(fields) =>
      match fields.get("request_id") {
        Some(Json::String(id)) => Json::string(id)
        _ => Json::null()
      }
    _ => Json::null()
  }
}

///|
/// Determines if an error can be retried based on its error code and method.
///
/// Rate limits (429) and service overloads (529) are always retryable since the
/// server explicitly asks us to retry. Server errors (500, 503) are only
/// retried for idempotent methods (GET, DELETE) to avoid duplicate side effects.
pub fn can_retry(error : NotionError, http_method : String) -> Bool {
  if !(error.kind is ApiResponseError) {
    return false
  }
  let code = error.code
  if code == "rate_limited" || code == "service_overload" {
    return true
  }
  let lower = http_method.to_lower()
  let is_idempotent = lower == "get" || lower == "delete"
  if is_idempotent {
    return code == "internal_server_error" || code == "service_unavailable"
  }
  false
}

///|
/// Calculates the delay before the next retry attempt.
fn Client::calculate_retry_delay(
  self : Client,
  error : NotionError,
  attempt : Int,
) -> Int {
  if error.kind is ApiResponseError {
    match parse_retry_after_header(error.headers) {
      Some(retry_after_ms) => return retry_after_ms.min(self.max_retry_delay_ms)
      None => ()
    }
  }
  let base_delay = self.initial_retry_delay_ms.to_double() *
    @math.pow(2.0, attempt.to_double())
  let jitter = (self.random)()
  (base_delay * jitter + base_delay / 2.0).to_int().min(self.max_retry_delay_ms)
}

///|
/// Parses the `retry-after` header value in delta-seconds form and returns the
/// delay in milliseconds. HTTP-date values are not supported by this port.
pub fn parse_retry_after_header(headers : Array[(String, String)]) -> Int? {
  match get_response_header(headers, "retry-after") {
    None => None
    Some(value) => {
      let seconds = @string.parse_int(value.trim()) catch { _ => -1 }
      if seconds >= 0 {
        Some(seconds * 1000)
      } else {
        None
      }
    }
  }
}

///|
/// Emits a log message if the level passes the client's threshold.
fn Client::log(
  self : Client,
  level : LogLevel,
  message : String,
  extra_info : Json,
) -> Unit {
  if log_level_severity(level) >= log_level_severity(self.log_level) {
    (self.logger)(level, message, extra_info)
  }
}

///|
/// Blocks a token or client secret inside a browser unless the caller opted in.
fn Client::assert_token_allowed_here(self : Client) -> Unit raise {
  if self.dangerously_allow_browser || !self.browser_environment {
    return
  }
  raise NotionClientError(browser_token_not_allowed_error())
}

// ---------------------------------------------------------------------------
// Server-sent events
// ---------------------------------------------------------------------------

///|
/// Event types the sessions stream can carry.
pub let session_stream_event_types : Array[String] = [
  "session.snapshot", "event.provisional", "event.committed", "stream.timeout", "stream.end",
  "stream.error",
]

///|
/// Splits an SSE buffer into complete frames, returning any trailing partial
/// frame so the caller can prepend it to the next chunk.
pub fn take_sse_frames(content : String, complete : Bool) -> SseFrames raise {
  let frames : Array[SseFrame] = []
  let mut remaining = content.replace_all(old="\r\n", new="\n")
  let mut boundary = remaining.find("\n\n")
  while boundary is Some(index) {
    match parse_sse_frame(remaining[:index].to_owned()) {
      Some(frame) => frames.push(frame)
      None => ()
    }
    remaining = remaining[index + 2:].to_owned()
    boundary = remaining.find("\n\n")
  }
  if complete && !remaining.is_empty() {
    match parse_sse_frame(remaining) {
      Some(frame) => frames.push(frame)
      None => ()
    }
    remaining = ""
  }
  { frames, remaining, }
}

///|
/// Parses a single SSE frame. Returns `None` for frames without a data field,
/// such as comments or keep-alives.
pub fn parse_sse_frame(content : String) -> SseFrame? raise {
  let mut event_name : String? = None
  let data_lines : Array[String] = []
  for line in content.split("\n") {
    if line.has_prefix(":") {
      continue
    }
    match line.find(":") {
      None => continue
      Some(colon_index) => {
        let field = line[:colon_index].to_owned()
        let value_start = if line[colon_index + 1:].has_prefix(" ") {
          colon_index + 2
        } else {
          colon_index + 1
        }
        let value = line[value_start:].to_owned()
        if field == "event" {
          event_name = Some(value)
        } else if field == "data" {
          data_lines.push(value)
        }
      }
    }
  }
  if data_lines.is_empty() {
    return None
  }
  match event_name {
    None =>
      raise NotionClientError(
        NotionError::new(
          kind=UnknownHTTPResponseError,
          code=ClientErrorCode::ResponseError.to_string(),
          message="Session stream event is missing its SSE event name.",
        ),
      )
    Some(name) => Some({ event_name: name, data: data_lines.join("\n"), })
  }
}

///|
/// Parses a session stream event and checks it against its SSE event name.
pub fn parse_session_stream_event(frame : SseFrame) -> Json raise {
  let event : Json = @json.parse(frame.data) catch {
    _ =>
      raise NotionClientError(
        NotionError::new(
          kind=UnknownHTTPResponseError,
          code=ClientErrorCode::ResponseError.to_string(),
          message="Session stream event body is not valid JSON.",
        ),
      )
  }
  let event_type = match event {
    Json::Object(fields) =>
      match fields.get("type") {
        Some(Json::String(t)) => t
        _ => ""
      }
    _ => ""
  }
  if !session_stream_event_types.contains(event_type) ||
    event_type != frame.event_name {
    raise NotionClientError(
      NotionError::new(
        kind=UnknownHTTPResponseError,
        code=ClientErrorCode::ResponseError.to_string(),
        message="Session stream event does not match its SSE event name.",
      ),
    )
  }
  event
}
