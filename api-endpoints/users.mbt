///|
// Note: This is a generated-parity port of src/api-endpoints/users.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let getSelf : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  optional=true,
  path=_ => "users/me",
)

///|
pub let getUser : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["user_id"],
  path=args => "users/" + path_param(args, "user_id"),
)

///|
pub let listUsers : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  query_params=["start_cursor", "page_size"],
  optional=true,
  path=_ => "users",
)
