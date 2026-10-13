///|
/// A small demonstration of the SDK: it constructs a client with a fake
/// transport and calls the users endpoint.
///
/// Run with `moon run cmd/main` from the project root. Replace the fake
/// `fetch` with a real HTTP transport to talk to the Notion API.
fn main {
  let fetch : @notionsdk.Fetch = (_url, _init) => {
    @notionsdk.HttpResponse::from_text(
      status=200,
      headers=[("x-notion-request-id", "demo-request")],
      body="{\"object\":\"user\",\"id\":\"demo\",\"type\":\"bot\"}",
    )
  }
  let client = @notionsdk.Client::new(
    options=@notionsdk.ClientOptions::new(
      auth=Some("secret_demo_token"),
      fetch=Some(fetch),
      log_level=@notionsdk.Error,
    ),
  )
  try {
    let me = (client.users().me)({})
    println(me.stringify())
  } catch {
    @notionsdk.NotionClientError(error) =>
      println("request failed: " + error.message)
    _ => println("unexpected error")
  }
}
