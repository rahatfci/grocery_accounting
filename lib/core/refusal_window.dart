/// How long a write is awaited before the screen treats it as done and closes.
///
/// With persistence on, a write is durably queued the moment it is made and
/// the local cache reacts at once, but the future only completes when the
/// server acknowledges it, which offline never happens. A refusal the server
/// does send arrives in milliseconds, and this window only exists to catch it
/// while the screen is still open.
const refusalWindow = Duration(milliseconds: 600);
