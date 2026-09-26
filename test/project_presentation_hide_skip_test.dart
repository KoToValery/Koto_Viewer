import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/project_bundle_service.dart';
import 'package:kotoview/src/features/project_viewer/widgets/project_presentation_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('bg'),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('ProjectPresentationBar Hiding & Skipping UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows slide sequence counter and skips hidden files on Next', (tester) async {
      final f1 = ProjectFileEntry(
        internalPath: '01.mp4',
        fileName: '01.mp4',
        uncompressedSize: 100,
        category: ProjectItemCategory.video,
        fileType: KotoFileType.video,
        presentationOrder: 1,
      );
      final f2 = ProjectFileEntry(
        internalPath: '02.dwg',
        fileName: '02.dwg',
        uncompressedSize: 200,
        category: ProjectItemCategory.drawing,
        fileType: KotoFileType.dwg,
        presentationOrder: 2,
        isHidden: true, // Hidden file
      );
      final f3 = ProjectFileEntry(
        internalPath: '03.glb',
        fileName: '03.glb',
        uncompressedSize: 300,
        category: ProjectItemCategory.model3d,
        fileType: KotoFileType.glb,
        presentationOrder: 3,
      );

      final bundle = ProjectBundleInfo(
        archivePath: 'C:/test/archive.zip',
        projectName: 'Villa Koto',
        totalFiles: 3,
        totalSizeBytes: 600,
        files: [f1, f2, f3],
      );

      int? switchedToIndex;

      await tester.pumpWidget(
        buildTestableWidget(
          ProjectPresentationBar(
            projectBundle: bundle,
            currentIndex: 0,
            onSwitchProjectItem: (idx) {
              switchedToIndex = idx;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On slide 0 (01.mp4), total visible is 2, so counter should show "1 / 2"
      expect(find.textContaining('1 / 2'), findsOneWidget);
      expect(find.text('01.mp4'), findsOneWidget);

      // Press Next button: should skip f2 (index 1) and jump to f3 (index 2)
      final nextButton = find.byTooltip('Следващ файл');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(switchedToIndex, 2);
    });

    testWidgets('displays skipped notification and indicator when previewing a hidden file', (tester) async {
      final f1 = ProjectFileEntry(
        internalPath: '01.mp4',
        fileName: '01.mp4',
        uncompressedSize: 100,
        category: ProjectItemCategory.video,
        fileType: KotoFileType.video,
        presentationOrder: 1,
      );
      final f2 = ProjectFileEntry(
        internalPath: '02.dwg',
        fileName: '02.dwg',
        uncompressedSize: 200,
        category: ProjectItemCategory.drawing,
        fileType: KotoFileType.dwg,
        presentationOrder: 2,
        isHidden: true, // Hidden file
      );

      final bundle = ProjectBundleInfo(
        archivePath: 'C:/test/archive.zip',
        projectName: 'Villa Koto',
        totalFiles: 2,
        totalSizeBytes: 300,
        files: [f1, f2],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          ProjectPresentationBar(
            projectBundle: bundle,
            currentIndex: 1, // Previewing hidden file
            onSwitchProjectItem: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show file name and indicator that it is skipped from presentation
      expect(find.text('02.dwg'), findsOneWidget);
      expect(find.textContaining('Пропуснат от презентацията'), findsOneWidget);
      expect(find.text('Скрит'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    });

    testWidgets('toggling hide button updates file state and saves to preferences', (tester) async {
      final f1 = ProjectFileEntry(
        internalPath: '01.mp4',
        fileName: '01.mp4',
        uncompressedSize: 100,
        category: ProjectItemCategory.video,
        fileType: KotoFileType.video,
        presentationOrder: 1,
        isHidden: false,
      );

      final bundle = ProjectBundleInfo(
        archivePath: 'C:/test/archive.zip',
        projectName: 'Villa Koto',
        totalFiles: 1,
        totalSizeBytes: 100,
        files: [f1],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          ProjectPresentationBar(
            projectBundle: bundle,
            currentIndex: 0,
            onSwitchProjectItem: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially visible
      expect(f1.isHidden, isFalse);
      final hideButton = find.byTooltip('Скрий от презентацията');
      expect(hideButton, findsOneWidget);

      // Tap hide button
      await tester.tap(hideButton);
      await tester.pumpAndSettle();

      // Should now be hidden
      expect(f1.isHidden, isTrue);
      expect(find.textContaining('Пропуснат от презентацията'), findsOneWidget);

      // Verify saved in SharedPreferences
      final savedHidden = await ProjectBundleService.loadHiddenFiles(bundle.archivePath);
      expect(savedHidden.contains('01.mp4'), isTrue);
    });

    testWidgets('Project file item card renders without RenderFlex overflow on narrow screens', (tester) async {
      final item = ProjectFileEntry(
        internalPath: '0.00 Worksheet (7).dwg',
        fileName: '0.00 Worksheet (7).dwg',
        uncompressedSize: 324205,
        category: ProjectItemCategory.drawing,
        fileType: KotoFileType.dwg,
        presentationOrder: 1,
        isHidden: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          SizedBox(
            width: 320,
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 8, right: 4, top: 2, bottom: 2),
                horizontalTitleGap: 8,
                minLeadingWidth: 0,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.visibility_off_rounded, size: 13, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.draw_rounded, color: Colors.teal, size: 20),
                    ),
                  ],
                ),
                title: Text(
                  item.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Builder(
                  builder: (context) => Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: item.formattedSize,
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        const TextSpan(
                          text: ' • ',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        TextSpan(
                          text: item.category.shortLabel,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(
                          text: ' • ',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        TextSpan(
                          text: context.l10n.hiddenInPresentation,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_off_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 28),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 28),
                      onPressed: () {},
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: Icon(Icons.drag_indicator_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0.00 Worksheet (7).dwg'), findsOneWidget);
      expect(find.textContaining('316.6 KB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
