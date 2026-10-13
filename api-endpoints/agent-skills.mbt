///|
// Note: This is a generated-parity port of src/api-endpoints/agent-skills.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let listSkillsPlugins : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  query_params=["page_size", "start_cursor"],
  optional=true,
  path=_ => "ai/plugins",
)

///|
pub let getPluginDirectory : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["id"],
  path=args => "ai/plugins/" + path_param(args, "id"),
)

///|
pub let getSkillDirectory : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["id"],
  path=args => "ai/skills/" + path_param(args, "id"),
)
