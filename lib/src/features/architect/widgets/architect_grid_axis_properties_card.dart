// === SECTION: TABLE OF CONTENTS ===
// 1. IMPORTS & DEFINITIONS
// 2. ARCHITECT GRID AXIS PROPERTIES CARD (WIDGET)
// ===================================

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_grid_axis.dart';

// === SECTION: ARCHITECT GRID AXIS PROPERTIES CARD ===

/// Floating inspector dock card displayed when a grid axis is selected.
/// Provides direct actions for duplicating with offset, auto-aligning and deleting.
class ArchitectGridAxisPropertiesCard extends StatelessWidget {
  final StructuralGridAxis axis;
  final VoidCallback onOffset;
  final VoidCallback onAlign;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const ArchitectGridAxisPropertiesCard({
    super.key,
    required this.axis,
    required this.onOffset,
    required this.onAlign,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const primaryColor = Color(0xFFFF9F0A);
    final orientationLabel = axis.isVertical
        ? l10n.architectAxisOrientationV
        : l10n.architectAxisOrientationH;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFA1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Header (Badge, Title, Subtitle, Close Button)
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.gridAxisTitle(axis.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '•  L = ${axis.formattedLengthMeters}  •  $orientationLabel',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Actions Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Action 1: Duplicate with Offset
                  _buildActionButton(
                    icon: Icons.straighten_rounded,
                    label: l10n.offsetAction,
                    color: const Color(0xFF00E5FF),
                    onTap: onOffset,
                  ),
                  const SizedBox(width: 8),

                  // Action 2: Align Extents with Parallel Axes
                  _buildActionButton(
                    icon: Icons.vertical_align_center_rounded,
                    label: l10n.alignGridAxisAction,
                    color: const Color(0xFF4CAF50),
                    onTap: onAlign,
                  ),
                  const SizedBox(width: 8),

                  // Action 4: Delete
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.deleteGridAxis,
                    color: const Color(0xFFFF5252),
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
