///|
/// Response helpers, ported from `src/helpers.ts`.
///
/// The TypeScript SDK pages with async iterators. MoonBit has no equivalent
/// `for await`, so the `iterate*` helpers here collect a page set into an array;
/// `collect*` is kept as the primary name and the iterate names are aliases.

///|
/// A page of results from any paginated Notion API.
pub(all) struct PaginatedList {
  results : Array[Json]
  next_cursor : String?
  has_more : Bool
}

///|
/// Reads the pagination fields out of a list response.
pub fn parse_paginated_list(response : Json) -> PaginatedList {
  let fields = object_fields(response)
  {
    results: match fields.get("results") {
      Some(Json::Array(items)) => items
      _ => []
    },
    next_cursor: match fields.get("next_cursor") {
      Some(Json::String(cursor)) => Some(cursor)
      _ => None
    },
    has_more: match fields.get("has_more") {
      Some(Json::True) => true
      _ => false
    },
  }
}

///|
/// Collects all of the results of paginating an API into an in-memory array.
pub fn collect_paginated_api(
  list_fn : (Json) -> Json raise,
  first_page_args : Json,
) -> Array[Json] raise {
  let results : Array[Json] = []
  let mut cursor = start_cursor_of(first_page_args)
  while true {
    let response = list_fn(set_start_cursor(first_page_args, cursor))
    let page = parse_paginated_list(response)
    for item in page.results {
      results.push(item)
    }
    cursor = page.next_cursor
    if cursor is None {
      break
    }
  }
  results
}

///|
/// Alias for `collect_paginated_api`. Present so callers porting TypeScript
/// `iteratePaginatedAPI` calls have a matching name.
pub fn iterate_paginated_api(
  list_fn : (Json) -> Json raise,
  first_page_args : Json,
) -> Array[Json] raise {
  collect_paginated_api(list_fn, first_page_args)
}

///|
/// Collects every data source template into an in-memory array.
pub fn collect_data_source_templates(
  client : Client,
  args : Json,
) -> Array[Json] raise {
  let results : Array[Json] = []
  let mut cursor = start_cursor_of(args)
  while true {
    let response = (client.data_sources().list_templates)(
      set_start_cursor(args, cursor),
    )
    let fields = object_fields(response)
    match fields.get("templates") {
      Some(Json::Array(items)) =>
        for item in items {
          results.push(item)
        }
      _ => ()
    }
    cursor = match fields.get("next_cursor") {
      Some(Json::String(next)) => Some(next)
      _ => None
    }
    if cursor is None {
      break
    }
  }
  results
}

///|
/// Alias for `collect_data_source_templates`.
pub fn iterate_data_source_templates(
  client : Client,
  args : Json,
) -> Array[Json] raise {
  collect_data_source_templates(client, args)
}

///|
/// Collects every row of a data source, including rows past the per-query
/// result limit.
///
/// A single query (one filter and sort) returns at most a fixed number of rows.
/// Once that limit is reached, `has_more` becomes `false` and the response
/// carries `request_status.type === "incomplete"`; plain pagination stops there
/// and silently misses the rest.
///
/// This helper partitions the data source into created_time windows. It sorts
/// by created_time ascending; whenever a window reaches the limit, it starts a
/// fresh query from the last row's created_time. Rows that share a boundary
/// timestamp are de-duplicated by id, so every row is yielded exactly once.
pub fn collect_all_data_source_rows(
  client : Client,
  args : Json,
) -> Array[Json] raise {
  let seen : Map[String, Bool] = Map([])
  let rows : Array[Json] = []
  let mut window_start : String? = None

  while true {
    let mut limit_reached = false
    let mut last_created_time : String? = None
    let mut cursor : String? = None
    let mut more = true
    while more {
      let query_args = build_full_data_source_query(args, window_start, cursor)
      let response = (client.data_sources().query)(query_args)
      let fields = object_fields(response)
      match fields.get("results") {
        Some(Json::Array(items)) =>
          for row in items {
            if is_full_page_or_data_source(row) {
              last_created_time = match object_fields(row).get("created_time") {
                Some(Json::String(time)) => Some(time)
                _ => last_created_time
              }
            }
            match object_fields(row).get("id") {
              Some(Json::String(id)) =>
                if !seen.contains(id) {
                  seen.set(id, true)
                  rows.push(row)
                }
              _ => ()
            }
          }
        _ => ()
      }
      match fields.get("request_status") {
        Some(Json::Object(status)) =>
          match status.get("type") {
            Some(Json::String("incomplete")) => limit_reached = true
            _ => ()
          }
        _ => ()
      }
      cursor = match fields.get("next_cursor") {
        Some(Json::String(next)) => Some(next)
        _ => None
      }
      more = cursor is Some(_)
    }

    if !limit_reached {
      return rows
    }
    match last_created_time {
      None =>
        raise notion_progress_error(
          "iterateAllDataSourceRows cannot make progress: the per-query result " +
          "limit was reached but the created_time window could not advance.",
        )
      Some(time) =>
        if window_start is Some(start) && start == time {
          raise notion_progress_error(
            "iterateAllDataSourceRows cannot make progress: the per-query result " +
            "limit was reached but the created_time window could not advance " +
            "past " +
            time +
            ". More rows share this timestamp than the limit allows. Add a filter " +
            "to narrow the query.",
          )
        } else {
          window_start = Some(time)
        }
    }
  } nobreak {
    rows
  }
}

///|
/// Alias for `collect_all_data_source_rows`.
pub fn iterate_all_data_source_rows(
  client : Client,
  args : Json,
) -> Array[Json] raise {
  collect_all_data_source_rows(client, args)
}

///|
/// Builds the query arguments for one window of
/// `collect_all_data_source_rows`.
fn build_full_data_source_query(
  args : Json,
  window_start : String?,
  cursor : String?,
) -> Json {
  let fields = object_fields(args)
  let out : Map[String, Json] = Map([])
  fields.each((key, value) => out.set(key, value))
  out.set(
    "sorts",
    Json::array([
      Json::object(
        Map([
          ("timestamp", Json::string("created_time")),
          ("direction", Json::string("ascending")),
        ]),
      ),
    ]),
  )
  match created_time_lower_bound(fields.get("filter"), window_start) {
    Some(filter) => out.set("filter", filter)
    None => out.remove("filter")
  }
  match cursor {
    Some(c) => out.set("start_cursor", Json::string(c))
    None => out.remove("start_cursor")
  }
  Json::object(out)
}

///|
/// Combines a caller-provided filter with the created_time lower bound used to
/// advance the partition window.
fn created_time_lower_bound(filter : Json?, window_start : String?) -> Json? {
  match window_start {
    None => filter
    Some(start) => {
      let bound = Json::object(
        Map([
          ("timestamp", Json::string("created_time")),
          (
            "created_time",
            Json::object(Map([("on_or_after", Json::string(start))])),
          ),
        ]),
      )
      match filter {
        None => Some(bound)
        Some(f) =>
          match object_fields(f).get("and") {
            Some(Json::Array(existing)) => {
              let combined : Array[Json] = []
              for item in existing {
                combined.push(item)
              }
              combined.push(bound)
              Some(Json::object(Map([("and", Json::array(combined))])))
            }
            _ => Some(Json::array([f, bound]))
          }
      }
    }
  }
}

///|
/// Builds the error raised when the created_time window cannot advance.
fn notion_progress_error(message : String) -> NotionClientError {
  NotionClientError(
    NotionError::new(
      kind=UnknownHTTPResponseError,
      code=ClientErrorCode::ResponseError.to_string(),
      message~,
    ),
  )
}

///|
/// Returns the fields of a JSON object, or an empty map for other values.
fn object_fields(value : Json) -> Map[String, Json] {
  match value {
    Json::Object(fields) => fields
    _ => Map([])
  }
}

///|
/// Reads `start_cursor` out of a query arguments object.
fn start_cursor_of(args : Json) -> String? {
  match object_fields(args).get("start_cursor") {
    Some(Json::String(cursor)) => Some(cursor)
    _ => None
  }
}

///|
/// Returns a copy of `args` with `start_cursor` set (or removed when absent),
/// matching the client's treatment of a null cursor.
pub fn set_start_cursor(args : Json, cursor : String?) -> Json {
  let out : Map[String, Json] = Map([])
  object_fields(args).each((key, value) => {
    if key != "start_cursor" {
      out.set(key, value)
    }
  })
  match cursor {
    Some(c) => out.set("start_cursor", Json::string(c))
    None => ()
  }
  Json::object(out)
}

// ---------------------------------------------------------------------------
// Response type guards
// ---------------------------------------------------------------------------

///|
/// `true` if `response` is a full `BlockObjectResponse`.
pub fn is_full_block(response : Json) -> Bool {
  has_string(response, "object", "block") && has_key(response, "type")
}

///|
/// `true` if `response` is a full `PageObjectResponse`.
pub fn is_full_page(response : Json) -> Bool {
  has_string(response, "object", "page") && has_key(response, "url")
}

///|
/// `true` if `response` is a full `DataSourceObjectResponse`.
pub fn is_full_data_source(response : Json) -> Bool {
  has_string(response, "object", "data_source") && has_key(response, "title")
}

///|
/// `true` if `response` is a full `DatabaseObjectResponse`.
pub fn is_full_database(response : Json) -> Bool {
  has_string(response, "object", "database") && has_key(response, "title")
}

///|
/// `true` if `response` is a full page or a full data source.
pub fn is_full_page_or_data_source(response : Json) -> Bool {
  if has_string(response, "object", "data_source") {
    is_full_data_source(response)
  } else {
    is_full_page(response)
  }
}

///|
/// `true` if `response` is a full `UserObjectResponse`.
pub fn is_full_user(response : Json) -> Bool {
  has_key(response, "type")
}

///|
/// `true` if `response` is a full `CommentObjectResponse`.
pub fn is_full_comment(response : Json) -> Bool {
  has_key(response, "created_by")
}

///|
/// `true` if `response` is a full `DataSourceViewObjectResponse`.
pub fn is_full_view(response : Json) -> Bool {
  has_key(response, "type")
}

///|
/// `true` if `rich_text` is a text rich text item.
pub fn is_text_rich_text_item_response(rich_text : Json) -> Bool {
  has_string(rich_text, "type", "text")
}

///|
/// `true` if `rich_text` is an equation rich text item.
pub fn is_equation_rich_text_item_response(rich_text : Json) -> Bool {
  has_string(rich_text, "type", "equation")
}

///|
/// `true` if `rich_text` is a mention rich text item.
pub fn is_mention_rich_text_item_response(rich_text : Json) -> Bool {
  has_string(rich_text, "type", "mention")
}

///|
/// Whether an object has a key with a given string value.
fn has_string(response : Json, key : String, expected : String) -> Bool {
  match object_fields(response).get(key) {
    Some(Json::String(value)) => value == expected
    _ => false
  }
}

///|
/// Whether an object has a key at all.
fn has_key(response : Json, key : String) -> Bool {
  object_fields(response).get(key) is Some(_)
}

// ---------------------------------------------------------------------------
// Notion ID extraction
// ---------------------------------------------------------------------------

///|
/// Extracts a Notion ID from a Notion URL, or returns the input if it is
/// already a valid ID. Path IDs are prioritized over query parameters to avoid
/// extracting view IDs instead of database IDs.
pub fn extract_notion_id(url_or_id : String) -> String? {
  let trimmed = url_or_id.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  let lower = trimmed.to_lower()
  if regex_matches(
      "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", lower,
    ) {
    return Some(lower)
  }
  if regex_matches("^[0-9a-f]{32}$", lower) {
    return Some(format_uuid(lower))
  }
  match regex_group("/[^/?#]*-([0-9a-f]{32})([/?#]|$)", lower, 1) {
    Some(id) => return Some(format_uuid(id))
    None => ()
  }
  match regex_group("[?&](p|page_id|database_id)=([0-9a-f]{32})", lower, 2) {
    Some(id) => return Some(format_uuid(id))
    None => ()
  }
  match regex_group("([0-9a-f]{32})", lower, 1) {
    Some(id) => Some(format_uuid(id))
    None => None
  }
}

///|
/// Extracts a database ID from a Notion database URL.
pub fn extract_database_id(database_url : String) -> String? {
  extract_notion_id(database_url)
}

///|
/// Extracts a page ID from a Notion page URL.
pub fn extract_page_id(page_url : String) -> String? {
  extract_notion_id(page_url)
}

///|
/// Extracts a block ID from a Notion URL with a block fragment. Looks for
/// `#block-<id>` or `#<id>` patterns.
pub fn extract_block_id(url_with_block : String) -> String? {
  if url_with_block.is_empty() {
    return None
  }
  match regex_group("#(block-)?([0-9a-f]{32})", url_with_block.to_lower(), 2) {
    Some(id) => Some(format_uuid(id))
    None => None
  }
}

///|
/// Formats a 32-character hex string into a standard UUID.
fn format_uuid(compact_id : String) -> String {
  let clean = compact_id.to_lower()
  clean[:8].to_owned() +
  "-" +
  clean[8:12].to_owned() +
  "-" +
  clean[12:16].to_owned() +
  "-" +
  clean[16:20].to_owned() +
  "-" +
  clean[20:32].to_owned()
}

///|
/// Whether a regular expression matches anywhere in the text.
fn regex_matches(pattern : String, text : String) -> Bool {
  let re = @string.Regex::unsafe_from_string(pattern)
  re.execute(text) is Some(_)
}

///|
/// Returns a capture group from the first match of a regular expression.
fn regex_group(pattern : String, text : String, index : Int) -> String? {
  let re = @string.Regex::unsafe_from_string(pattern)
  match re.execute(text) {
    Some(result) =>
      match result.group(index) {
        Some(value) => Some(value.to_owned())
        None => None
      }
    None => None
  }
}
