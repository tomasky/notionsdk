///|
// Note: This is a generated-parity port of src/api-endpoints/blocks.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let getBlock : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["block_id"],
  path=args => "blocks/" + path_param(args, "block_id"),
)

///|
pub let updateBlock : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["block_id"],
  body_params=[
    "archived", "embed", "type", "in_trash", "bookmark", "image", "video", "pdf",
    "file", "audio", "code", "equation", "divider", "breadcrumb", "tab", "table_of_contents",
    "link_to_page", "table_row", "heading_1", "heading_2", "heading_3", "heading_4",
    "paragraph", "bulleted_list_item", "numbered_list_item", "quote", "to_do", "toggle",
    "template", "callout", "synced_block", "table", "column",
  ],
  path=args => "blocks/" + path_param(args, "block_id"),
)

///|
pub let deleteBlock : EndpointDefinition = EndpointDefinition::new(
  http_method="delete",
  path_params=["block_id"],
  path=args => "blocks/" + path_param(args, "block_id"),
)

///|
pub let listBlockChildren : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["block_id"],
  query_params=["start_cursor", "page_size"],
  path=args => "blocks/" + path_param(args, "block_id") + "/children",
)

///|
pub let appendBlockChildren : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["block_id"],
  body_params=["after", "children", "position"],
  path=args => "blocks/" + path_param(args, "block_id") + "/children",
)
