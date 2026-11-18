use acadrust::{CadDocument, DwgReader, EntityType};
use serde::Serialize;
use std::{io::Write, path::Path};

#[derive(Serialize)]
struct NativeBlock<'a> {
    name: &'a str,
    handle: acadrust::Handle,
    base_point: &'a acadrust::Vector3,
    entities: Vec<&'a EntityType>,
}

/// In-memory object transport between the native worker and Flutter. This is
/// neither a CAD export nor a persistent cache; no DXF/KCAD writer is involved.
pub fn read_to_writer(input: &Path, output: impl Write) -> Result<(), Box<dyn std::error::Error>> {
    let outcome = DwgReader::from_file(input)?.read_with_stats()?;
    if !outcome.stats.stream_completed || outcome.stats.skipped_source_records > 0 || outcome.stats.recovered_errors > 0 {
        return Err(format!("DWG decode incomplete: completed={}, skipped={}, recovered={}",
            outcome.stats.stream_completed, outcome.stats.skipped_source_records,
            outcome.stats.recovered_errors).into());
    }
    write_objects(&outcome.document, output)
}

fn write_objects(doc: &CadDocument, mut output: impl Write) -> Result<(), Box<dyn std::error::Error>> {
    let blocks: Vec<_> = doc.block_records.iter().map(|block| NativeBlock {
        name: &block.name,
        handle: block.handle,
        base_point: &block.base_point,
        entities: doc.entities_in_block(&block.name).collect(),
    }).collect();
    let mut attributes = std::collections::BTreeMap::<String, Vec<&acadrust::entities::AttributeEntity>>::new();
    for entity in doc.entities() {
        if let EntityType::AttributeEntity(attribute) = entity {
            attributes.entry(attribute.common.owner_handle.value().to_string()).or_default().push(attribute);
        }
    }
    let objects = serde_json::json!({
        "protocol": 1,
        "source": "DWG",
        "header": doc.header,
        "layers": doc.layers.iter().collect::<Vec<_>>(),
        "line_types": doc.line_types.iter().collect::<Vec<_>>(),
        "text_styles": doc.text_styles.iter().collect::<Vec<_>>(),
        "dim_styles": doc.dim_styles.iter().collect::<Vec<_>>(),
        "blocks": blocks,
        "attributes": attributes,
        "layouts": doc.objects.values().filter_map(|object| match object {
            acadrust::objects::ObjectType::Layout(layout) => Some(layout),
            _ => None,
        }).collect::<Vec<_>>(),
    });
    serde_json::to_writer(&mut output, &objects)?;
    output.flush()?;
    Ok(())
}
