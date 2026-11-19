use acadrust::{DwgReader, DwgWriter, DxfReader, DxfVersion};
use std::io::{Cursor, Read, Write};

pub const MAX_EXCHANGE_BYTES: u64 = 256 * 1024 * 1024;

/// Uses the existing publication geometry as an in-memory CAD exchange stream.
/// Only the final DWG leaves this function; no intermediate CAD file is created.
pub fn write_dwg(input: impl Read, mut output: impl Write) -> Result<(), Box<dyn std::error::Error>> {
    let mut bytes = Vec::new();
    input.take(MAX_EXCHANGE_BYTES + 1).read_to_end(&mut bytes)?;
    if bytes.is_empty() || bytes.len() as u64 > MAX_EXCHANGE_BYTES {
        return Err("CAD export input is empty or exceeds the transport limit".into());
    }
    let outcome = DxfReader::from_reader(Cursor::new(bytes))?.read_with_stats()?;
    if !outcome.stats.stream_completed || outcome.stats.skipped_source_records > 0 || outcome.stats.recovered_errors > 0 {
        return Err(format!("CAD export input incomplete: completed={}, skipped={}, recovered={}",
            outcome.stats.stream_completed, outcome.stats.skipped_source_records,
            outcome.stats.recovered_errors).into());
    }
    let mut document = outcome.document;
    // Modern DWG strings preserve localized layer names and Cyrillic annotations.
    document.version = DxfVersion::AC1032;
    let dwg = DwgWriter::write_to_vec(&document)?;
    if dwg.len() as u64 > MAX_EXCHANGE_BYTES {
        return Err("DWG export exceeds the transport limit".into());
    }
    // Validate the complete binary before publishing even its first byte.
    let check = DwgReader::from_stream(Cursor::new(dwg.as_slice())).read_with_stats()?;
    if !check.stats.stream_completed || check.stats.skipped_source_records > 0 || check.stats.recovered_errors > 0 {
        return Err("DWG writer produced an incomplete drawing".into());
    }
    output.write_all(&dwg)?;
    output.flush()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use acadrust::{CadDocument, DxfWriter, EntityType, Line, Text};

    #[test]
    fn exports_real_dwg_with_geometry_and_unicode_without_intermediate_files() {
        let mut doc = CadDocument::new();
        let mut line = Line::new();
        line.start = acadrust::Vector3::new(12.5, -3.0, 0.0);
        line.end = acadrust::Vector3::new(42.0, 7.0, 0.0);
        doc.add_entity(EntityType::Line(line)).unwrap();
        let mut text = Text::new();
        text.value = "Етаж ±0.00".into();
        text.height = 2.5;
        doc.add_entity(EntityType::Text(text)).unwrap();
        let mut source = Vec::new();
        DxfWriter::new(&doc).write_to_writer(&mut source).unwrap();
        let mut dwg = Vec::new();
        write_dwg(Cursor::new(source), &mut dwg).unwrap();
        assert_eq!(&dwg[..6], b"AC1032");
        let restored = DwgReader::from_stream(Cursor::new(dwg)).read().unwrap();
        assert!(restored.entities().any(|e| matches!(e, EntityType::Text(t) if t.value == "Етаж ±0.00")));
        assert!(restored.entities().any(|e| matches!(e, EntityType::Line(l) if l.start.x == 12.5 && l.end.x == 42.0)));
    }

    #[test]
    fn rejects_invalid_input_before_writing_any_binary() {
        let mut output = Vec::new();
        assert!(write_dwg(Cursor::new(b"not a CAD drawing"), &mut output).is_err());
        assert!(output.is_empty());
    }
}
