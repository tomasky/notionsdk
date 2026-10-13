///|
/// Shared building blocks for the generated endpoint definitions.
///
/// This mirrors `src/api-endpoints/common.ts` in notion-sdk-js: that file
/// carries the request/response object types shared by every resource. In this
/// MoonBit port the payloads travel as `Json`, so what is shared here is the
/// `EndpointDefinition` shape and the path-parameter reader.
///
/// Error raised when a required path parameter is missing or not a string.
pub(all) suberror EndpointParameterError {
  EndpointParameterError(String)
}

///|
/// Renders a JSON number the way JavaScript's `String(value)` does for the
/// integers used in path and query parameters.
pub fn number_to_string(value : Double) -> String {
  if value == value.to_int().to_double() {
    value.to_int().to_string()
  } else {
    value.to_string()
  }
}

///|
/// Reads a required path parameter out of an arguments object.
///
/// Equivalent to ``p.<name>`` in the TypeScript endpoint definitions.
pub fn path_param(args : Json, name : String) -> String raise {
  match args {
    Json::Object(fields) =>
      match fields.get(name) {
        Some(Json::String(value)) => value
        Some(Json::Number(value, ..)) => number_to_string(value)
        _ =>
          raise EndpointParameterError(
            "Missing required path parameter: " + name,
          )
      }
    _ => raise EndpointParameterError("Expected an object of path parameters")
  }
}

///|
/// The static description of a Notion API endpoint.
///
/// `pathParams`, `queryParams`, `bodyParams` and `formDataParams` list the
/// parameter names the endpoint understands; the client uses them to filter
/// arguments (see `pick`) and to warn about unknown ones.
pub(all) struct EndpointDefinition {
  /// HTTP method in lower case: "get", "post", "patch" or "delete".
  http_method : String
  /// Names of parameters that are interpolated into the path.
  path_params : Array[String]
  /// Names of parameters that go into the query string.
  query_params : Array[String]
  /// Names of parameters that go into the JSON request body.
  body_params : Array[String]
  /// Names of parameters that go into a multipart/form-data body.
  form_data_params : Array[String]
  /// Extra headers to send with the request.
  headers : Array[(String, String)]
  /// Builds the path from the arguments object.
  path : (Json) -> String raise
  /// True for endpoints that take no required path parameters
  /// (`optionalMethod` in the TypeScript client).
  optional : Bool
}

///|
/// Builds an `EndpointDefinition`, defaulting every parameter list to empty.
pub fn EndpointDefinition::new(
  http_method~ : String,
  path~ : (Json) -> String raise,
  path_params? : Array[String] = [],
  query_params? : Array[String] = [],
  body_params? : Array[String] = [],
  form_data_params? : Array[String] = [],
  headers? : Array[(String, String)] = [],
  optional? : Bool = false,
) -> EndpointDefinition {
  {
    http_method,
    path_params,
    query_params,
    body_params,
    form_data_params,
    headers,
    path,
    optional,
  }
}
