///|
// Note: This is a generated-parity port of src/api-endpoints/custom-emojis.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let listCustomEmojis : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  query_params=["start_cursor", "page_size", "name"],
  path=_ => "custom_emojis",
)
