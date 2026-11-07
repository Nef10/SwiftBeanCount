#![forbid(unsafe_code)]

use rustledger_booking::{merge_with_padding_spanned, posting_weight};
use rustledger_core::{Directive, MetaValue, Posting};
use rustledger_loader::{
    DiskFileSystem, ErrorSeverity, FileSystem, Ledger as ProcessedLedger, LoadError, LoadOptions,
    Loader, ProcessError, SourceMap, VirtualFileSystem,
};
use rustledger_parser::Spanned;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};

mod authored_options;

uniffi::setup_scaffolding!();

const UPSTREAM_REVISION: &str = "c01a3fbb4316c525db7a18275822ab5b0fceff31";
static NEXT_DOCUMENT_ID: AtomicU64 = AtomicU64::new(1);

#[derive(Debug, Clone, uniffi::Record)]
pub struct SourceFileRecord {
    pub id: u32,
    pub path: String,
    pub content: String,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct MetadataRecord {
    pub key: String,
    pub kind: String,
    pub value: String,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct AmountRecord {
    pub number: String,
    pub currency: String,
    pub scale: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct PostingRecord {
    pub record_id: String,
    pub source_posting_id: String,
    pub source_directive_id: String,
    pub source_file_id: u32,
    pub start_byte: u64,
    pub end_byte: u64,
    pub account: String,
    pub units: Option<AmountRecord>,
    pub has_cost: bool,
    pub cost: Option<AmountRecord>,
    pub cost_is_total: bool,
    pub cost_date: Option<String>,
    pub cost_label: Option<String>,
    pub price: Option<AmountRecord>,
    pub price_is_total: bool,
    pub exact_weight: Option<AmountRecord>,
    pub flag: Option<String>,
    pub metadata: Vec<MetadataRecord>,
    pub synthetic: bool,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct DirectiveRecord {
    pub record_id: String,
    pub kind: String,
    pub source_file_id: u32,
    pub start_byte: u64,
    pub end_byte: u64,
    pub date_year: i32,
    pub date_month: u32,
    pub date_day: u32,
    pub flag: Option<String>,
    pub account: Option<String>,
    pub name: Option<String>,
    pub value: Option<String>,
    pub currency: Option<String>,
    pub booking_method: Option<String>,
    pub allowed_currencies: Vec<String>,
    pub amount: Option<AmountRecord>,
    pub payee: Option<String>,
    pub narration: Option<String>,
    pub tags: Vec<String>,
    pub links: Vec<String>,
    pub metadata: Vec<MetadataRecord>,
    pub custom_values: Vec<MetadataRecord>,
    pub posting_ids: Vec<String>,
    pub synthetic: bool,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct DiagnosticRecord {
    pub phase: String,
    pub severity: String,
    pub code: String,
    pub message: String,
    pub source_file_id: Option<u32>,
    pub start_byte: Option<u64>,
    pub end_byte: Option<u64>,
    pub path: Option<String>,
    pub line: Option<u32>,
    pub column: Option<u32>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct OptionRecord {
    pub name: String,
    pub value: String,
    pub source_file_id: u32,
    pub start_byte: u64,
    pub end_byte: u64,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct PluginRecord {
    pub name: String,
    pub config: Option<String>,
    pub source_file_id: u32,
    pub start_byte: u64,
    pub end_byte: u64,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct LedgerResult {
    pub document_id: String,
    pub engine_revision: String,
    pub sources: Vec<SourceFileRecord>,
    /// One processed balance view, including synthesized padding exactly once.
    pub directives: Vec<DirectiveRecord>,
    pub postings: Vec<PostingRecord>,
    pub diagnostics: Vec<DiagnosticRecord>,
    pub options: Vec<OptionRecord>,
    pub plugins: Vec<PluginRecord>,
}

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum BridgeError {
    #[error("failed to read or process ledger: {message}")]
    Load { message: String },
}

#[uniffi::export]
pub fn load_text(source: String, source_path: Option<String>) -> LedgerResult {
    let path = source_path.unwrap_or_else(|| "/__swiftbeancount_memory__/ledger.beancount".into());
    load_sources(
        vec![SourceFileRecord {
            id: 0,
            path: path.clone(),
            content: source,
        }],
        path,
    )
}

/// Load a complete virtual source tree without consulting disk or retaining a session.
/// Swift can pass back the source snapshots returned by a previous load, with edits
/// applied to the root source, when it needs to rebuild an include-based ledger.
#[uniffi::export]
pub fn load_sources(sources: Vec<SourceFileRecord>, root_path: String) -> LedgerResult {
    let mut fs = VirtualFileSystem::new();
    for source in &sources {
        fs.add_file(&source.path, source.content.clone());
    }
    match rustledger_loader::load_with_fs(
        Path::new(&root_path),
        &LoadOptions::default(),
        Box::new(fs),
    ) {
        Ok(ledger) => result_from_processed(ledger),
        Err(error) => {
            let root_source = sources
                .iter()
                .find(|source| source.path == root_path)
                .or_else(|| sources.first())
                .cloned();
            let mut result = partial_result(
                root_source
                    .as_ref()
                    .map_or_else(String::new, |source| source.content.clone()),
                root_path,
                error.to_string(),
            );
            if let Some(root_source) = root_source {
                if let Some(parsed_root) = result.sources.first_mut() {
                    parsed_root.id = root_source.id;
                }
                result.sources.extend(
                    sources
                        .into_iter()
                        .filter(|source| source.path != root_source.path),
                );
            }
            result
        }
    }
}

#[uniffi::export]
pub fn read_source_files(path: String) -> Result<Vec<SourceFileRecord>, BridgeError> {
    // Resolve includes without booking, plugins, validation, or mapping a ledger
    // that Swift will discard before normalizing the authored source.
    match Loader::new()
        .with_filesystem(Box::new(NoSubprocessFileSystem))
        .load(Path::new(&path))
    {
        Ok(raw) => Ok(sources_from_map(&raw.source_map)),
        Err(
            error @ LoadError::Io {
                include_site: None, ..
            },
        ) => Err(BridgeError::Load {
            message: error.to_string(),
        }),
        // The processed reload remains responsible for reporting load errors.
        // Preserve the root-only snapshot used by load_file's partial fallback.
        Err(_) => std::fs::read_to_string(&path)
            .map(|content| {
                vec![SourceFileRecord {
                    id: 0,
                    path: path.clone(),
                    content,
                }]
            })
            .map_err(|error| BridgeError::Load {
                message: error.to_string(),
            }),
    }
}

#[uniffi::export]
pub fn load_file(path: String) -> Result<LedgerResult, BridgeError> {
    match rustledger_loader::load_with_fs(
        Path::new(&path),
        &LoadOptions::default(),
        Box::new(NoSubprocessFileSystem),
    ) {
        Ok(ledger) => Ok(result_from_processed(ledger)),
        Err(ProcessError::Load(
            error @ LoadError::Io {
                include_site: None, ..
            },
        )) => Err(BridgeError::Load {
            message: error.to_string(),
        }),
        Err(error) => {
            let source = std::fs::read_to_string(&path).map_err(|io_error| BridgeError::Load {
                message: format!("failed to read file {path}: {io_error}"),
            })?;
            Ok(partial_result(source, path, error.to_string()))
        }
    }
}

#[uniffi::export]
pub fn parse_source(source: String) -> LedgerResult {
    let parsed = rustledger_parser::parse(&source);
    let options = parsed
        .options
        .iter()
        .map(|(name, value, span)| OptionRecord {
            name: name.clone(),
            value: value.clone(),
            source_file_id: 0,
            start_byte: span.start as u64,
            end_byte: span.end as u64,
        })
        .collect();
    let plugins = parsed
        .plugins
        .iter()
        .map(|(name, config, span)| PluginRecord {
            name: name.clone(),
            config: config.clone(),
            source_file_id: 0,
            start_byte: span.start as u64,
            end_byte: span.end as u64,
        })
        .collect();
    let mut diagnostics = parsed
        .warnings
        .iter()
        .map(|warning| DiagnosticRecord {
            phase: "parse".into(),
            severity: "warning".into(),
            code: "DEPRECATION".into(),
            message: warning.message.clone(),
            source_file_id: Some(0),
            start_byte: Some(warning.span.start as u64),
            end_byte: Some(warning.span.end as u64),
            path: None,
            line: None,
            column: None,
        })
        .collect::<Vec<_>>();
    diagnostics.extend(parsed.errors.iter().map(|error| DiagnosticRecord {
        phase: "parse".into(),
        severity: "error".into(),
        code: format!("{:?}", error.kind),
        message: error.to_string(),
        source_file_id: Some(0),
        start_byte: Some(error.span.start as u64),
        end_byte: Some(error.span.end as u64),
        path: None,
        line: None,
        column: None,
    }));
    let source_record = SourceFileRecord {
        id: 0,
        path: "<memory>".into(),
        content: source,
    };
    let mut result = result_from_directives(
        "parser-fragment".into(),
        vec![source_record],
        parsed.directives,
        diagnostics,
    );
    result.options = options;
    result.plugins = plugins;
    result
}

fn partial_result(source: String, path: String, message: String) -> LedgerResult {
    let mut result = parse_source(source);
    result.document_id = unique_document_id(&path);
    if let Some(root) = result.sources.first_mut() {
        root.path = path.clone();
    }
    result.diagnostics.push(DiagnosticRecord {
        phase: "load".into(),
        severity: "error".into(),
        code: "LOAD".into(),
        message,
        source_file_id: Some(0),
        start_byte: None,
        end_byte: None,
        path: Some(path),
        line: None,
        column: None,
    });
    result
}

fn result_from_processed(ledger: ProcessedLedger) -> LedgerResult {
    let sources = sources_from_map(&ledger.source_map);
    let diagnostics = ledger
        .errors
        .iter()
        .map(|error| DiagnosticRecord {
            phase: if error.code == "LOAD" {
                "load".into()
            } else {
                error.phase.clone()
            },
            severity: match error.severity {
                ErrorSeverity::Error => "error",
                ErrorSeverity::Warning => "warning",
            }
            .into(),
            code: error.code.clone(),
            message: error.message.clone(),
            source_file_id: error.file_id.map(u32::from),
            start_byte: error.source_span.map(|span| span.0 as u64),
            end_byte: error.source_span.map(|span| span.1 as u64),
            path: error
                .location
                .as_ref()
                .map(|location| location.file.to_string_lossy().into_owned()),
            line: error
                .location
                .as_ref()
                .and_then(|location| u32::try_from(location.line).ok()),
            column: error
                .location
                .as_ref()
                .and_then(|location| u32::try_from(location.column).ok()),
        })
        .collect();
    let options = authored_options::collect(&sources);
    let mut plugins: Vec<_> = ledger
        .plugins
        .iter()
        .map(|plugin| PluginRecord {
            name: if plugin.force_python {
                format!("python:{}", plugin.name)
            } else {
                plugin.name.clone()
            },
            config: plugin.config.clone(),
            source_file_id: u32::try_from(plugin.file_id).unwrap_or(u32::MAX),
            start_byte: plugin.span.start as u64,
            end_byte: plugin.span.end as u64,
        })
        .collect();
    plugins.sort_by_key(|plugin| (plugin.source_file_id, plugin.start_byte));
    let records = map_directives(merge_with_padding_spanned(&ledger.directives));
    LedgerResult {
        document_id: unique_document_id(sources.first().map_or("<empty>", |source| &source.path)),
        engine_revision: UPSTREAM_REVISION.into(),
        sources,
        directives: records.0,
        postings: records.1,
        diagnostics,
        options,
        plugins,
    }
}

fn unique_document_id(path: &str) -> String {
    let generation = NEXT_DOCUMENT_ID.fetch_add(1, Ordering::Relaxed);
    format!("{path}#{generation}")
}

fn result_from_directives(
    document_id: String,
    sources: Vec<SourceFileRecord>,
    directives: Vec<Spanned<Directive>>,
    diagnostics: Vec<DiagnosticRecord>,
) -> LedgerResult {
    let mapped = map_directives(directives);
    LedgerResult {
        document_id: unique_document_id(&document_id),
        engine_revision: UPSTREAM_REVISION.into(),
        sources,
        directives: mapped.0,
        postings: mapped.1,
        diagnostics,
        options: Vec::new(),
        plugins: Vec::new(),
    }
}

fn sources_from_map(map: &SourceMap) -> Vec<SourceFileRecord> {
    map.files()
        .iter()
        .map(|file| SourceFileRecord {
            id: u32::try_from(file.id).unwrap_or(u32::MAX),
            path: file.path.to_string_lossy().into_owned(),
            content: file.source.to_string(),
        })
        .collect()
}

fn map_directives(
    directives: Vec<Spanned<Directive>>,
) -> (Vec<DirectiveRecord>, Vec<PostingRecord>) {
    let mut mapped_directives = Vec::with_capacity(directives.len());
    let mut mapped_postings = Vec::new();
    for (index, spanned) in directives.into_iter().enumerate() {
        let file_id = u32::from(spanned.file_id);
        let start = spanned.span.start as u64;
        let end = spanned.span.end as u64;
        let id = if file_id == u32::from(rustledger_parser::SYNTHESIZED_FILE_ID) {
            format!("synthetic:{index}:{}", spanned.value.type_name())
        } else {
            format!("f{file_id}:{start}:{end}:{}", spanned.value.type_name())
        };
        let date = spanned.value.date();
        let mut record = DirectiveRecord {
            record_id: id.clone(),
            kind: spanned.value.type_name().into(),
            source_file_id: file_id,
            start_byte: start,
            end_byte: end,
            date_year: i32::from(date.year()),
            date_month: date.month() as u32,
            date_day: date.day() as u32,
            flag: None,
            account: None,
            name: None,
            value: None,
            currency: None,
            booking_method: None,
            allowed_currencies: Vec::new(),
            amount: None,
            payee: None,
            narration: None,
            tags: Vec::new(),
            links: Vec::new(),
            metadata: metadata_records(spanned.value.meta()),
            custom_values: Vec::new(),
            posting_ids: Vec::new(),
            synthetic: file_id == u32::from(rustledger_parser::SYNTHESIZED_FILE_ID),
        };
        match &spanned.value {
            Directive::Transaction(transaction) => {
                record.flag = Some(transaction.flag.to_string());
                record.payee = transaction.payee.as_ref().map(ToString::to_string);
                record.narration = Some(transaction.narration.to_string());
                record.tags = transaction.tags.iter().map(ToString::to_string).collect();
                record.tags.sort();
                record.links = transaction.links.iter().map(ToString::to_string).collect();
                record.links.sort();
                for (posting_index, posting) in transaction.postings.iter().enumerate() {
                    let posting_id = format!("{id}-p{posting_index}");
                    record.posting_ids.push(posting_id.clone());
                    mapped_postings.push(posting_record(&id, &posting_id, posting_index, posting));
                }
            }
            Directive::Balance(balance) => {
                record.account = Some(balance.account.to_string());
                record.amount = Some(amount_record(
                    &balance.amount.number,
                    &balance.amount.currency,
                ));
            }
            Directive::Open(open) => {
                record.account = Some(open.account.to_string());
                record.booking_method = open.booking.clone();
                record.allowed_currencies =
                    open.currencies.iter().map(ToString::to_string).collect();
            }
            Directive::Close(close) => record.account = Some(close.account.to_string()),
            Directive::Commodity(commodity) => {
                record.currency = Some(commodity.currency.to_string())
            }
            Directive::Pad(pad) => {
                record.account = Some(pad.account.to_string());
                record.name = Some(pad.source_account.to_string());
            }
            Directive::Event(event) => {
                record.name = Some(event.event_type.clone());
                record.value = Some(event.value.to_string());
            }
            Directive::Query(query) => {
                record.name = Some(query.name.to_string());
                record.value = Some(query.query.to_string());
            }
            Directive::Note(note) => {
                record.account = Some(note.account.to_string());
                record.value = Some(note.comment.to_string());
            }
            Directive::Document(document) => {
                record.account = Some(document.account.to_string());
                record.value = Some(document.path.clone());
            }
            Directive::Price(price) => {
                record.currency = Some(price.currency.to_string());
                record.amount = Some(amount_record(&price.amount.number, &price.amount.currency));
            }
            Directive::Custom(custom) => {
                record.name = Some(custom.custom_type.clone());
                record.custom_values = custom
                    .values
                    .iter()
                    .enumerate()
                    .map(|(index, value)| MetadataRecord {
                        key: index.to_string(),
                        kind: match value {
                            MetaValue::String(_) => "string",
                            MetaValue::Account(_) => "account",
                            MetaValue::Currency(_) => "currency",
                            MetaValue::Tag(_) => "tag",
                            MetaValue::Link(_) => "link",
                            MetaValue::Date(_) => "date",
                            MetaValue::Number(_) => "number",
                            MetaValue::Bool(_) => "bool",
                            MetaValue::Amount(_) => "amount",
                            MetaValue::None => "none",
                            MetaValue::Int(_) => "int",
                        }
                        .into(),
                        value: metadata_value(value),
                    })
                    .collect();
            }
        }
        mapped_directives.push(record);
    }
    (mapped_directives, mapped_postings)
}

fn posting_record(
    directive_id: &str,
    posting_id: &str,
    _posting_index: usize,
    posting: &Spanned<Posting>,
) -> PostingRecord {
    let value = &posting.value;
    let units = value
        .amount()
        .map(|amount| amount_record(&amount.number, &amount.currency));
    let cost_number = value.cost.as_deref().and_then(|cost| {
        cost.number.as_ref().map(|number| match number {
            rustledger_core::CostNumber::PerUnit { value } => (*value, false),
            rustledger_core::CostNumber::Total { value } => (*value, true),
            rustledger_core::CostNumber::PerUnitFromTotal(booked) => (booked.per_unit, false),
            rustledger_core::CostNumber::Compound { per_unit, .. } => (*per_unit, false),
        })
    });
    let cost_is_total = cost_number.is_some_and(|(_, is_total)| is_total);
    let cost = value
        .cost
        .as_deref()
        .and_then(|spec| Some(amount_record(&cost_number?.0, spec.currency.as_deref()?)));
    let cost_date = value
        .cost
        .as_deref()
        .and_then(|cost| cost.date.map(|date| date.to_string()));
    let cost_label = value.cost.as_deref().and_then(|cost| cost.label.clone());
    let price = value
        .price
        .as_deref()
        .and_then(|price| price.amount())
        .map(|amount| amount_record(&amount.number, &amount.currency));
    let price_is_total = value
        .price
        .as_deref()
        .is_some_and(|price| price.kind == rustledger_core::PriceKind::Total);
    let weight =
        posting_weight(value).map(|amount| amount_record(&amount.number, &amount.currency));
    let source_id = format!(
        "f{}:{}:{}:{}",
        posting.file_id, posting.span.start, posting.span.end, value.account
    );
    PostingRecord {
        record_id: posting_id.into(),
        source_posting_id: source_id,
        source_directive_id: directive_id.into(),
        source_file_id: u32::from(posting.file_id),
        start_byte: posting.span.start as u64,
        end_byte: posting.span.end as u64,
        account: value.account.to_string(),
        units,
        has_cost: value.cost.is_some(),
        cost,
        cost_date,
        cost_label,
        price,
        cost_is_total,
        price_is_total,
        exact_weight: weight,
        flag: value.flag.map(|flag| flag.to_string()),
        metadata: metadata_records(&value.meta),
        synthetic: u32::from(posting.file_id) == u32::from(rustledger_parser::SYNTHESIZED_FILE_ID),
    }
}

fn amount_record(number: &rust_decimal::Decimal, currency: &str) -> AmountRecord {
    AmountRecord {
        number: number.to_string(),
        currency: currency.into(),
        scale: number.scale(),
    }
}

fn metadata_records(metadata: &rustledger_core::directive::Metadata) -> Vec<MetadataRecord> {
    metadata
        .iter()
        .map(|(key, value)| MetadataRecord {
            key: key.clone(),
            kind: meta_kind(value).into(),
            value: metadata_value(value),
        })
        .collect()
}

fn metadata_value(value: &MetaValue) -> String {
    match value {
        MetaValue::String(text) => text.clone(),
        _ => value.to_string(),
    }
}

fn meta_kind(value: &MetaValue) -> &'static str {
    match value {
        MetaValue::String(_) => "string",
        MetaValue::Account(_) => "account",
        MetaValue::Currency(_) => "currency",
        MetaValue::Tag(_) => "tag",
        MetaValue::Link(_) => "link",
        MetaValue::Date(_) => "date",
        MetaValue::Number(_) => "number",
        MetaValue::Bool(_) => "bool",
        MetaValue::Amount(_) => "amount",
        MetaValue::None => "none",
        MetaValue::Int(_) => "int",
    }
}

#[derive(Debug)]
struct NoSubprocessFileSystem;

impl FileSystem for NoSubprocessFileSystem {
    fn read(&self, path: &Path) -> Result<std::sync::Arc<str>, LoadError> {
        DiskFileSystem.read(path)
    }

    fn exists(&self, path: &Path) -> bool {
        DiskFileSystem.exists(path)
    }
    fn dir_exists(&self, path: &Path) -> bool {
        DiskFileSystem.dir_exists(path)
    }
    fn is_encrypted(&self, path: &Path) -> bool {
        DiskFileSystem.is_encrypted(path)
    }
    fn normalize(&self, path: &Path) -> std::path::PathBuf {
        DiskFileSystem.normalize(path)
    }
    fn normalize_lexical(&self, path: &Path) -> std::path::PathBuf {
        DiskFileSystem.normalize_lexical(path)
    }
    fn supports_parallel_read(&self) -> bool {
        true
    }
    fn glob(&self, pattern: &str) -> Result<Vec<std::path::PathBuf>, String> {
        DiskFileSystem.glob(pattern)
    }

    fn decrypt(&self, path: &Path) -> Result<std::sync::Arc<str>, LoadError> {
        Err(LoadError::Decryption {
            path: path.to_path_buf(),
            message: "encrypted files are not supported by the native SwiftBeanCount bridge".into(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parser_only_returns_partial_records_and_source_spans() {
        let result =
            parse_source("2024-01-01 * \"x\"\n  Assets:Cash  1.230 USD\n  Equity:Opening\n".into());
        assert_eq!(result.directives.len(), 1);
        assert_eq!(result.postings.len(), 2);
        assert_eq!(
            result.postings[0].units.as_ref().map(|amount| amount.scale),
            Some(3)
        );
        assert_eq!(result.postings[0].start_byte, 17);
    }

    #[test]
    fn full_load_runs_canonical_booking_and_returns_weights() {
        let source = "2024-01-01 open Assets:Cash USD\n2024-01-01 open Equity:Opening USD\n2024-01-02 * \"open\"\n  Assets:Cash  1 USD\n  Equity:Opening  -1 USD\n";
        let result = load_text(source.into(), None);
        assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
        assert!(
            result
                .postings
                .iter()
                .all(|posting| posting.exact_weight.is_some())
        );
    }

    #[test]
    fn balance_view_contains_pad_effect_once_and_keeps_source_pad() {
        let source = "2024-01-01 open Assets:Cash USD\n2024-01-01 open Equity:Opening USD\n2024-01-02 pad Assets:Cash Equity:Opening\n2024-01-03 balance Assets:Cash 10 USD\n";
        let result = load_text(source.into(), None);
        assert!(
            result
                .directives
                .iter()
                .any(|directive| directive.kind == "pad")
        );
        let generated = result
            .directives
            .iter()
            .filter(|directive| directive.synthetic)
            .count();
        assert_eq!(generated, 1);
        assert_eq!(result.postings.len(), 2);
    }

    #[test]
    fn booking_splits_one_source_reduction_into_owned_posting_records() {
        let source = "2024-01-01 open Assets:Stock FIFO\n2024-01-01 open Assets:Cash USD\n2024-01-01 open Income:Gains USD\n2024-01-01 open Equity:Opening USD\n2024-01-02 * \"buy first\"\n  Assets:Stock  1 AAPL {10 USD}\n  Assets:Cash  -10 USD\n2024-01-03 * \"buy second\"\n  Assets:Stock  2 AAPL {20 USD}\n  Assets:Cash  -40 USD\n2024-01-04 * \"sell\"\n  Assets:Stock  -3 AAPL {}\n  Assets:Cash  60 USD\n  Income:Gains  -10 USD\n";
        let result = load_text(source.into(), None);
        let sold = result
            .postings
            .iter()
            .filter(|posting| {
                posting.account == "Assets:Stock"
                    && posting
                        .units
                        .as_ref()
                        .is_some_and(|units| units.number.starts_with('-'))
            })
            .collect::<Vec<_>>();
        assert_eq!(sold.len(), 2, "diagnostics: {:?}", result.diagnostics);
        assert_eq!(sold[0].source_posting_id, sold[1].source_posting_id);
    }

    #[test]
    fn text_metadata_values_remain_unquoted() {
        let result = parse_source("2024-01-01 open Assets:Cash\n2024-01-02 * \"x\"\n  key: \"a\\nb\"\n  Assets:Cash  1 USD\n  Equity:Opening  -1 USD\n".into());
        let value = result
            .directives
            .iter()
            .find(|directive| directive.kind == "transaction")
            .and_then(|directive| {
                directive
                    .metadata
                    .iter()
                    .find(|metadata| metadata.key == "key")
            })
            .map(|metadata| metadata.value.as_str());
        assert_eq!(value, Some("a\nb"));
    }

    #[test]
    fn missing_included_file_is_a_load_diagnostic_with_partial_rust_parse() {
        let source = "include \"missing-include.beancount\"\n2024-01-01 open Assets:Cash USD\n";
        let result = load_text(source.into(), None);
        assert_eq!(result.directives.len(), 1);
        assert!(
            result
                .diagnostics
                .iter()
                .any(|diagnostic| diagnostic.phase == "load"),
            "{:?}",
            result.diagnostics
        );
        assert_eq!(
            result.sources.first().map(|source| source.content.as_str()),
            Some(source)
        );
    }

    #[test]
    fn source_snapshot_reload_keeps_includes_and_adds_root_transactions() {
        let root_path = "/books/main.beancount";
        let root_source = "include \"included.beancount\"\n";
        let included_source = r#"2024-01-01 open Assets:Cash USD
2024-01-01 open Expenses:Food USD
2024-01-02 * "included transaction"
  Assets:Cash  -5 USD
  Expenses:Food  5 USD
"#;

        let memory_only = load_text(root_source.into(), Some(root_path.into()));
        assert!(
            memory_only.diagnostics.iter().any(|diagnostic| {
                diagnostic.phase == "load" && diagnostic.message.contains("included.beancount")
            }),
            "an in-memory root alone cannot resolve an include: {:?}",
            memory_only.diagnostics
        );

        let initial = load_sources(
            vec![
                SourceFileRecord {
                    id: 0,
                    path: root_path.into(),
                    content: root_source.into(),
                },
                SourceFileRecord {
                    id: 1,
                    path: "/books/included.beancount".into(),
                    content: included_source.into(),
                },
            ],
            root_path.into(),
        );
        assert!(initial.diagnostics.is_empty(), "{:?}", initial.diagnostics);
        assert!(initial.directives.iter().any(|directive| {
            directive.kind == "transaction"
                && directive.narration.as_deref() == Some("included transaction")
        }));

        let mut snapshots = initial.sources.clone();
        let root = snapshots
            .iter_mut()
            .find(|source| source.content == root_source)
            .expect("root source snapshot should be returned");
        let root_path = root.path.clone();
        root.content.push_str(
            "2024-01-03 * \"root transaction\"\n  Assets:Cash  -7 USD\n  Expenses:Food  7 USD\n",
        );
        let reloaded = load_sources(snapshots, root_path);
        assert!(
            reloaded.diagnostics.is_empty(),
            "{:?}",
            reloaded.diagnostics
        );
        let narrations = reloaded
            .directives
            .iter()
            .filter(|directive| directive.kind == "transaction")
            .filter_map(|directive| directive.narration.as_deref())
            .collect::<Vec<_>>();
        assert_eq!(narrations, ["included transaction", "root transaction"]);
        assert_eq!(reloaded.sources.len(), 2);
    }

    #[test]
    fn missing_root_file_remains_a_throwing_file_load_error() {
        let path = std::env::temp_dir().join(format!(
            "swiftbeancount-missing-{}.beancount",
            NEXT_DOCUMENT_ID.fetch_add(1, Ordering::Relaxed)
        ));
        let result = load_file(path.to_string_lossy().into_owned());
        assert!(matches!(result, Err(BridgeError::Load { .. })));
        assert!(matches!(
            read_source_files(path.to_string_lossy().into_owned()),
            Err(BridgeError::Load { .. })
        ));
    }

    #[test]
    fn source_discovery_retains_authored_includes_without_running_plugins() {
        let directory = std::env::temp_dir().join(format!(
            "swiftbeancount-sources-{}-{}",
            std::process::id(),
            NEXT_DOCUMENT_ID.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir_all(&directory).unwrap();
        let root = directory.join("root.bean");
        let root_source = "include \"child.bean\"\nplugin \"unavailable.plugin\"\n";
        let child_source = "2024-01-01 open Assets:Cash\n\tlabel: \"é\"\n";
        std::fs::write(&root, root_source).unwrap();
        std::fs::write(directory.join("child.bean"), child_source).unwrap();
        let sources = read_source_files(root.to_string_lossy().into_owned()).unwrap();
        std::fs::remove_dir_all(directory).unwrap();
        assert_eq!(sources.len(), 2);
        assert_eq!(sources[0].content, root_source);
        assert_eq!(sources[1].content, child_source);
        assert_ne!(sources[0].id, sources[1].id);
    }

    #[test]
    fn balance_view_preserves_distinct_locations_for_identical_directives() {
        let price = "2024-01-01 price HOOL 10 USD\n";
        let result = load_text(price.repeat(2), None);
        assert_eq!(result.directives.len(), 2);
        assert_eq!(result.directives[0].start_byte, 0);
        assert_eq!(result.directives[1].start_byte, price.len() as u64);
        assert!(
            result
                .directives
                .iter()
                .all(|directive| !directive.synthetic)
        );
        assert_ne!(
            result.directives[0].record_id,
            result.directives[1].record_id
        );
    }

    #[test]
    fn processed_declarations_preserve_authored_values_order_and_source_spans() {
        let root = "/books/root.bean";
        let result = load_sources(vec![
            SourceFileRecord {
                id: 0, path: root.into(),
                content: "option \"title\" \"Root\\\"quoted\"\noption \"title\" \"Again\"\nplugin \"python:missing.plugin\" \"first\nlast\"\ninclude \"child.bean\"\n".into(),
            },
            SourceFileRecord {
                id: 1, path: "/books/child.bean".into(),
                content: "option \"title\" \"Child\"\nplugin \"beancount.plugins.nounused\"\n2024-01-01 open Assets:Cash\n".into(),
            },
        ], root.into());
        let mut expected_options = Vec::new();
        let mut expected_plugins = Vec::new();
        for file in &result.sources {
            let parsed = rustledger_parser::parse(&file.content);
            expected_options.extend(parsed.options.into_iter().map(|(name, value, span)| {
                (name, value, file.id, span.start as u64, span.end as u64)
            }));
            expected_plugins.extend(parsed.plugins.into_iter().map(|(name, config, span)| {
                (name, config, file.id, span.start as u64, span.end as u64)
            }));
        }
        let actual_options: Vec<_> = result
            .options
            .into_iter()
            .map(|record| {
                (
                    record.name,
                    record.value,
                    record.source_file_id,
                    record.start_byte,
                    record.end_byte,
                )
            })
            .collect();
        let actual_plugins: Vec<_> = result
            .plugins
            .into_iter()
            .map(|record| {
                (
                    record.name,
                    record.config,
                    record.source_file_id,
                    record.start_byte,
                    record.end_byte,
                )
            })
            .collect();
        assert_eq!(actual_options, expected_options);
        assert_eq!(actual_plugins, expected_plugins);
    }

    #[test]
    fn wildcard_tolerance_regression_keeps_the_written_eur_precision() {
        let source = r#"option "inferred_tolerance_default" "*:0.01"
2024-01-01 open Assets:Cash CAD
2024-01-01 open Assets:Stock
2024-01-02 * "purchase"
  Assets:Cash  -135 CAD @ 0.7407 EUR
  Assets:Stock  1 HOOL {100.00 EUR}
"#;
        let result = load_text(source.into(), None);
        assert!(result.diagnostics.is_empty(), "{:?}", result.diagnostics);
        let cash = result
            .postings
            .iter()
            .find(|posting| posting.account == "Assets:Cash")
            .unwrap();
        let stock = result
            .postings
            .iter()
            .find(|posting| posting.account == "Assets:Stock")
            .unwrap();
        assert_eq!(
            cash.exact_weight
                .as_ref()
                .map(|weight| (weight.number.as_str(), weight.currency.as_str())),
            Some(("-99.9945", "EUR"))
        );
        assert_eq!(
            stock
                .exact_weight
                .as_ref()
                .map(|weight| (weight.number.as_str(), weight.currency.as_str())),
            Some(("100.00", "EUR"))
        );
    }

    #[test]
    fn permitted_nonzero_residual_does_not_zero_canonical_weights() {
        let source = r#"2024-01-01 open Assets:Cash USD
2024-01-01 open Expenses:Food USD
2024-01-02 * "within tolerance"
  Assets:Cash  10.00 USD
  Expenses:Food  -9.999 USD
"#;
        let result = load_text(source.into(), None);
        assert!(
            result
                .diagnostics
                .iter()
                .all(|diagnostic| diagnostic.severity != "error"),
            "{:?}",
            result.diagnostics
        );
        let cash = result
            .postings
            .iter()
            .find(|posting| posting.account == "Assets:Cash")
            .unwrap();
        let expense = result
            .postings
            .iter()
            .find(|posting| posting.account == "Expenses:Food")
            .unwrap();
        assert_eq!(
            cash.exact_weight
                .as_ref()
                .map(|weight| weight.number.as_str()),
            Some("10.00")
        );
        assert_eq!(
            expense
                .exact_weight
                .as_ref()
                .map(|weight| weight.number.as_str()),
            Some("-9.999")
        );
    }

    #[test]
    fn zero_cost_and_negative_total_price_use_canonical_signed_weights() {
        let source = r#"2024-01-01 open Assets:Stock
2024-01-01 open Assets:Cash USD
2024-01-02 * "zero cost"
  Assets:Stock  1 AAPL {0 USD}
  Assets:Cash  0 USD
2024-01-03 * "negative total price"
  Assets:Stock  -2 HOOL @@ 20 USD
  Assets:Cash  20 USD
"#;
        let result = load_text(source.into(), None);
        assert!(
            result
                .diagnostics
                .iter()
                .all(|diagnostic| diagnostic.severity != "error"),
            "{:?}",
            result.diagnostics
        );
        let zero = result
            .postings
            .iter()
            .find(|posting| {
                posting.account == "Assets:Stock"
                    && posting
                        .units
                        .as_ref()
                        .is_some_and(|units| units.currency == "AAPL")
            })
            .unwrap();
        let sale = result
            .postings
            .iter()
            .find(|posting| {
                posting.account == "Assets:Stock"
                    && posting
                        .units
                        .as_ref()
                        .is_some_and(|units| units.currency == "HOOL")
            })
            .unwrap();
        assert_eq!(
            zero.cost.as_ref().map(|cost| cost.number.as_str()),
            Some("0")
        );
        assert_eq!(
            zero.exact_weight
                .as_ref()
                .map(|weight| (weight.number.as_str(), weight.currency.as_str())),
            Some(("0", "USD"))
        );
        assert_eq!(
            sale.exact_weight
                .as_ref()
                .map(|weight| (weight.number.as_str(), weight.currency.as_str())),
            Some(("-20", "USD"))
        );
    }

    #[test]
    fn ambiguous_missing_amounts_are_diagnosed_without_fabricated_units() {
        let source = r#"2024-01-01 open Assets:Cash USD
2024-01-01 open Expenses:Food USD
2024-01-01 open Expenses:Fees USD
2024-01-02 * "ambiguous"
  Assets:Cash  -10 USD
  Expenses:Food
  Expenses:Fees
"#;
        let result = load_text(source.into(), None);
        assert!(
            result.diagnostics.iter().any(|diagnostic| {
                diagnostic.code == "BOOK" && diagnostic.message.contains("interpolation failed")
            }),
            "{:?}",
            result.diagnostics
        );
        let unresolved = result
            .postings
            .iter()
            .filter(|posting| posting.account.starts_with("Expenses:"))
            .collect::<Vec<_>>();
        assert_eq!(unresolved.len(), 2);
        assert!(
            unresolved
                .iter()
                .all(|posting| posting.units.is_none() && posting.exact_weight.is_none())
        );
    }

    const SIX_NATIVE_PLUGIN_SOURCE: &str = r#"2024-01-01 commodity AAPL
2024-01-01 open Assets:Investments
2024-01-01 open Assets:Investments:Broker AAPL
2024-01-01 open Assets:Cash USD
2024-01-01 open Assets:Unused USD
2024-01-01 open Assets:Unlisted XYZ
2024-01-01 open Income:Gains USD
2024-01-01 open Equity:Opening USD
2024-01-02 * "buy with cost"
  Assets:Investments:Broker  1 AAPL {10 USD}
  Assets:Cash  -10 USD
2024-01-03 * "buy with price"
  Assets:Investments:Broker  1 AAPL @ 10 USD
  Assets:Cash  -10 USD
2024-01-04 * "mismatched proceeds"
  Assets:Investments:Broker  -1 AAPL {10 USD} @ 12 USD
  Assets:Cash  11 USD
  Income:Gains  -1 USD
2024-01-05 * "post to parent"
  Assets:Investments  1 USD
  Assets:Cash  -1 USD
"#;

    fn with_native_plugins(names: &[&str], source: &str) -> LedgerResult {
        let plugin_directives = names
            .iter()
            .map(|name| format!("plugin \"beancount.plugins.{name}\"\n"))
            .collect::<String>();
        load_text(format!("{plugin_directives}{source}"), None)
    }

    fn has_plugin_diagnostic(result: &LedgerResult, text: &str) -> bool {
        result
            .diagnostics
            .iter()
            .any(|diagnostic| diagnostic.message.contains(text))
    }

    #[test]
    fn six_repository_native_plugins_run_individually_and_together() {
        let cases: [(&str, &str); 6] = [
            ("leafonly", "Non-leaf account 'Assets:Investments'"),
            ("check_commodity", "Missing Commodity directive for 'XYZ'"),
            (
                "coherent_cost",
                "Currency 'AAPL' is used both with and without cost",
            ),
            ("sellgains", "Invalid price vs. proceeds/gains"),
            ("nounused", "Unused account 'Assets:Unused'"),
            ("implicit_prices", ""),
        ];
        for (plugin, message) in cases {
            let result = with_native_plugins(&[plugin], SIX_NATIVE_PLUGIN_SOURCE);
            assert!(
                result
                    .plugins
                    .iter()
                    .any(|record| record.name.ends_with(plugin)),
                "{plugin}: {:?}",
                result.plugins
            );
            if !message.is_empty() {
                assert!(
                    has_plugin_diagnostic(&result, message),
                    "{plugin}: {:?}",
                    result.diagnostics
                );
            } else {
                assert!(
                    result
                        .directives
                        .iter()
                        .any(|directive| directive.kind == "price"),
                    "implicit_prices: {:?}",
                    result.directives
                );
            }
        }

        let names = cases.map(|case| case.0);
        let result = with_native_plugins(&names, SIX_NATIVE_PLUGIN_SOURCE);
        for (_, message) in cases.iter().filter(|case| !case.1.is_empty()) {
            assert!(
                has_plugin_diagnostic(&result, message),
                "expected {message:?}: {:?}",
                result.diagnostics
            );
        }
        assert!(
            result
                .directives
                .iter()
                .any(|directive| directive.kind == "price")
        );
    }

    #[test]
    fn unsupported_external_plugin_reports_error_and_projection_does_not_rerun_plugins() {
        let source = r#"plugin "beancount.plugins.implicit_prices"
2024-01-01 open Assets:Stock
2024-01-01 open Assets:Cash USD
2024-01-02 * "buy"
  Assets:Stock  1 AAPL {10 USD}
  Assets:Cash  -10 USD
"#;
        let first = load_text(source.into(), None);
        let second = load_text(source.into(), None);
        let source_prices = first
            .directives
            .iter()
            .filter(|directive| directive.kind == "price")
            .count();
        assert_eq!(
            source_prices, 1,
            "the single processed view must contain plugin output once"
        );
        assert_eq!(
            second
                .directives
                .iter()
                .filter(|directive| directive.kind == "price")
                .count(),
            source_prices
        );

        let unsupported = load_text(
            "plugin \"beancount.plugins.not_available_here\"\n".into(),
            None,
        );
        assert!(
            unsupported.diagnostics.iter().any(|diagnostic| {
                diagnostic.severity == "error"
                    && diagnostic.phase == "plugin"
                    && diagnostic
                        .message
                        .contains("requires the python-plugins feature")
            }),
            "unsupported plugin was silently ignored: {:?}",
            unsupported.diagnostics
        );
    }
}
