///|
// Note: This is a generated-parity port of src/api-endpoints/oauth.ts from
// notion-sdk-js. Payload object types from the original are represented as
// `Json`; the request shape (method, path and parameter names) is preserved.

///|
pub let oauthToken : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=[
    "grant_type", "code", "redirect_uri", "external_account", "refresh_token",
  ],
  path=_ => "oauth/token",
)

///|
pub let oauthRevoke : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["token"],
  path=_ => "oauth/revoke",
)

///|
pub let oauthIntrospect : EndpointDefinition = EndpointDefinition::new(
  http_method="post",
  body_params=["token"],
  path=_ => "oauth/introspect",
)
