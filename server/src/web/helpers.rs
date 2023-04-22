use chrono::{DateTime, Utc};
use handlebars::handlebars_helper;

handlebars_helper!(strftime: |t: DateTime<Utc>, fmt: String| format!("{}", t.format(&fmt)));
