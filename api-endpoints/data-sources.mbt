///|
// Note: This is a generated-parity port of src/api-endpoints/data-sources.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let getDataSource : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["data_source_id"],
  path=args => "data_sources/" + path_param(args, "data_source_id"),
)

///|
pub let updateDataSource : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["data_source_id"],
  body_params=["archived", "title", "icon", "properties", "in_trash", "parent"],
  path=args => "data_sources/" + path_param(args, "data_source_id"),
)

///|
pub let queryDataSource : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["data_source_id"],
  query_params=["filter_properties"],
  body_params=[
    "archived", "sorts", "filter", "start_cursor", "page_size", "in_trash", "result_type",
  ],
  path=args => "data_sources/" + path_param(args, "data_source_id") + "/query",
)

///|
pub let createDataSource : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["parent", "properties", "title", "icon"],
  path=_ => "data_sources",
)

///|
pub let listDataSourceTemplates : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["data_source_id"],
  query_params=["name", "start_cursor", "page_size"],
  path=args => {
    "data_sources/" + path_param(args, "data_source_id") + "/templates"
  },
)
