///|
// Note: This is a generated-parity port of src/api-endpoints/databases.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let getDatabase : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["database_id"],
  path=args => "databases/" + path_param(args, "database_id"),
)

///|
pub let updateDatabase : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["database_id"],
  body_params=[
    "parent", "title", "description", "is_inline", "icon", "cover", "in_trash", "is_locked",
  ],
  path=args => "databases/" + path_param(args, "database_id"),
)

///|
pub let createDatabase : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=[
    "parent", "title", "description", "is_inline", "initial_data_source", "database_type",
    "icon", "cover",
  ],
  path=_ => "databases",
)
