///|
// Note: This is a generated-parity port of src/api-endpoints/comments.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let createComment : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=[
    "attachments", "display_name", "parent", "rich_text", "markdown", "discussion_id",
  ],
  path=_ => "comments",
)

///|
pub let listComments : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  query_params=["block_id", "start_cursor", "page_size"],
  path=_ => "comments",
)

///|
pub let getComment : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["comment_id"],
  path=args => "comments/" + path_param(args, "comment_id"),
)

///|
pub let updateComment : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["comment_id"],
  body_params=["rich_text", "markdown"],
  path=args => "comments/" + path_param(args, "comment_id"),
)

///|
pub let deleteComment : EndpointDefinition = EndpointDefinition::new(
  http_method="delete",
  path_params=["comment_id"],
  path=args => "comments/" + path_param(args, "comment_id"),
)
