///|
// Note: This is a generated-parity port of src/api-endpoints/meeting-notes.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let createMeetingNote : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["title", "language", "options", "source", "parent"],
  path=_ => "blocks/meeting_notes",
)

///|
pub let queryMeetingNotes : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["filter", "sort", "limit"],
  path=_ => "blocks/meeting_notes/query",
)
