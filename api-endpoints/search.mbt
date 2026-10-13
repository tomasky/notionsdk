///|
// Note: This is a generated-parity port of src/api-endpoints/search.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let search : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["sort", "query", "start_cursor", "page_size", "filter"],
  optional=true,
  path=_ => "search",
)
