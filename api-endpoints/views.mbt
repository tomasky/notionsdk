///|
// Note: This is a generated-parity port of src/api-endpoints/views.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let listDatabaseViews : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  query_params=["database_id", "data_source_id", "start_cursor", "page_size"],
  optional=true,
  path=_ => "views",
)

///|
pub let createView : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path=_ => "views",
)

///|
pub let getView : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["view_id"],
  path=args => "views/" + path_param(args, "view_id"),
)

///|
pub let updateView : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["view_id"],
  path=args => "views/" + path_param(args, "view_id"),
)

///|
pub let deleteView : EndpointDefinition = EndpointDefinition::new(
  http_method="delete",
  path_params=["view_id"],
  path=args => "views/" + path_param(args, "view_id"),
)

///|
pub let createViewQuery : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["view_id"],
  path=args => "views/" + path_param(args, "view_id") + "/queries",
)

///|
pub let getViewQueryResults : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["view_id", "query_id"],
  query_params=["start_cursor", "page_size"],
  path=args => {
    "views/" +
    path_param(args, "view_id") +
    "/queries/" +
    path_param(args, "query_id")
  },
)

///|
pub let deleteViewQuery : EndpointDefinition = EndpointDefinition::new(
  http_method="delete",
  path_params=["view_id", "query_id"],
  path=args => {
    "views/" +
    path_param(args, "view_id") +
    "/queries/" +
    path_param(args, "query_id")
  },
)
