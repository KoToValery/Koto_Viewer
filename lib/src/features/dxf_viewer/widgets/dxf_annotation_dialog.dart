import 'package:flutter/material.dart';
import '../models/dxf_models.dart';

/// Modal dialog for creating or editing a CAD leader annotation note.
class DxfAnnotationDialog extends StatefulWidget {
  final DxfAnnotation? initialAnnotation;
  final Offset arrowTipCad;
  final Offset textPosCad;
  final VoidCallback? onDelete;

  const DxfAnnotationDialog({
    super.key,
    this.initialAnnotation,
    required this.arrowTipCad,
    required this.textPosCad,
    this.onDelete,
  });

  @override
  State<DxfAnnotationDialog> createState() => _DxfAnnotationDialogState();
}

class _DxfAnnotationDialogState extends State<DxfAnnotationDialog> {
  late final TextEditingController _textController;
  late int _selectedColor;

  static const List<int> _availableColors = [
    0xFFFF5252, // Vibrant Red (standard markup)
    0xFFFFD600, // Safety Amber / Yellow
    0xFF00E5FF, // Cyan
    0xFF00E676, // Green
    0xFFFF4081, // Pink / Magenta
    0xFFFFFFFF, // White
  ];

  static const List<String> _quickNotes = [
    'Verify on site',
    'Relocate',
    'Check dimension',
    'Opening / Void',
    'Elevation check',
    'Attention',
    'Approved',
    'Revision',
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialAnnotation?.text ?? '');
    _selectedColor = widget.initialAnnotation?.colorValue ?? _availableColors[0];
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final annotation = DxfAnnotation(
      id: widget.initialAnnotation?.id ?? 'anno_${DateTime.now().millisecondsSinceEpoch}',
      arrowTipCad: widget.arrowTipCad,
      textPosCad: widget.textPosCad,
      text: text,
      colorValue: _selectedColor,
      createdAt: widget.initialAnnotation?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(annotation);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialAnnotation != null;

    return Dialog(
      backgroundColor: const Color(0xFF1B2433),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Color(_selectedColor).withValues(alpha: 0.8), width: 1.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(_selectedColor).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_outward, color: Color(_selectedColor), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Leader Note' : 'Add Leader Annotation',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Arrow pointing to CAD feature with attached note',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Note Text Field
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Enter annotation text or select a preset below...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(_selectedColor), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Preset Chips
            const Text(
              'Quick Presets',
              style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickNotes.map((preset) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _textController.text = preset;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      preset,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Color Selection
            Row(
              children: [
                const Text(
                  'Color:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                ..._availableColors.map((colorVal) {
                  final isSelected = colorVal == _selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorVal;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(colorVal).withValues(alpha: 0.6),
                                  blurRadius: 6,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (isEditing && widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                    tooltip: 'Delete Note',
                    onPressed: () {
                      widget.onDelete!();
                      Navigator.of(context).pop();
                    },
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(isEditing ? 'Update Note' : 'Add Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_selectedColor),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
