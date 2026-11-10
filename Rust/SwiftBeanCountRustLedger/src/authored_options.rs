use crate::{OptionRecord, SourceFileRecord};
use rustledger_parser::logos_lexer::{Token, tokenize};

/// The loader exposes effective options, but discards their authored order and
/// spans. Locate option declarations with its lexer, then use the canonical
/// parser only on those declarations, never rebuilding the ledger's AST.
pub(super) fn collect(sources: &[SourceFileRecord]) -> Vec<OptionRecord> {
    let mut options = Vec::new();
    for source in sources {
        let tokens = tokenize(&source.content);
        let lines = logical_lines(&tokens, source.content.len());
        let top_level: Vec<_> = lines
            .iter()
            .enumerate()
            .filter_map(|(index, line)| line.2.then_some(index))
            .collect();
        let mut scanned_through = 0;
        for window in tokens.windows(3) {
            let [
                (Token::Option_, keyword),
                (Token::String(_), _),
                (Token::String(_), _),
            ] = window
            else {
                continue;
            };
            if keyword.start < scanned_through {
                continue;
            }
            let line = lines[lines.partition_point(|line| line.0 <= keyword.start) - 1];
            let boundary = top_level.partition_point(|&index| lines[index].0 <= line.0);
            let start = boundary
                .checked_sub(1)
                .map_or(0, |index| lines[top_level[index]].0);
            // Include the next header so the canonical parser attributes trailing
            // comments and metadata exactly as it does in the complete file.
            let end = top_level
                .get(boundary)
                .map_or(source.content.len(), |&index| lines[index].1);
            scanned_through = line.1;
            let parsed = rustledger_parser::parse(&source.content[start..end]);
            options.extend(
                parsed
                    .options
                    .into_iter()
                    .filter_map(|(name, value, span)| {
                        let offset = start + span.start;
                        (offset >= line.0 && offset < line.1).then_some(OptionRecord {
                            name,
                            value,
                            source_file_id: source.id,
                            start_byte: offset as u64,
                            end_byte: (start + span.end) as u64,
                        })
                    }),
            );
        }
    }
    options
}

// Logical lines use lexer newlines, so embedded newlines in quoted strings
// never create false declaration boundaries. Indented candidates retain their
// preceding header: an "option" inside a transaction must stay inside it.
fn logical_lines(
    tokens: &[(Token<'_>, rustledger_parser::logos_lexer::Span)],
    length: usize,
) -> Vec<(usize, usize, bool)> {
    let mut lines = Vec::new();
    let (mut start, mut indented, mut content) = (0, false, false);
    for (token, span) in tokens {
        match token {
            Token::Newline => {
                lines.push((start, span.end, content && !indented));
                (start, indented, content) = (span.end, false, false);
            }
            Token::Indent(_) | Token::DeepIndent(_) => indented = true,
            Token::Comment(_)
            | Token::PercentComment(_)
            | Token::Shebang(_)
            | Token::EmacsDirective(_) => {}
            _ => content = true,
        }
    }
    if start < length {
        lines.push((start, length, content && !indented));
    }
    lines
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn declarations_match_full_parser_with_strings_comments_and_recovery() {
        let fixtures = [
            "",
            "  option \"title\" \"leading indent\"\n",
            "option \"title\" \"first\"\n  note: \"metadata\"\n; comment\noption \"title\" \"second\"\n",
            "2024-01-01 * \"transaction\"\n\n  option \"title\" \"after blank\"\n",
            "option \"title\" \"é\"\noption \"title\" \"second\"",
            "\u{feff}option \"title\" \"BOM\"\r\n; comment\r\noption \"title\" \"CRLF\"\r\n",
            "option \"title\" \"a\\\"b\\\\c\" ; comment\n",
            "option \"title\" \"first\noption \\\"fake\\\" \\\"value\\\"\nlast\"\n",
            "; option \"title\" \"comment\"\n2024-01-01 event \"note\" \"option \\\"fake\\\" \\\"value\\\"\"\noption \"title\" \"real\"\n",
            "2024-01-01 * \"transaction\"\n  option \"title\" \"indented\"\noption \"title\" \"real\"\n",
            "option \"missing\"\noption \"title\" \"recovered\"\n",
            "option \"title\" \"first\" option \"title\" \"second\"\n",
            "option \"title\"\n\"not on the same line\"\n",
        ];
        for content in fixtures {
            let expected = rustledger_parser::parse(content).options;
            let actual = collect(&[SourceFileRecord {
                id: 7,
                path: "test.bean".into(),
                content: content.into(),
            }]);
            let actual: Vec<_> = actual
                .into_iter()
                .map(|record| {
                    assert_eq!(record.source_file_id, 7);
                    (
                        record.name,
                        record.value,
                        record.start_byte as usize,
                        record.end_byte as usize,
                    )
                })
                .collect();
            let expected: Vec<_> = expected
                .into_iter()
                .map(|(name, value, span)| (name, value, span.start, span.end))
                .collect();
            assert_eq!(actual, expected, "source: {content:?}");
        }
    }
}
