///|
/// Default base URL for the Notion API.
///
/// Port of `DEFAULT_BASE_URL` from `src/constants.ts`.
pub let default_base_url : String = "https://api.notion.com"

///|
/// Default request timeout in milliseconds (60 seconds).
pub let default_timeout_ms : Int = 60000

///|
/// Default maximum number of retry attempts for failed requests.
pub let default_max_retries : Int = 2

///|
/// Default initial delay between retries in milliseconds (1 second).
/// Used as the base for exponential back-off when the retry-after
/// header is absent.
pub let default_initial_retry_delay_ms : Int = 1000

///|
/// Default maximum delay between retries in milliseconds (60 seconds).
/// Caps both retry-after and exponential back-off delays.
pub let default_max_retry_delay_ms : Int = 60000

///|
/// The minimum width of a view column in pixels, used with the views API to
/// make a property column appear minimal / collapsed in the Notion app UI.
pub let min_view_column_width : Int = 32
