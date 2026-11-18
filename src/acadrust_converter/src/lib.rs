use acadrust::{CadDocument, DwgReader, DxfVersion, DxfWriter};
use std::{
    fs::File,
    io::{BufWriter, Write},
    path::Path,
};

// Match Uri.encodeComponent and the existing KOTO_DWG_LAYERS reader. In
// particular, separators and non-ASCII layer names must survive the comment.
fn encode_layer_name(name: &str) -> String {
    let mut result = String::new();
    for byte in name.bytes() {
        if byte.is_ascii_alphanumeric() || b"-_.!~*'()".contains(&byte) {
            result.push(byte as char);
        } else {
            use std::fmt::Write;
            write!(result, "%{byte:02X}").unwrap();
        }
    }
    result
}

fn write_document(document: &CadDocument, output: &Path) -> Result<(), Box<dyn std::error::Error>> {
    // R2018 ASCII DXF uses UTF-8, even when the source DWG uses an old codepage.
    let writer = DxfWriter::new(document).with_version(DxfVersion::AC1032);
    let omissions = writer.omitted_architecture_records();
    if !omissions.is_empty() {
        return Err(format!(
            "DXF export would omit {} architecture records",
            omissions.len()
        )
        .into());
    }
    let mut file = BufWriter::new(File::create(output)?);
    write!(file, "999\nKOTO_DWG_LAYERS:")?;
    for (index, layer) in document.layers.iter().enumerate() {
        if index != 0 {
            write!(file, ";")?;
        }
        write!(
            file,
            "{}={}{}",
            encode_layer_name(&layer.name),
            if layer.is_frozen() { "f" } else { "" },
            if layer.is_off() { "-" } else { "+" }
        )?;
    }
    writeln!(
        file,
        "\n999\nKOTO_DWG_CONVERTER:acadrust-{}",
        acadrust::VERSION
    )?;
    writer.write_to_writer(&mut file)?;
    file.flush()?;
    Ok(())
}

pub fn convert(input: &Path, output: &Path) -> Result<(), Box<dyn std::error::Error>> {
    if input == output || (output.exists() && input.canonicalize()? == output.canonicalize()?) {
        return Err("input and output must be different files".into());
    }
    let outcome = DwgReader::from_file(input)?.read_with_stats()?;
    eprintln!(
        "DWG read: {} entities, {} skipped records, {} recovered errors",
        outcome.stats.output_entities,
        outcome.stats.skipped_source_records,
        outcome.stats.recovered_errors
    );
    if !outcome.stats.stream_completed
        || outcome.stats.skipped_source_records > 0
        || outcome.stats.recovered_errors > 0
    {
        return Err("DWG was not read completely; use the fallback converter".into());
    }
    write_document(&outcome.document, output)
}

mod ffi;
mod reader;
pub use reader::read_to_writer;

#[cfg(test)]
mod tests {
    use super::*;
    use acadrust::{DwgWriter, DxfReader, EntityType, Layer, Line, Text};
    use std::{
        env, fs,
        time::{SystemTime, UNIX_EPOCH},
    };

    fn temp_dir() -> std::path::PathBuf {
        let id = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = env::temp_dir().join(format!("koto_acadrust_{}_{id}", std::process::id()));
        fs::create_dir(&dir).unwrap();
        dir
    }

    #[test]
    fn legacy_dwg_preserves_cyrillic_text_geometry_and_layer_states() {
        let dir = temp_dir();
        let input = dir.join("етаж с интервали.dwg");
        let output = dir.join("резултат.dxf");
        let mut document = CadDocument::with_version(DxfVersion::AC1015);
        document.header.code_page = "ANSI_1251".into();
        let mut layer = Layer::new("размери");
        layer.freeze();
        layer.turn_off();
        document.layers.add(layer).unwrap();
        document
            .add_entity(EntityType::Line(Line::from_coords(
                -12.5, 2.0, 0.0, 54.0, 10.0, 0.0,
            )))
            .unwrap();
        let mut text = Text::new();
        text.value = "Кота ±0.00".into();
        text.height = 40.0;
        text.common.layer = "размери".into();
        document.add_entity(EntityType::Text(text)).unwrap();
        DwgWriter::write_to_file(&input, &document).unwrap();
        convert(&input, &output).unwrap();

        let ffi_output = dir.join("Резултат 🏠.dxf");
        let input_utf16: Vec<u16> = input.to_str().unwrap().encode_utf16().collect();
        let output_utf16: Vec<u16> = ffi_output.to_str().unwrap().encode_utf16().collect();
        assert_eq!(
            unsafe {
                crate::ffi::koto_acadrust_convert_utf16(
                    input_utf16.as_ptr(),
                    input_utf16.len(),
                    output_utf16.as_ptr(),
                    output_utf16.len(),
                )
            },
            0
        );
        assert!(fs::read_to_string(&ffi_output)
            .unwrap()
            .contains("Кота ±0.00"));

        let content = fs::read_to_string(&output).unwrap();
        assert!(content.contains("Кота ±0.00"));
        assert!(content.contains(&format!("{}=f-", encode_layer_name("размери"))));
        assert!(content.contains("KOTO_DWG_CONVERTER:acadrust-0.6.8"));
        let read = DxfReader::from_file(&output).unwrap().read().unwrap();
        assert_eq!(read.entities().count(), 2);
        assert!(read.layers.get("размери").unwrap().is_off());
        assert!(read.layers.get("размери").unwrap().is_frozen());
        let line = read
            .entities()
            .find_map(|entity| {
                if let EntityType::Line(line) = entity {
                    Some(line)
                } else {
                    None
                }
            })
            .unwrap();
        assert_eq!(line.start.x, -12.5);
        assert_eq!(line.end.x, 54.0);
        assert!(convert(&input, &input).is_err());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn corrupt_input_does_not_create_output() {
        let dir = temp_dir();
        let input = dir.join("bad.dwg");
        let output = dir.join("bad.dxf");
        fs::write(&input, b"this is not DWG").unwrap();
        assert!(convert(&input, &output).is_err());
        assert!(!output.exists());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn metadata_escapes_delimiters_and_utf8() {
        assert_eq!(encode_layer_name("a;b=c% d"), "a%3Bb%3Dc%25%20d");
        assert_eq!(encode_layer_name("Б"), "%D0%91");
    }
}
