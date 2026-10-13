///|
/// Error handling, ported from `src/errors.ts`.
///
/// Every failure the client throws is a `NotionClientError` wrapping a
/// `NotionError` record. The record keeps the same fields the TypeScript SDK
/// exposes: `code`, `message`, `status`, `headers`, `body`, `additional_data`,
/// `request_id` and `ray_id`.

///|
/// Error codes returned in responses from the API.
pub(all) enum APIErrorCode {
  Unauthorized
  RestrictedResource
  ObjectNotFound
  RateLimited
  InvalidJson
  InvalidRequestUrl
  InvalidRequest
  InvalidBeta
  ValidationError
  ConflictError
  InternalServerError
  ServiceOverload
  ServiceUnavailable
  GatewayTimeout
}

///|
/// The wire value of an API error code.
pub fn APIErrorCode::to_string(self : APIErrorCode) -> String {
  match self {
    Unauthorized => "unauthorized"
    RestrictedResource => "restricted_resource"
    ObjectNotFound => "object_not_found"
    RateLimited => "rate_limited"
    InvalidJson => "invalid_json"
    InvalidRequestUrl => "invalid_request_url"
    InvalidRequest => "invalid_request"
    InvalidBeta => "invalid_beta"
    ValidationError => "validation_error"
    ConflictError => "conflict_error"
    InternalServerError => "internal_server_error"
    ServiceOverload => "service_overload"
    ServiceUnavailable => "service_unavailable"
    GatewayTimeout => "gateway_timeout"
  }
}

///|
/// Parses an API error code from its wire value.
pub fn APIErrorCode::from_string(value : String) -> APIErrorCode? {
  match value {
    "unauthorized" => Some(Unauthorized)
    "restricted_resource" => Some(RestrictedResource)
    "object_not_found" => Some(ObjectNotFound)
    "rate_limited" => Some(RateLimited)
    "invalid_json" => Some(InvalidJson)
    "invalid_request_url" => Some(InvalidRequestUrl)
    "invalid_request" => Some(InvalidRequest)
    "invalid_beta" => Some(InvalidBeta)
    "validation_error" => Some(ValidationError)
    "conflict_error" => Some(ConflictError)
    "internal_server_error" => Some(InternalServerError)
    "service_overload" => Some(ServiceOverload)
    "service_unavailable" => Some(ServiceUnavailable)
    "gateway_timeout" => Some(GatewayTimeout)
    _ => None
  }
}

///|
/// Whether a string is a known API error code.
pub fn is_api_error_code(value : String) -> Bool {
  APIErrorCode::from_string(value) is Some(_)
}

///|
/// Error codes generated for client errors.
pub(all) enum ClientErrorCode {
  RequestTimeout
  ResponseError
  InvalidPathParameter
}

///|
/// The wire value of a client error code.
pub fn ClientErrorCode::to_string(self : ClientErrorCode) -> String {
  match self {
    RequestTimeout => "notionhq_client_request_timeout"
    ResponseError => "notionhq_client_response_error"
    InvalidPathParameter => "notionhq_client_invalid_path_parameter"
  }
}

///|
/// The kind of error, mirroring the TypeScript SDK's error classes.
pub(all) enum NotionErrorKind {
  RequestTimeoutError
  UnknownHTTPResponseError
  ApiResponseError
  InvalidPathParameterError
  BrowserTokenNotAllowedError
}

///|
/// The name of the error class a kind corresponds to.
pub fn NotionErrorKind::name(self : NotionErrorKind) -> String {
  match self {
    RequestTimeoutError => "RequestTimeoutError"
    UnknownHTTPResponseError => "UnknownHTTPResponseError"
    ApiResponseError => "APIResponseError"
    InvalidPathParameterError => "InvalidPathParameterError"
    BrowserTokenNotAllowedError => "BrowserTokenNotAllowedError"
  }
}

///|
/// The fields carried by every error the client raises.
pub(all) struct NotionError {
  kind : NotionErrorKind
  code : String
  message : String
  status : Int
  headers : Array[(String, String)]
  body : String
  additional_data : Json?
  request_id : String?
  ray_id : String?
}

///|
/// Builds a `NotionError`. `status`, `headers` and `body` default to the
/// values used by errors that never reached the API.
pub fn NotionError::new(
  kind~ : NotionErrorKind,
  code~ : String,
  message~ : String,
  status? : Int = 0,
  headers? : Array[(String, String)] = [],
  body? : String = "",
  additional_data? : Json? = None,
  request_id? : String? = None,
  ray_id? : String? = None,
) -> NotionError {
  {
    kind,
    code,
    message,
    status,
    headers,
    body,
    additional_data,
    request_id,
    ray_id,
  }
}

///|
/// The error class name, e.g. `"APIResponseError"`.
pub fn NotionError::name(self : NotionError) -> String {
  self.kind.name()
}

///|
/// Error thrown by the client if a request times out.
pub fn request_timeout_error(
  message? : String = "Request to Notion API has timed out",
) -> NotionError {
  NotionError::new(
    kind=RequestTimeoutError,
    code=ClientErrorCode::RequestTimeout.to_string(),
    message~,
  )
}

///|
/// Error thrown when a path parameter contains invalid characters such as path
/// traversal sequences (`..`) that could alter the intended API endpoint.
pub fn invalid_path_parameter_error(
  message? : String = "Path parameter contains invalid characters that could alter the request path",
) -> NotionError {
  NotionError::new(
    kind=InvalidPathParameterError,
    code=ClientErrorCode::InvalidPathParameter.to_string(),
    message~,
  )
}

///|
/// Error thrown when the client would send a token or client secret from a
/// browser page without `dangerouslyAllowBrowser: true`.
pub fn browser_token_not_allowed_error() -> NotionError {
  NotionError::new(
    kind=BrowserTokenNotAllowedError,
    code="browser_token_not_allowed",
    message="It looks like you're running in a browser. Using a Notion token here " +
      "is blocked by default: anyone who can load the page can read the token and " +
      "act as your connection. Keep the token on a server instead. If only you can " +
      "open this page and you accept the risk, pass `dangerouslyAllowBrowser: true` " +
      "to the Client.",
  )
}

///|
/// A response from the API indicating a problem.
pub fn api_response_error(
  code~ : APIErrorCode,
  message~ : String,
  status~ : Int,
  headers~ : Array[(String, String)],
  body~ : String,
  additional_data? : Json? = None,
  request_id? : String? = None,
) -> NotionError {
  NotionError::new(
    kind=ApiResponseError,
    code=code.to_string(),
    message~,
    status~,
    headers~,
    body~,
    additional_data~,
    request_id~,
    ray_id=get_response_header(headers, "cf-ray"),
  )
}

///|
/// Error thrown if an API call responds with an unknown error code, or does not
/// respond with a property-formatted error.
pub fn unknown_http_response_error(
  status~ : Int,
  headers~ : Array[(String, String)],
  body~ : String,
  message? : String? = None,
) -> NotionError {
  let ray_id = get_response_header(headers, "cf-ray")
  let request_id = get_response_header(headers, "x-notion-request-id")
  let message = match message {
    Some(m) => m
    None =>
      build_unknown_response_message(
        status~,
        content_type=get_response_header(headers, "content-type"),
        ray_id~,
        request_id~,
      )
  }
  NotionError::new(
    kind=UnknownHTTPResponseError,
    code=ClientErrorCode::ResponseError.to_string(),
    message~,
    status~,
    headers~,
    body~,
    additional_data=None,
    request_id~,
    ray_id~,
  )
}

///|
/// The error type that encompasses every failure the Notion client raises.
pub(all) suberror NotionClientError {
  NotionClientError(NotionError)
}

///|
/// `true` if the error is a `NotionClientError`.
pub fn is_notion_client_error(error : Error) -> Bool {
  match error {
    NotionClientError(_) => true
    _ => false
  }
}

///|
/// `true` if the error is an HTTP response error
/// (`APIResponseError` or `UnknownHTTPResponseError`).
pub fn is_http_response_error(error : Error) -> Bool {
  match error {
    NotionClientError(e) =>
      e.kind is ApiResponseError || e.kind is UnknownHTTPResponseError
    _ => false
  }
}

///|
/// `true` if the error is an `APIResponseError`.
pub fn is_api_response_error(error : Error) -> Bool {
  match error {
    NotionClientError(e) => e.kind is ApiResponseError
    _ => false
  }
}

///|
/// Reads a header by name, case-insensitively per RFC 9110.
pub fn get_response_header(
  headers : Array[(String, String)],
  name : String,
) -> String? {
  let lower_name = name.to_lower()
  for pair in headers {
    let (key, value) = pair
    if key.to_lower() == lower_name {
      return Some(value)
    }
  }
  None
}

///|
/// Validates that a request path does not contain path traversal sequences.
/// Raises `InvalidPathParameterError` if the path contains `..` segments,
/// including URL-encoded variants like `%2e%2e`.
pub fn validate_request_path(path : String) -> Unit raise {
  if path.contains("..") {
    raise NotionClientError(
      invalid_path_parameter_error(
        message="Request path \"" +
          path +
          "\" contains path traversal sequence \"..\"",
      ),
    )
  }
  let lower = path.to_lower()
  if lower.contains("%2e") {
    let decoded = lower.replace_all(old="%2e", new=".")
    if decoded.contains("..") {
      raise NotionClientError(
        invalid_path_parameter_error(
          message="Request path \"" +
            path +
            "\" contains encoded path traversal sequence",
        ),
      )
    }
  }
}

///|
/// Builds the default message for an unrecognized HTTP response.
///
/// A response with a Cloudflare Ray ID but no Notion request ID was answered
/// before it reached the API.
pub fn build_unknown_response_message(
  status~ : Int,
  content_type~ : String?,
  ray_id~ : String?,
  request_id~ : String?,
) -> String {
  let base = "Request to Notion API failed with status: " + status.to_string()
  match ray_id {
    None => base
    Some(ray) =>
      match request_id {
        Some(_) => base
        None => {
          let content_type_note = match content_type {
            Some(ct) => " (content-type: " + ct + ")"
            None => ""
          }
          let blocked_note = if status == 403 {
            " This may mean the request was blocked by a network security rule."
          } else {
            ""
          }
          base +
          ". The response was returned by Notion's edge proxy before reaching " +
          "the Notion API" +
          content_type_note +
          "." +
          blocked_note +
          " Cloudflare Ray ID: " +
          ray +
          ". Include this ID when contacting Notion support."
        }
      }
  }
}

///|
/// Builds the error to throw for a non-ok HTTP response, preferring the API's
/// structured error body over a generic response error.
pub fn build_request_error(
  response : HttpResponse,
  body_text : String,
) -> NotionClientError {
  match parse_api_error_response_body(body_text) {
    Some(parsed) =>
      NotionClientError(
        api_response_error(
          code=parsed.code,
          message=parsed.message,
          status=response.status,
          headers=response.headers,
          body=body_text,
          additional_data=parsed.additional_data,
          request_id=parsed.request_id,
        ),
      )
    None =>
      NotionClientError(
        unknown_http_response_error(
          status=response.status,
          headers=response.headers,
          body=body_text,
          message=None,
        ),
      )
  }
}

///|
/// The structured shape of an API error response body.
pub(all) struct ParsedAPIError {
  code : APIErrorCode
  message : String
  additional_data : Json?
  request_id : String?
}

///|
/// Parses a Notion API error body. Returns `None` when the body is not JSON or
/// does not carry a `message` and a known `code`.
pub fn parse_api_error_response_body(body : String) -> ParsedAPIError? {
  let parsed : Json = @json.parse(body) catch { _ => return None }
  match parsed {
    Json::Object(fields) =>
      match (fields.get("message"), fields.get("code")) {
        (Some(Json::String(message)), Some(Json::String(code))) =>
          match APIErrorCode::from_string(code) {
            Some(code) =>
              Some({
                code,
                message,
                additional_data: fields.get("additional_data"),
                request_id: match fields.get("request_id") {
                  Some(Json::String(id)) => Some(id)
                  _ => None
                },
              })
            None => None
          }
        _ => None
      }
    _ => None
  }
}
