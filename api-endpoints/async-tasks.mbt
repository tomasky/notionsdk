///|
// Note: This is a generated-parity port of src/api-endpoints/async-tasks.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let getAsyncTask : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["task_id"],
  path=args => "async_tasks/" + path_param(args, "task_id"),
)
