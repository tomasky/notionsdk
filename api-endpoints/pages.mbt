///|
// Note: This is a generated-parity port of src/api-endpoints/pages.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let createPage : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  query_params=["filter_properties"],
  body_params=[
    "parent", "properties", "icon", "cover", "content", "children", "markdown", "allow_async",
    "template", "position",
  ],
  path=_ => "pages",
)

///|
pub let getPage : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["page_id"],
  query_params=["filter_properties"],
  path=args => "pages/" + path_param(args, "page_id"),
)

///|
pub let updatePage : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["page_id"],
  query_params=["filter_properties"],
  body_params=[
    "archived", "properties", "icon", "cover", "is_locked", "template", "erase_content",
    "in_trash", "is_archived",
  ],
  path=args => "pages/" + path_param(args, "page_id"),
)

///|
pub let movePage : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["page_id"],
  body_params=["parent"],
  path=args => "pages/" + path_param(args, "page_id") + "/move",
)

///|
pub let getPageProperty : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["page_id", "property_id"],
  query_params=["start_cursor", "page_size"],
  path=args => {
    "pages/" +
    path_param(args, "page_id") +
    "/properties/" +
    path_param(args, "property_id")
  },
)

///|
pub let getPageMarkdown : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["page_id"],
  query_params=["include_transcript"],
  path=args => "pages/" + path_param(args, "page_id") + "/markdown",
)

///|
pub let updatePageMarkdown : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["page_id"],
  body_params=[
    "allow_async", "type", "insert_content", "replace_content_range", "update_content",
    "replace_content",
  ],
  path=args => "pages/" + path_param(args, "page_id") + "/markdown",
)
