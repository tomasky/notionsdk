///|
/// Endpoint methods, ported from `src/api-endpoint-methods.ts`.
///
/// Each resource is exposed as a struct of bound functions (for example
/// `client.pages().create(args)`), so the shape matches the TypeScript client's
/// `notion.pages.create` while staying idiomatic MoonBit.

///|
/// Resource methods for `users`.
pub struct UsersEndpointMethods {
  me : (Json) -> Json raise
  retrieve : (Json) -> Json raise
  list : (Json) -> Json raise
}

///|
/// Resource methods for `pages`.
pub struct PagesEndpointMethods {
  create : (Json) -> Json raise
  retrieve : (Json) -> Json raise
  update : (Json) -> Json raise
  move_page : (Json) -> Json raise
  retrieve_markdown : (Json) -> Json raise
  update_markdown : (Json) -> Json raise
  properties_retrieve : (Json) -> Json raise
}

///|
/// Resource methods for `asyncTasks`.
pub struct AsyncTasksEndpointMethods {
  retrieve : (Json) -> Json raise
}

///|
/// Resource methods for `blocks`.
pub struct BlocksEndpointMethods {
  retrieve : (Json) -> Json raise
  update : (Json) -> Json raise
  delete : (Json) -> Json raise
  children_list : (Json) -> Json raise
  children_append : (Json) -> Json raise
  meeting_notes_create : (Json) -> Json raise
  meeting_notes_query : (Json) -> Json raise
}

///|
/// Resource methods for `dataSources`.
pub struct DataSourcesEndpointMethods {
  retrieve : (Json) -> Json raise
  update : (Json) -> Json raise
  query : (Json) -> Json raise
  create : (Json) -> Json raise
  list_templates : (Json) -> Json raise
}

///|
/// Resource methods for `databases`.
pub struct DatabasesEndpointMethods {
  retrieve : (Json) -> Json raise
  update : (Json) -> Json raise
  create : (Json) -> Json raise
}

///|
/// Resource methods for `comments`.
pub struct CommentsEndpointMethods {
  create : (Json) -> Json raise
  list : (Json) -> Json raise
  retrieve : (Json) -> Json raise
  update : (Json) -> Json raise
  delete : (Json) -> Json raise
}

///|
/// Resource methods for `fileUploads`.
pub struct FileUploadsEndpointMethods {
  create : (Json) -> Json raise
  retrieve : (Json) -> Json raise
  list : (Json) -> Json raise
  send : (Json) -> Json raise
  complete : (Json) -> Json raise
}

///|
/// Resource methods for `views`.
pub struct ViewsEndpointMethods {
  list : (Json) -> Json raise
  create : (Json) -> Json raise
  retrieve : (Json) -> Json raise
  update : (Json) -> Json raise
  delete : (Json) -> Json raise
  queries_create : (Json) -> Json raise
  queries_results : (Json) -> Json raise
  queries_delete : (Json) -> Json raise
}

///|
/// Resource methods for `agents`.
pub struct AgentsEndpointMethods {
  query : (Json) -> Json raise
  retrieve : (Json) -> Json raise
  delete : (Json) -> Json raise
  retrieve_insights : (Json) -> Json raise
  update_status : (Json) -> Json raise
  update_credit_limit : (Json) -> Json raise
  batch : (Json) -> Json raise
}

///|
/// Resource methods for `plugins`.
pub struct PluginsEndpointMethods {
  list : (Json) -> Json raise
  retrieve : (Json) -> Json raise
}

///|
/// Resource methods for `skills`.
pub struct SkillsEndpointMethods {
  retrieve : (Json) -> Json raise
}

///|
/// Resource methods for `sessions`.
pub struct SessionsEndpointMethods {
  retrieve : (Json) -> Json raise
  update : (Json) -> Json raise
  stream : (Json) -> Array[Json] raise
  cancel : (Json) -> Json raise
  query : (Json) -> Json raise
  query_events : (Json) -> Json raise
}

///|
/// Resource methods for `oauth`.
pub struct OauthEndpointMethods {
  token : (Json) -> Json raise
  introspect : (Json) -> Json raise
  revoke : (Json) -> Json raise
}

///|
/// Arguments to `search`, exposed as its own resource in the TypeScript client.
pub struct SearchEndpointMethods {
  search : (Json) -> Json raise
}

///|
/// Calls an endpoint, filtering arguments through its parameter lists and
/// warning about unrecognized names.
fn Client::call_endpoint(
  self : Client,
  definition : @endpoints.EndpointDefinition,
  args : Json,
) -> Json raise {
  self.warn_unknown_params(args, definition)
  self.request(
    endpoint_request(
      definition,
      args,
      definition.body_params,
      definition.query_params,
    ),
  )
}

///|
/// Calls an endpoint with explicit body/query key lists. Used where the
/// TypeScript client filters fields itself (`views.create` and friends).
fn Client::call_endpoint_keys(
  self : Client,
  definition : @endpoints.EndpointDefinition,
  args : Json,
  body_keys : Array[String],
  query_keys : Array[String],
) -> Json raise {
  self.request(endpoint_request(definition, args, body_keys, query_keys))
}

///|
/// Calls an endpoint with a caller-supplied auth (used by the OAuth endpoints).
fn Client::call_endpoint_auth(
  self : Client,
  definition : @endpoints.EndpointDefinition,
  args : Json,
  auth : RequestAuth?,
) -> Json raise {
  self.warn_unknown_params(args, definition)
  let request = endpoint_request(
    definition,
    args,
    definition.body_params,
    definition.query_params,
  )
  self.request({ ..request, auth, })
}

///|
/// Builds the `RequestParameters` for an endpoint definition.
fn endpoint_request(
  definition : @endpoints.EndpointDefinition,
  args : Json,
  body_keys : Array[String],
  query_keys : Array[String],
) -> RequestParameters raise {
  RequestParameters::new(
    path=(definition.path)(args),
    http_method=definition.http_method,
    query=Some(pick(args, query_keys)),
    body=Some(pick(args, body_keys)),
    form_data_params=if definition.form_data_params.is_empty() {
      None
    } else {
      Some(pick(args, definition.form_data_params))
    },
    headers=definition.headers,
    auth=request_auth_from_args(args),
  )
}

///|
/// Reads a per-request bearer token from the `auth` field of an arguments
/// object.
fn request_auth_from_args(args : Json) -> RequestAuth? {
  match args {
    Json::Object(fields) =>
      match fields.get("auth") {
        Some(Json::String(token)) => Some(Bearer(token))
        _ => None
      }
    _ => None
  }
}

///|
/// Reads OAuth client credentials from an arguments object.
fn oauth_auth_from_args(args : Json) -> RequestAuth? {
  match args {
    Json::Object(fields) =>
      match (fields.get("client_id"), fields.get("client_secret")) {
        (Some(Json::String(client_id)), Some(Json::String(client_secret))) =>
          Some(Basic(client_id~, client_secret~))
        _ => None
      }
    _ => None
  }
}

///|
/// Logs a warning when the caller passes parameters that are not recognized by
/// the endpoint definition.
fn Client::warn_unknown_params(
  self : Client,
  args : Json,
  definition : @endpoints.EndpointDefinition,
) -> Unit {
  let unknown = get_unknown_params(args, definition)
  if !unknown.is_empty() {
    let known : Array[String] = []
    known.append(definition.path_params)
    known.append(definition.query_params)
    known.append(definition.body_params)
    known.append(definition.form_data_params)
    self.log_warning(unknown, known)
  }
}

///|
/// Emits the "unknown parameters were ignored" warning.
fn Client::log_warning(
  self : Client,
  unknown : Array[String],
  known : Array[String],
) -> Unit {
  self.log(
    Warn,
    "unknown parameters were ignored",
    Json::object(
      Map([
        ("unknownParams", Json::array(unknown.map(x => Json::string(x)))),
        ("knownParams", Json::array(known.map(x => Json::string(x)))),
      ]),
    ),
  )
}

///|
/// The resource clients, each bound to this client.
pub fn Client::users(self : Client) -> UsersEndpointMethods {
  {
    me: args => self.call_endpoint(@endpoints.getSelf, args),
    retrieve: args => self.call_endpoint(@endpoints.getUser, args),
    list: args => self.call_endpoint(@endpoints.listUsers, args),
  }
}

///|
pub fn Client::pages(self : Client) -> PagesEndpointMethods {
  {
    create: args => self.call_endpoint(@endpoints.createPage, args),
    retrieve: args => self.call_endpoint(@endpoints.getPage, args),
    update: args => self.call_endpoint(@endpoints.updatePage, args),
    move_page: args => self.call_endpoint(@endpoints.movePage, args),
    retrieve_markdown: args => {
      self.call_endpoint(@endpoints.getPageMarkdown, args)
    },
    update_markdown: args => {
      self.call_endpoint(@endpoints.updatePageMarkdown, args)
    },
    properties_retrieve: args => {
      self.call_endpoint(@endpoints.getPageProperty, args)
    },
  }
}

///|
pub fn Client::async_tasks(self : Client) -> AsyncTasksEndpointMethods {
  { retrieve: args => self.call_endpoint(@endpoints.getAsyncTask, args), }
}

///|
pub fn Client::blocks(self : Client) -> BlocksEndpointMethods {
  {
    retrieve: args => self.call_endpoint(@endpoints.getBlock, args),
    update: args => self.call_endpoint(@endpoints.updateBlock, args),
    delete: args => self.call_endpoint(@endpoints.deleteBlock, args),
    children_list: args => {
      self.call_endpoint(@endpoints.listBlockChildren, args)
    },
    children_append: args => {
      self.call_endpoint(@endpoints.appendBlockChildren, args)
    },
    meeting_notes_create: args => {
      self.call_endpoint(@endpoints.createMeetingNote, args)
    },
    meeting_notes_query: args => {
      self.call_endpoint(@endpoints.queryMeetingNotes, args)
    },
  }
}

///|
pub fn Client::data_sources(self : Client) -> DataSourcesEndpointMethods {
  {
    retrieve: args => self.call_endpoint(@endpoints.getDataSource, args),
    update: args => self.call_endpoint(@endpoints.updateDataSource, args),
    query: args => self.call_endpoint(@endpoints.queryDataSource, args),
    create: args => self.call_endpoint(@endpoints.createDataSource, args),
    list_templates: args => {
      self.call_endpoint(@endpoints.listDataSourceTemplates, args)
    },
  }
}

///|
pub fn Client::databases(self : Client) -> DatabasesEndpointMethods {
  {
    retrieve: args => self.call_endpoint(@endpoints.getDatabase, args),
    update: args => self.call_endpoint(@endpoints.updateDatabase, args),
    create: args => self.call_endpoint(@endpoints.createDatabase, args),
  }
}

///|
pub fn Client::comments(self : Client) -> CommentsEndpointMethods {
  {
    create: args => self.call_endpoint(@endpoints.createComment, args),
    list: args => self.call_endpoint(@endpoints.listComments, args),
    retrieve: args => self.call_endpoint(@endpoints.getComment, args),
    update: args => self.call_endpoint(@endpoints.updateComment, args),
    delete: args => self.call_endpoint(@endpoints.deleteComment, args),
  }
}

///|
pub fn Client::file_uploads(self : Client) -> FileUploadsEndpointMethods {
  {
    create: args => self.call_endpoint(@endpoints.createFileUpload, args),
    retrieve: args => self.call_endpoint(@endpoints.getFileUpload, args),
    list: args => self.call_endpoint(@endpoints.listFileUploads, args),
    send: args => self.call_endpoint(@endpoints.sendFileUpload, args),
    complete: args => self.call_endpoint(@endpoints.completeFileUpload, args),
  }
}

///|
pub fn Client::views(self : Client) -> ViewsEndpointMethods {
  let create_body : Array[String] = [
    "data_source_id", "name", "type", "database_id", "view_id", "filter", "sorts",
    "quick_filters", "create_database", "configuration", "position", "placement",
  ]
  let update_body : Array[String] = [
    "name", "filter", "sorts", "quick_filters", "configuration",
  ]
  {
    list: args => self.call_endpoint(@endpoints.listDatabaseViews, args),
    create: args => {
      self.call_endpoint_keys(@endpoints.createView, args, create_body, [])
    },
    retrieve: args => self.call_endpoint(@endpoints.getView, args),
    update: args => {
      self.call_endpoint_keys(@endpoints.updateView, args, update_body, [])
    },
    delete: args => self.call_endpoint(@endpoints.deleteView, args),
    queries_create: args => {
      self.call_endpoint_keys(@endpoints.createViewQuery, args, ["page_size"], [])
    },
    queries_results: args => {
      self.call_endpoint(@endpoints.getViewQueryResults, args)
    },
    queries_delete: args => self.call_endpoint(@endpoints.deleteViewQuery, args),
  }
}

///|
pub fn Client::agents(self : Client) -> AgentsEndpointMethods {
  {
    query: args => self.call_endpoint(@endpoints.queryAgents, args),
    retrieve: args => self.call_endpoint(@endpoints.getAgent, args),
    delete: args => self.call_endpoint(@endpoints.deleteAgent, args),
    retrieve_insights: args => self.call_endpoint(@endpoints.getInsights, args),
    update_status: args => {
      self.call_endpoint(@endpoints.updateAgentStatus, args)
    },
    update_credit_limit: args => {
      self.call_endpoint(@endpoints.updateAgentCreditLimit, args)
    },
    batch: args => self.call_endpoint(@endpoints.agentBatch, args),
  }
}

///|
pub fn Client::plugins(self : Client) -> PluginsEndpointMethods {
  {
    list: args => self.call_endpoint(@endpoints.listSkillsPlugins, args),
    // Plugin IDs can be tag IDs containing URL delimiters, not just UUIDs, so
    // the client percent-encodes them before building the path.
    retrieve: args => {
      self.call_endpoint(
        @endpoints.getPluginDirectory,
        encode_string_field(args, "id"),
      )
    },
  }
}

///|
pub fn Client::skills(self : Client) -> SkillsEndpointMethods {
  { retrieve: args => self.call_endpoint(@endpoints.getSkillDirectory, args), }
}

///|
pub fn Client::sessions(self : Client) -> SessionsEndpointMethods {
  {
    retrieve: args => self.call_endpoint(@endpoints.retrieveSession, args),
    update: args => self.call_endpoint(@endpoints.updateSession, args),
    stream: args => {
      let definition = @endpoints.updateSessionStream
      self.warn_unknown_params(args, definition)
      self.stream_request(
        endpoint_request(
          definition,
          args,
          definition.body_params,
          definition.query_params,
        ),
        parse_session_stream_event,
      )
    },
    cancel: args => self.call_endpoint(@endpoints.cancelSession, args),
    query: args => self.call_endpoint(@endpoints.querySessions, args),
    query_events: args => {
      self.call_endpoint(@endpoints.querySessionEvents, args)
    },
  }
}

///|
pub fn Client::oauth(self : Client) -> OauthEndpointMethods {
  {
    token: args => {
      self.call_endpoint_auth(
        @endpoints.oauthToken,
        args,
        oauth_auth_from_args(args),
      )
    },
    introspect: args => {
      self.call_endpoint_auth(
        @endpoints.oauthIntrospect,
        args,
        oauth_auth_from_args(args),
      )
    },
    revoke: args => {
      self.call_endpoint_auth(
        @endpoints.oauthRevoke,
        args,
        oauth_auth_from_args(args),
      )
    },
  }
}

///|
pub fn Client::search(self : Client) -> SearchEndpointMethods {
  { search: args => self.call_endpoint(@endpoints.search, args), }
}

///|
/// Percent-encodes a string field of an arguments object, leaving the object
/// otherwise untouched.
fn encode_string_field(args : Json, name : String) -> Json {
  match args {
    Json::Object(fields) => {
      let out : Map[String, Json] = Map([])
      fields.each((key, value) => {
        if key == name {
          match value {
            Json::String(s) =>
              out.set(key, Json::string(encode_uri_component(s)))
            other => out.set(key, other)
          }
        } else {
          out.set(key, value)
        }
      })
      Json::object(out)
    }
    _ => args
  }
}
