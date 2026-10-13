///|
/// A MoonBit port of the Notion SDK for JavaScript.
///
/// The package mirrors the structure and behavior of `@notionhq/client`:
///
/// - `Client` owns URL, header and body construction, authentication, logging,
///   retries and server-sent event parsing.
/// - `api-endpoints/` holds one module per resource with the method, path and
///   parameter lists of every endpoint.
/// - `errors`, `helpers`, `logging`, `utils`, `webhooks` and `constants`
///   correspond to the same-named TypeScript modules.
///
/// The transport is injected. Callers connect `fetch` in `ClientOptions`, which
/// keeps the SDK usable on any runtime and easy to test. Payload objects travel
/// as `Json`, so no generated type definitions are needed.
///
/// See `README.mbt.md` for a walked-through example.
pub let sdk_version : String = "5.27.0"
