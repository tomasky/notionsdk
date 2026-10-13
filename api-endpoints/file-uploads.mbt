///|
// Note: This is a generated-parity port of src/api-endpoints/file-uploads.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let createFileUpload : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=[
    "mode", "filename", "content_type", "number_of_parts", "external_url",
  ],
  optional=true,
  path=_ => "file_uploads",
)

///|
pub let listFileUploads : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  query_params=["status", "start_cursor", "page_size"],
  path=_ => "file_uploads",
)

///|
pub let sendFileUpload : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["file_upload_id"],
  form_data_params=["file", "part_number"],
  path=args => "file_uploads/" + path_param(args, "file_upload_id") + "/send",
)

///|
pub let completeFileUpload : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  path_params=["file_upload_id"],
  path=args => {
    "file_uploads/" + path_param(args, "file_upload_id") + "/complete"
  },
)

///|
pub let getFileUpload : EndpointDefinition = EndpointDefinition::new(
  http_method="get",
  path_params=["file_upload_id"],
  path=args => "file_uploads/" + path_param(args, "file_upload_id"),
)
