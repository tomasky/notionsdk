///|
/// Logging primitives, ported from `src/logging.ts`.
///
/// The client emits structured messages through a `Logger`. The level filter is
/// numeric so callers can compare severities.

///|
/// Log levels, ordered by severity.
pub(all) enum LogLevel {
  Debug
  Info
  Warn
  Error
}

///|
/// The string form of a log level (`"debug"`, `"info"`, `"warn"`, `"error"`).
pub fn LogLevel::to_string(self : LogLevel) -> String {
  match self {
    Debug => "debug"
    Info => "info"
    Warn => "warn"
    Error => "error"
  }
}

///|
/// Parses a log level from its string form.
pub fn LogLevel::from_string(value : String) -> LogLevel? {
  match value {
    "debug" => Some(Debug)
    "info" => Some(Info)
    "warn" => Some(Warn)
    "error" => Some(Error)
    _ => None
  }
}

///|
/// A logger receives a level, a message, and extra structured information.
pub type Logger = (LogLevel, String, Json) -> Unit

///|
/// A logger that writes to standard output.
pub fn make_console_logger(name : String) -> Logger {
  (level, message, extra_info) => {
    println(
      name +
      " " +
      level.to_string() +
      ": " +
      message +
      " " +
      extra_info.stringify(),
    )
  }
}

///|
/// Transforms a log level into a comparable (numerical) value ordered by
/// severity.
pub fn log_level_severity(level : LogLevel) -> Int {
  match level {
    Debug => 20
    Info => 40
    Warn => 60
    Error => 80
  }
}
