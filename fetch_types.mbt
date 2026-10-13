///|
/// Transport types the client is written against.
///
/// This mirrors `src/fetch-types.ts` from notion-sdk-js. The client never calls
/// the network directly: it is handed a `Fetch` function, so the same logic can
/// run on top of Node's fetch, the browser, an edge runtime, or a fake in tests.
/// Keeping the surface minimal is what makes that compatibility possible.

///|
/// Options passed to a `Fetch` implementation.
pub(all) struct HttpRequestInit {
  /// HTTP method, already upper-cased for the transport.
  http_method : String
  /// Request headers as name/value pairs.
  headers : Array[(String, String)]
  /// Serialized request body, when the request has one.
  body : String?
  /// How long the transport may wait before failing the request.
  timeout_ms : Int
  /// Opaque agent label, ignored by transports that have no such concept.
  agent : String?
}

///|
/// The response shape the client reads.
///
/// `text` returns the response body. It is a function so a transport can defer
/// reading the body until the caller decides to.
pub(all) struct HttpResponse {
  /// Whether the request succeeded (`response.ok` in fetch).
  ok : Bool
  /// HTTP status code.
  status : Int
  /// Response headers as name/value pairs.
  headers : Array[(String, String)]
  /// Reads the response body as text.
  text : () -> String
}

///|
/// A `fetch`-compatible function.
///
/// The first argument is the absolute URL, the second the request options.
pub type Fetch = (String, HttpRequestInit) -> HttpResponse raise

///|
/// Builds an `HttpResponse` from an already-read body.
pub fn HttpResponse::from_text(
  status~ : Int,
  headers~ : Array[(String, String)],
  body~ : String,
) -> HttpResponse {
  let ok = status >= 200 && status < 300
  { ok, status, headers, text: () => body, }
}

///|
/// The default transport. It fails loudly because the MoonBit SDK does not
/// bundle an HTTP stack; pass `fetch` to `ClientOptions` to connect one.
pub fn default_fetch(
  _url : String,
  _init : HttpRequestInit,
) -> HttpResponse raise {
  raise NotionClientError(
    NotionError::new(
      kind=UnknownHTTPResponseError,
      code=ClientErrorCode::ResponseError.to_string(),
      message="No fetch implementation was provided. Pass `fetch` in ClientOptions " +
        "to connect an HTTP transport (for example one built on moonbitlang/async).",
    ),
  )
}
