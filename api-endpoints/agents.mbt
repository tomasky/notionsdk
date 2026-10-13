///|
// Note: This is a generated-parity port of src/api-endpoints/agents.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let updateSessionStream : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=[
    "message", "agent_id", "session_id", "attachments", "metadata", "prompt_context",
    "actions", "continue_from",
  ],
  headers=[("Accept", "text/event-stream")],
  path=_ => "sessions",
)

///|
pub let agentBatch : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["operations"],
  path=_ => "agents/batch",
)

///|
pub let cancelSession : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["session_id"],
  body_params=["event_id"],
  path=args => "sessions/" + path_param(args, "session_id") + "/cancel",
)

///|
pub let chatWithAgent : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["agent_id"],
  query_params=["verbose"],
  body_params=[
    "message", "attachments", "metadata", "prompt_context", "thread_id",
  ],
  path=args => "agents/" + path_param(args, "agent_id") + "/chat",
)

///|
pub let continueThread : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["thread_id"],
  body_params=["action_id", "option_id", "input"],
  path=args => "threads/" + path_param(args, "thread_id") + "/continue",
)

///|
pub let createExternalAgentStubVault : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["agent_id"],
  body_params=["name", "credential", "target"],
  path=args => "external_agent_stub/" + path_param(args, "agent_id") + "/vaults",
)

///|
pub let deleteAgent : EndpointDefinition = EndpointDefinition::new(
  http_method="delete",
  path_params=["agent_id"],
  path=args => "agents/" + path_param(args, "agent_id"),
)

///|
pub let getAgent : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["agent_id"],
  query_params=["verbose"],
  path=args => "agents/" + path_param(args, "agent_id"),
)

///|
pub let deleteExternalAgentStubVault : EndpointDefinition = EndpointDefinition::new(
  http_method="delete",
  path_params=["agent_id", "vault_id"],
  path=args => {
    "external_agent_stub/" +
    path_param(args, "agent_id") +
    "/vaults/" +
    path_param(args, "vault_id")
  },
)

///|
pub let updateExternalAgentStubVault : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["agent_id", "vault_id"],
  body_params=["expected_version", "credential"],
  path=args => {
    "external_agent_stub/" +
    path_param(args, "agent_id") +
    "/vaults/" +
    path_param(args, "vault_id")
  },
)

///|
pub let getInsights : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["agent_id"],
  query_params=["start_time", "end_time"],
  path=args => "agents/" + path_param(args, "agent_id") + "/insights",
)

///|
pub let listAgents : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  query_params=[
    "name", "agent_type", "agent_ids", "created_by", "start_cursor", "page_size",
    "verbose",
  ],
  path=_ => "agents",
)

///|
pub let listExternalAgentStubSessionEvents : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["agent_id", "session_id"],
  query_params=["cursor"],
  path=args => {
    "external_agent_stub/" +
    path_param(args, "agent_id") +
    "/sessions/" +
    path_param(args, "session_id") +
    "/events"
  },
)

///|
pub let listThreadMessages : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["thread_id"],
  query_params=["verbose", "role", "start_cursor", "page_size"],
  path=args => "threads/" + path_param(args, "thread_id") + "/messages",
)

///|
pub let sendThreadMessage : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["thread_id"],
  body_params=["message", "attachments", "metadata", "prompt_context"],
  path=args => "threads/" + path_param(args, "thread_id") + "/messages",
)

///|
pub let listThreads : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["agent_id"],
  query_params=[
    "id", "title", "status", "activity", "created_by", "last_used_by", "sort_by",
    "sort_direction", "start_cursor", "page_size",
  ],
  path=args => "agents/" + path_param(args, "agent_id") + "/threads",
)

///|
pub let queryAgents : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=[
    "query", "filter", "sorts", "start_cursor", "page_size", "verbose", "include_deleted",
  ],
  optional=true,
  path=_ => "agents/query",
)

///|
pub let querySessionEvents : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["session_id"],
  body_params=["filter", "sorts", "start_cursor", "page_size"],
  path=args => "sessions/" + path_param(args, "session_id") + "/events/query",
)

///|
pub let querySessions : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["query", "filter", "sorts", "start_cursor", "page_size"],
  optional=true,
  path=_ => "sessions/query",
)

///|
pub let queryThreadMessages : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["thread_id"],
  body_params=["verbose", "start_cursor", "page_size"],
  path=args => "threads/" + path_param(args, "thread_id") + "/messages/query",
)

///|
pub let queryThreads : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["agent_id"],
  body_params=["query", "filter", "sorts", "start_cursor", "page_size"],
  path=args => "agents/" + path_param(args, "agent_id") + "/threads/query",
)

///|
pub let retrieveSession : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["session_id"],
  path=args => "sessions/" + path_param(args, "session_id"),
)

///|
pub let sendExternalAgentStubSessionMessage : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["agent_id", "session_id"],
  body_params=["message", "client_message_id"],
  path=args => {
    "external_agent_stub/" +
    path_param(args, "agent_id") +
    "/sessions/" +
    path_param(args, "session_id") +
    "/messages"
  },
)

///|
pub let startExternalAgentStubSession : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["agent_id"],
  body_params=[
    "spec_version", "client_reference_id", "configs", "model", "cwd", "locale", "system_prompt",
  ],
  path=args => {
    "external_agent_stub/" + path_param(args, "agent_id") + "/sessions"
  },
)

///|
pub let updateAgentCreditLimit : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["agent_id"],
  body_params=["credit_limit"],
  path=args => "agents/" + path_param(args, "agent_id") + "/credit_limit",
)

///|
pub let updateAgentStatus : EndpointDefinition = EndpointDefinition::new(
  http_method="patch",
  path_params=["agent_id"],
  body_params=["status"],
  path=args => "agents/" + path_param(args, "agent_id") + "/status",
)

///|
pub let updateSession : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=[
    "message", "agent_id", "session_id", "attachments", "metadata", "prompt_context",
    "actions", "continue_from",
  ],
  path=_ => "sessions",
)
