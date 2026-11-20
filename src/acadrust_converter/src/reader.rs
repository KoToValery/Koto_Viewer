use acadrust::{
    document::HeaderVariables,
    entities::AttributeEntity,
    objects::{Layout, ObjectType},
    CadDocument, DimStyle, DwgReader, EntityType, Layer, LineType, TextStyle,
};
use serde::Serialize;
use std::{collections::BTreeMap, io::Write, path::Path};

#[derive(Serialize)]
struct NativeBlock<'a> {
    name: &'a str,
    handle: acadrust::Handle,
    base_point: &'a acadrust::Vector3,
    entities: Vec<&'a EntityType>,
}

#[derive(Serialize)]
struct NativeDrawing<'a> {
    protocol: u8,
    source: &'static str,
    header: &'a HeaderVariables,
    layers: Vec<&'a Layer>,
    line_types: Vec<&'a LineType>,
    text_styles: Vec<&'a TextStyle>,
    dim_styles: Vec<&'a DimStyle>,
    blocks: Vec<NativeBlock<'a>>,
    attributes: BTreeMap<String, Vec<&'a AttributeEntity>>,
    layouts: Vec<&'a Layout>,
}

/// In-memory object transport between the native worker and Flutter. This is
/// neither a CAD export nor a persistent cache; no DXF/KCAD writer is involved.
pub fn read_to_writer(input: &Path, output: impl Write) -> Result<(), Box<dyn std::error::Error>> {
    let outcome = DwgReader::from_file(input)?.read_with_stats()?;
    if !outcome.stats.stream_completed
        || outcome.stats.skipped_source_records > 0
        || outcome.stats.recovered_errors > 0
    {
        return Err(format!(
            "DWG decode incomplete: completed={}, skipped={}, recovered={}",
            outcome.stats.stream_completed,
            outcome.stats.skipped_source_records,
            outcome.stats.recovered_errors
        )
        .into());
    }
    write_objects(&outcome.document, output)
}

fn write_objects(
    doc: &CadDocument,
    mut output: impl Write,
) -> Result<(), Box<dyn std::error::Error>> {
    let blocks: Vec<_> = doc
        .block_records
        .iter()
        .map(|block| NativeBlock {
            name: &block.name,
            handle: block.handle,
            base_point: &block.base_point,
            entities: doc.entities_in_block(&block.name).collect(),
        })
        .collect();
    let mut attributes = BTreeMap::<String, Vec<&AttributeEntity>>::new();
    for entity in doc.entities() {
        if let EntityType::AttributeEntity(attribute) = entity {
            attributes
                .entry(attribute.common.owner_handle.value().to_string())
                .or_default()
                .push(attribute);
        }
    }
    let drawing = NativeDrawing {
        protocol: 1,
        source: "DWG",
        header: &doc.header,
        layers: doc.layers.iter().collect(),
        line_types: doc.line_types.iter().collect(),
        text_styles: doc.text_styles.iter().collect(),
        dim_styles: doc.dim_styles.iter().collect(),
        blocks,
        attributes,
        layouts: doc
            .objects
            .values()
            .filter_map(|object| match object {
                ObjectType::Layout(layout) => Some(layout),
                _ => None,
            })
            .collect(),
    };
    // Serialize borrowed objects straight into the transport instead of
    // allocating a second representation of the whole document.
    serde_json::to_writer(&mut output, &drawing)?;
    output.flush()?;
    Ok(())
}
