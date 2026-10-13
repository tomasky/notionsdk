///|
/// Small helpers, ported from `src/utils.ts`.
///
/// In the TypeScript SDK `pick` copies a set of named properties off an
/// arguments object and `getUnknownParams` reports names the endpoint does not
/// know. Here arguments are a `Json` object and `pick` returns a `Json` object.

///|
/// Returns `true` if `value` is a JSON object.
pub fn is_object(value : Json) -> Bool {
  value is Json::Object(_)
}

///|
/// Returns a JSON object with only the given keys from `base`.
///
/// Mirrors `pick` from `utils.ts`: keys that are absent from `base` are skipped
/// rather than copied as `undefined`.
pub fn pick(base : Json, keys : ArrayView[String]) -> Json {
  match base {
    Json::Object(fields) => {
      let out : Map[String, Json] = Map([])
      for key in keys {
        match fields.get(key) {
          Some(value) => out.set(key, value)
          None => ()
        }
      }
      Json::object(out)
    }
    _ => Json::empty_object()
  }
}

///|
/// Returns parameter names present in `args` that are not recognized by the
/// endpoint definition. Useful for warning users about typos or parameters that
/// have been renamed across API versions.
pub fn get_unknown_params(
  args : Json,
  endpoint : @endpoints.EndpointDefinition,
) -> Array[String] {
  let known : Array[String] = []
  known.append(endpoint.path_params)
  known.append(endpoint.query_params)
  known.append(endpoint.body_params)
  known.append(endpoint.form_data_params)
  known.push("auth")
  match args {
    Json::Object(fields) => {
      let unknown : Array[String] = []
      fields.each((key, _) => if !known.contains(key) { unknown.push(key) })
      unknown
    }
    _ => []
  }
}
