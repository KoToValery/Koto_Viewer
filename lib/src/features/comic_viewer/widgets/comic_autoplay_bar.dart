import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/comic_models.dart';

/// Floating HUD and Controls for Comic Autoplay mode.
/// Displays Play/Pause, Next/Prev, Speed/Interval adjustments,
/// Loop toggle, and a real-time countdown progress bar.
class ComicAutoplayBar extends StatelessWidget {
  final bool isPlaying;
  final bool isPaused;
  final bool isPausedForZoom;
  final bool isWebtoon;
  final ComicAutoplayConfig config;
  final ValueNotifier<double> progressNotifier;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggleLoop;
  final ValueChanged<double> onIntervalChanged;
  final ValueChanged<double> onScrollSpeedChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback onClose;

  const ComicAutoplayBar({
    super.key,
    required this.isPlaying,
    required this.isPaused,
    required this.isPausedForZoom,
    required this.isWebtoon,
    required this.config,
    required this.progressNotifier,
    required this.onTogglePlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleLoop,
    required this.onIntervalChanged,
    required this.onScrollSpeedChanged,
    required this.onOpenSettings,
    required this.onClose,
  });

  void _stepInterval(int deltaSeconds) {
    final next = (config.intervalSeconds + deltaSeconds).clamp(2.0, 30.0);
    onIntervalChanged(next);
  }

  void _stepScrollSpeed(int deltaPx) {
    final next = (config.webtoonScrollSpeed + deltaPx).clamp(20.0, 200.0);
    onScrollSpeedChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const accentColor = Color(0xFFE11D48);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: const Color(0xDD18181B), // Dark zinc / charcoal
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPausedForZoom ? Colors.amberAccent.withValues(alpha: 0.6) : Colors.white24,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom Pause Status Banner
              if (isPausedForZoom)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.amber.withValues(alpha: 0.2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.zoom_in, size: 14, color: Colors.amberAccent),
                      const SizedBox(width: 6),
                      Text(
                        l10n.comicAutoplayPausedForZoom,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Controls Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play / Pause Button
                      IconButton(
                        icon: Icon(
                          isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: 26,
                        ),
                        color: accentColor,
                        tooltip: isPaused ? l10n.comicAutoplayResume : l10n.comicAutoplayPause,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: onTogglePlayPause,
                      ),

                      const SizedBox(width: 4),

                      // Previous Page Button (in paged mode)
                      if (!isWebtoon) ...[
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, size: 20),
                          color: Colors.white,
                          tooltip: 'Previous Page',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: onPrevious,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 20),
                          color: Colors.white,
                          tooltip: 'Next Page',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: onNext,
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Speed / Duration stepper chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 14),
                              color: Colors.white70,
                              tooltip: 'Decrease',
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                if (isWebtoon) {
                                  _stepScrollSpeed(-10);
                                } else {
                                  _stepInterval(-1);
                                }
                              },
                            ),
                            InkWell(
                              onTap: onOpenSettings,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  isWebtoon
                                      ? l10n.comicAutoplaySpeedPx(config.webtoonScrollSpeed.round())
                                      : l10n.comicAutoplaySeconds(config.intervalSeconds.round()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 14),
                              color: Colors.white70,
                              tooltip: 'Increase',
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                if (isWebtoon) {
                                  _stepScrollSpeed(10);
                                } else {
                                  _stepInterval(1);
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 4),

                      // Loop Toggle Button
                      IconButton(
                        icon: Icon(
                          config.loop ? Icons.repeat_one_on_rounded : Icons.repeat_rounded,
                          size: 19,
                          color: config.loop ? accentColor : Colors.white60,
                        ),
                        tooltip: l10n.comicAutoplayLoop,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: onToggleLoop,
                      ),

                      // Settings Dialog Button
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 19, color: Colors.white70),
                        tooltip: l10n.comicAutoplaySettings,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: onOpenSettings,
                      ),

                      // Stop / Close Autoplay Button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 19, color: Colors.white54),
                        tooltip: l10n.comicAutoplayStop,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Progress Bar
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, progress, _) {
                    return LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 3.5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isPausedForZoom ? Colors.amberAccent : accentColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet for adjusting comic autoplay settings
/// (page duration, webtoon scroll speed, loop, and pause on zoom).
class ComicAutoplaySettingsSheet extends StatefulWidget {
  final ComicAutoplayConfig initialConfig;
  final bool isWebtoon;
  final ValueChanged<ComicAutoplayConfig> onConfigChanged;

  const ComicAutoplaySettingsSheet({
    super.key,
    required this.initialConfig,
    required this.isWebtoon,
    required this.onConfigChanged,
  });

  @override
  State<ComicAutoplaySettingsSheet> createState() => _ComicAutoplaySettingsSheetState();
}

class _ComicAutoplaySettingsSheetState extends State<ComicAutoplaySettingsSheet> {
  late ComicAutoplayConfig _config;

  static const List<double> _durationPresets = [2, 3, 5, 8, 10, 15, 20, 30];
  static const List<double> _speedPresets = [30, 60, 90, 120, 160];

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  void _update(ComicAutoplayConfig newConfig) {
    setState(() => _config = newConfig);
    widget.onConfigChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const accentColor = Color(0xFFE11D48);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.slideshow_rounded, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.comicAutoplaySettings,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        widget.isWebtoon ? 'Webtoon Scroll Mode' : 'Paged Reading Mode',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24, color: Colors.white12),

            // Page Duration Section (for LTR & Manga)
            if (!widget.isWebtoon) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.comicAutoplayPageDuration,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.comicAutoplaySeconds(_config.intervalSeconds.round()),
                      style: const TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _config.intervalSeconds,
                min: 2.0,
                max: 30.0,
                divisions: 28,
                activeColor: accentColor,
                inactiveColor: Colors.white24,
                onChanged: (val) {
                  _update(_config.copyWith(intervalSeconds: val));
                },
              ),
              Wrap(
                spacing: 8,
                children: _durationPresets.map((preset) {
                  final isSelected = (_config.intervalSeconds - preset).abs() < 0.5;
                  return ChoiceChip(
                    label: Text('${preset.toInt()}s'),
                    selected: isSelected,
                    selectedColor: accentColor,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        _update(_config.copyWith(intervalSeconds: preset));
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Webtoon Scroll Speed Section
            if (widget.isWebtoon) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.comicAutoplayScrollSpeed,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.comicAutoplaySpeedPx(_config.webtoonScrollSpeed.round()),
                      style: const TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _config.webtoonScrollSpeed,
                min: 20.0,
                max: 200.0,
                divisions: 18,
                activeColor: accentColor,
                inactiveColor: Colors.white24,
                onChanged: (val) {
                  _update(_config.copyWith(webtoonScrollSpeed: val));
                },
              ),
              Wrap(
                spacing: 8,
                children: _speedPresets.map((preset) {
                  final isSelected = (_config.webtoonScrollSpeed - preset).abs() < 5;
                  return ChoiceChip(
                    label: Text('${preset.toInt()} px/s'),
                    selected: isSelected,
                    selectedColor: accentColor,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        _update(_config.copyWith(webtoonScrollSpeed: preset));
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            const Divider(height: 16, color: Colors.white12),

            // Loop Toggle Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.comicAutoplayLoop,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Restart from page 1 upon reaching the end',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeThumbColor: accentColor,
              activeTrackColor: accentColor.withValues(alpha: 0.5),
              value: _config.loop,
              onChanged: (val) => _update(_config.copyWith(loop: val)),
            ),

            // Pause on Zoom Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.comicAutoplayPauseOnZoom,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Automatically suspend page turns while inspecting panels zoomed in',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeThumbColor: accentColor,
              activeTrackColor: accentColor.withValues(alpha: 0.5),
              value: _config.pauseOnZoom,
              onChanged: (val) => _update(_config.copyWith(pauseOnZoom: val)),
            ),

            const SizedBox(height: 12),

            // Done Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.ok),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
