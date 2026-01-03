use std::fmt::{self, Write};

use tracing::{Subscriber, span};
use tracing_subscriber::{
    EnvFilter, Layer,
    fmt::{FmtContext, FormatEvent, FormatFields, FormattedFields},
    layer::SubscriberExt,
    registry::LookupSpan,
    util::SubscriberInitExt,
};

pub struct GlacierFormatter {
    display_target: bool,
    display_thread_id: bool,
    display_thread_name: bool,
    display_filename: bool,
    display_line_number: bool,
}

impl Default for GlacierFormatter {
    fn default() -> Self {
        Self {
            display_target: true,
            display_thread_id: false,
            display_thread_name: false,
            display_filename: false,
            display_line_number: false,
        }
    }
}

struct FmtCtx<'a, S, N> {
    ctx: &'a FmtContext<'a, S, N>,
    span: Option<&'a span::Id>,
}

impl<'a, S, N: 'a> FmtCtx<'a, S, N>
where
    S: Subscriber + for<'lookup> LookupSpan<'lookup>,
    N: for<'writer> FormatFields<'writer> + 'static,
{
    pub(crate) fn new(ctx: &'a FmtContext<'_, S, N>, span: Option<&'a span::Id>) -> Self {
        Self { ctx, span }
    }
}

impl<'a, S, N: 'a> fmt::Display for FmtCtx<'a, S, N>
where
    S: Subscriber + for<'lookup> LookupSpan<'lookup>,
    N: for<'writer> FormatFields<'writer> + 'static,
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut seen = false;

        let span = self
            .span
            .and_then(|id| self.ctx.span(id))
            .or_else(|| self.ctx.lookup_current());

        let scope = span.into_iter().flat_map(|span| span.scope().from_root());

        for span in scope {
            seen = true;
            write!(f, "{}:", span.metadata().name())?;
        }

        if seen {
            f.write_char(' ')?;
        }

        Ok(())
    }
}

impl<S, N> FormatEvent<S, N> for GlacierFormatter
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
{
    fn format_event(
        &self,
        ctx: &tracing_subscriber::fmt::FmtContext<'_, S, N>,
        mut writer: tracing_subscriber::fmt::format::Writer<'_>,
        event: &tracing::Event<'_>,
    ) -> std::fmt::Result {
        let metadata = event.metadata();

        if !matches!(metadata.level(), &tracing::Level::INFO) {
            write!(writer, "{} ", metadata.level())?;
        }

        if self.display_thread_name {
            let current_thread = std::thread::current();
            match current_thread.name() {
                Some(name) => {
                    write!(writer, "{} ", name)?;
                }
                None if !self.display_thread_id => {
                    write!(writer, "{:0>2?} ", current_thread.id())?;
                }
                _ => {}
            }
        }

        if self.display_thread_id {
            write!(writer, "{:0>2?} ", std::thread::current().id())?;
        }

        let fmt_ctx = FmtCtx::new(ctx, event.parent());
        write!(writer, "{}", fmt_ctx)?;

        let mut needs_space = false;

        if self.display_target {
            write!(writer, "{}:", metadata.target())?;
            needs_space = true;
        }

        if self.display_filename
            && let Some(filename) = metadata.file()
        {
            if self.display_target {
                writer.write_char(' ')?;
            }
            write!(writer, "{}:", filename)?;
            needs_space = true;
        }

        if self.display_line_number
            && let Some(line_number) = metadata.line()
        {
            write!(writer, "{}:", line_number)?;
            needs_space = true;
        }

        if needs_space {
            writer.write_char(' ')?;
        }

        ctx.format_fields(writer.by_ref(), event)?;

        for span in ctx
            .event_scope()
            .into_iter()
            .flat_map(tracing_subscriber::registry::Scope::from_root)
        {
            let exts = span.extensions();
            if let Some(fields) = exts.get::<FormattedFields<N>>()
                && !fields.is_empty()
            {
                write!(writer, " {}", &fields.fields)?;
            }
        }

        writeln!(writer)
    }
}

pub fn init() {
    let env_filter = EnvFilter::try_from_default_env();

    let stderr_env_filter = env_filter.unwrap_or_else(|_| EnvFilter::new("info"));

    let stderr_layer = tracing_subscriber::fmt::layer()
        .event_format(GlacierFormatter::default())
        .with_writer(std::io::stderr)
        .with_filter(stderr_env_filter);

    tracing_subscriber::registry().with(stderr_layer).init()
}
