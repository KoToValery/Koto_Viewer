import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/services/file_source_service.dart';
import '../../core/services/dwg_converter_service.dart';
import '../../core/services/doc_to_pdf_converter_service.dart';
import '../../core/services/ppt_to_pdf_converter_service.dart';
import '../../core/widgets/coordinate_settings_dialog.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';
import '../dxf_viewer/dxf_viewer_screen.dart';
import '../svg_viewer/svg_viewer_screen.dart';
import '../dxf_3d_viewer/dxf_3d_viewer_screen.dart';
import '../xlsx_viewer/xlsx_viewer_screen.dart';
import '../text_viewer/text_viewer_screen.dart';
import '../markdown_viewer/markdown_viewer_screen.dart';
import '../docx_viewer/docx_viewer_screen.dart';
import '../eps_viewer/eps_viewer_screen.dart';
import '../pcb_viewer/pcb_viewer_screen.dart';
import '../hpgl_viewer/hpgl_viewer_screen.dart';
import 'widgets/share_options_sheet.dart';

class FileTypeIcon extends StatelessWidget {
  final KotoFileType type;
  final double width;
  final double height;

  const FileTypeIcon({
    super.key,
    required this.type,
    this.width = 44,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case KotoFileType.pdf:
        return _buildPdfIcon();
      case KotoFileType.dxf:
        return _buildDxfIcon();
      case KotoFileType.dwg:
        return _buildDwgIcon();
      case KotoFileType.svg:
        return _buildSvgIcon();
      case KotoFileType.stl:
        return _buildStlIcon();
      case KotoFileType.obj:
        return _buildObjIcon();
      case KotoFileType.gltf:
      case KotoFileType.glb:
        return _buildGlbIcon();
      case KotoFileType.xlsx:
        return _buildXlsxIcon();
      case KotoFileType.txt:
        return _buildTxtIcon();
      case KotoFileType.md:
        return _buildMdIcon();
      case KotoFileType.docx:
        return _buildDocxIcon();
      case KotoFileType.pptx:
      case KotoFileType.ppt:
        return _buildPptIcon();
      case KotoFileType.rtf:
        return _buildRtfIcon();
      case KotoFileType.eps:
        return _buildEpsIcon();
      case KotoFileType.gbr:
        return _buildPcbIcon();
      case KotoFileType.drl:
        return _buildDrillIcon();
      case KotoFileType.kicad:
        return _buildKicadIcon();
      case KotoFileType.plt:
        return _buildPltIcon();
      case KotoFileType.step:
        return _buildStepIcon();
      case KotoFileType.iges:
        return _buildIgesIcon();
      case KotoFileType.other:
        return _buildGenericIcon();
    }
  }

  Widget _buildPdfIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              color: const Color(0xFF4F46E5),
              size: width * 0.58,
            ),
            Text(
              'PDF',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4F46E5),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDxfIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.draw_rounded,
              color: const Color(0xFF059669),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'DXF',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF059669),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDwgIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.architecture_rounded,
              color: const Color(0xFFE11D48),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'DWG',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFE11D48),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gesture_rounded,
              color: const Color(0xFFEA580C),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'SVG',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFEA580C),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStlIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5F3FC)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar_rounded,
              color: const Color(0xFF0891B2),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'STL',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0891B2),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_rounded,
              color: const Color(0xFF7C3AED),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'OBJ',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF7C3AED),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlbIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.token_rounded,
              color: const Color(0xFF16A34A),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              '3D',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF16A34A),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXlsxIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_rounded,
              color: const Color(0xFF107C41),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'XLS',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF107C41),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxtIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_rounded,
              color: const Color(0xFF475569),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'TXT',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF475569),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMdIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              color: const Color(0xFF4338CA),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'MD',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4338CA),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocxIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_rounded,
              color: const Color(0xFF2563EB),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'DOC',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2563EB),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPptIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.slideshow_rounded,
              color: const Color(0xFFD24726),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'PPT',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD24726),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRtfIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.text_snippet_rounded,
              color: const Color(0xFF4F46E5),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'RTF',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4F46E5),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpsIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8B4FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gesture_rounded,
              color: const Color(0xFF8B5CF6),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'EPS',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF8B5CF6),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPcbIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.memory_rounded,
              color: const Color(0xFF059669),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'PCB',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF059669),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.adjust_rounded,
              color: const Color(0xFF0D9488),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'DRL',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0D9488),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKicadIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5F3FC)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.developer_board_rounded,
              color: const Color(0xFF0891B2),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'CAD',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0891B2),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPltIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.architecture_rounded,
              color: const Color(0xFFD97706),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'PLT',
              style: TextStyle(
                fontSize: width * 0.2,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD97706),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar_rounded,
              color: const Color(0xFF4F46E5),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'STEP',
              style: TextStyle(
                fontSize: width * 0.18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF4F46E5),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIgesIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar_rounded,
              color: const Color(0xFF7C3AED),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'IGES',
              style: TextStyle(
                fontSize: width * 0.18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF7C3AED),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Icon(
          Icons.insert_drive_file_rounded,
          color: Colors.grey.shade600,
          size: width * 0.6,
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<bool> onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PdfItem> _pdfFiles = [];
  bool _isLoading = true;
  FileSourceMode _currentMode = FileSourceMode.recent;
  SortOption _currentSort = SortOption.date;
  String? _customFolderPath;
  List<String> _customFolderList = [];
  FileCategory _selectedCategory = FileCategory.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getCategoryCount(FileCategory cat) {
    if (cat == FileCategory.all) return _pdfFiles.length;
    return _pdfFiles.where((f) => f.category == cat).length;
  }

  List<PdfItem> get _filteredFiles {
    return _pdfFiles.where((f) {
      final matchesCategory =
          _selectedCategory == FileCategory.all || f.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          f.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    final mode = await FileSourceService.getSourceMode();
    final sort = await FileSourceService.getSortOption();
    final customPath = await FileSourceService.getCustomFolderPath();
    final customFolders = await FileSourceService.getCustomFolderList();
    final files = await FileSourceService.getPdfFilesForCurrentSource();

    if (mounted) {
      setState(() {
        _currentMode = mode;
        _currentSort = sort;
        _customFolderPath = customPath;
        _customFolderList = customFolders;
        _pdfFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchMode(FileSourceMode newMode) async {
    if (newMode == FileSourceMode.custom) {
      if (_customFolderPath == null || _customFolderPath!.isEmpty) {
        if (_customFolderList.isNotEmpty) {
          await FileSourceService.setSelectedCustomFolder(_customFolderList.first);
        } else {
          final success = await _pickCustomFolder();
          if (!success) return;
        }
      } else {
        await FileSourceService.setSourceMode(FileSourceMode.custom);
      }
    } else {
      await FileSourceService.setSourceMode(newMode);
    }

    await _loadFiles();
  }

  Future<void> _selectCustomFolder(String path) async {
    await FileSourceService.setSelectedCustomFolder(path);
    await _loadFiles();
  }

  Future<void> _confirmRemoveCustomFolder(String path) async {
    final parts = path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).toList();
    final folderName = parts.isNotEmpty ? parts.last : path;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Folder'),
        content: Text(
          'Remove "$folderName" from saved folders list?\n\n(The files on your device will NOT be deleted.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FileSourceService.removeCustomFolder(path);
      await _loadFiles();
    }
  }

  Future<void> _switchSort(SortOption newSort) async {
    await FileSourceService.setSortOption(newSort);
    await _loadFiles();
  }

  Future<String?> _getDownloadDirectoryPath() async {
    if (Platform.isAndroid) {
      const androidDownload = '/storage/emulated/0/Download';
      final dir = Directory(androidDownload);
      if (dir.existsSync()) {
        return androidDownload;
      }
    }
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null && dir.existsSync()) {
        return dir.path;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _pickCustomFolder() async {
    try {
      final initialDir = await _getDownloadDirectoryPath();
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        initialDirectory: initialDir,
      );

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        await FileSourceService.addCustomFolder(selectedDirectory);
        await _loadFiles();
        return true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking folder: $e')));
      }
    }

    return false;
  }

  Future<void> _pickAndOpenFile() async {
    try {
      final initialDir = await _getDownloadDirectoryPath();
      // Use FileType.any because Android SAF doesn't register CAD MIME types for DWG/DXF,
      // which causes Android's file picker to grey them out if FileType.custom is used.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        initialDirectory: initialDir,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final lower = filePath.toLowerCase();
        if (!lower.endsWith('.pdf') &&
            !lower.endsWith('.dxf') &&
            !lower.endsWith('.dwg') &&
            !lower.endsWith('.svg') &&
            !lower.endsWith('.stl') &&
            !lower.endsWith('.obj') &&
            !lower.endsWith('.gltf') &&
            !lower.endsWith('.glb') &&
            !lower.endsWith('.xlsx') &&
            !lower.endsWith('.xls') &&
            !lower.endsWith('.txt') &&
            !lower.endsWith('.log') &&
            !lower.endsWith('.csv') &&
            !lower.endsWith('.md') &&
            !lower.endsWith('.markdown') &&
            !lower.endsWith('.docx') &&
            !lower.endsWith('.doc') &&
            !lower.endsWith('.eps') &&
            !lower.endsWith('.gbr') &&
            !lower.endsWith('.ger') &&
            !lower.endsWith('.pho') &&
            !lower.endsWith('.art') &&
            !lower.endsWith('.gtl') &&
            !lower.endsWith('.gbl') &&
            !lower.endsWith('.gts') &&
            !lower.endsWith('.gbs') &&
            !lower.endsWith('.gto') &&
            !lower.endsWith('.gbo') &&
            !lower.endsWith('.gko') &&
            !lower.endsWith('.gm1') &&
            !lower.endsWith('.gm2') &&
            !lower.endsWith('.drl') &&
            !lower.endsWith('.xln') &&
            !lower.endsWith('.exc') &&
            !lower.endsWith('.drd') &&
            !lower.endsWith('.kicad_pcb') &&
            !lower.endsWith('.kicad_sch') &&
            !lower.endsWith('.kicad_sym') &&
            !lower.endsWith('.sch') &&
            !lower.endsWith('.brd') &&
            !lower.endsWith('.plt') &&
            !lower.endsWith('.hpgl') &&
            !lower.endsWith('.hpg') &&
            !lower.endsWith('.prn') &&
            !lower.endsWith('.step') &&
            !lower.endsWith('.stp') &&
            !lower.endsWith('.p21') &&
            !lower.endsWith('.iges') &&
            !lower.endsWith('.igs')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please select a supported file (.pdf, .dxf, .dwg, .svg, .stl, .obj, .glb, .step, .iges, .xlsx, .docx, .eps, .gbr, .drl, .kicad_pcb, .plt).',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        await _openFileScreen(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    }
  }

  Future<void> _openFileScreen(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File does not exist.')));

      if (_currentMode == FileSourceMode.recent) {
        await _removeRecentFile(filePath);
      } else {
        await _loadFiles();
      }

      return;
    }

    final stat = await file.stat();
    final name = filePath.split(Platform.pathSeparator).last;

    final item = PdfItem(
      path: filePath,
      name: name,
      sizeInBytes: stat.size,
      lastOpened: DateTime.now(),
    );

    if (!mounted) return;

    switch (item.fileType) {
      case KotoFileType.pdf:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.dxf:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => DxfViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.dwg:
        // Show converting progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Converting DWG...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Converting DWG to DXF for viewing',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        String? convertedDxfPath;
        String? conversionError;

        try {
          convertedDxfPath = await DwgConverterService.convertDwgToDxf(
            filePath,
          );
        } catch (e) {
          conversionError = e.toString();
        }

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // dismiss dialog
        }

        if (convertedDxfPath != null && mounted) {
          final bool? success = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => DxfViewerScreen(
                filePath: convertedDxfPath!,
                title: name,
              ),
            ),
          );
          if (success != false) {
            await RecentFilesService.addRecentFile(item);
          } else {
            await RecentFilesService.removeRecentFile(filePath);
          }
        } else {
          // Failed to convert: ensure it is not kept in Recent Files
          await RecentFilesService.removeRecentFile(filePath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not convert DWG file: ${conversionError ?? "Unknown error"}',
                ),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        }
        break;

      case KotoFileType.svg:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => SvgViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.stl:
      case KotoFileType.obj:
      case KotoFileType.gltf:
      case KotoFileType.glb:
      case KotoFileType.step:
      case KotoFileType.iges:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => Dxf3DViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.xlsx:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => XlsxViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.txt:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => TextViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.md:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => MarkdownViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.docx:
      case KotoFileType.rtf:
        String viewPath = filePath;
        bool openedAsPdf = false;
        try {
          // Seamless mode: convert DOC/DOCX/RTF to PDF on the fly
          viewPath = await DocToPdfConverterService.convertToPdf(filePath);
          openedAsPdf = true;
        } catch (e) {
          debugPrint('Doc to PDF conversion fallback to docx viewer: $e');
        }

        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => openedAsPdf
                ? PdfViewerScreen(
                    filePath: viewPath,
                    title: item.name,
                  )
                : DocxViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.pptx:
      case KotoFileType.ppt:
        try {
          // Seamless mode: convert PPT/PPTX to Landscape PDF on the fly
          final viewPath = await PptToPdfConverterService.convertToPdf(filePath);
          final bool? success = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                filePath: viewPath,
                title: item.name,
              ),
            ),
          );
          if (success != false) {
            await RecentFilesService.addRecentFile(item);
          } else {
            await RecentFilesService.removeRecentFile(filePath);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load presentation: $e')),
            );
          }
        }
        break;

      case KotoFileType.eps:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => EpsViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.gbr:
      case KotoFileType.drl:
      case KotoFileType.kicad:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => PcbViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.plt:
        final bool? success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => HpglViewerScreen(filePath: filePath),
          ),
        );
        if (success != false) {
          await RecentFilesService.addRecentFile(item);
        } else {
          await RecentFilesService.removeRecentFile(filePath);
        }
        break;

      case KotoFileType.other:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unsupported format.')));
        return;
    }

    await _loadFiles();
  }

  Future<void> _removeRecentFile(String path) async {
    await RecentFilesService.removeRecentFile(path);
    await _loadFiles();
  }

  Future<void> _clearAllRecent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Recent Files'),
        content: const Text(
          'Are you sure you want to clear your recent files history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await RecentFilesService.clearAll();
      await _loadFiles();
    }
  }

  void _showSupportDeveloperDialog() {
    int? selectedIndex = 0;
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double? currentAmount;
          if (selectedIndex == 0) currentAmount = 2.0;
          if (selectedIndex == 1) currentAmount = 5.0;
          if (selectedIndex == 2) currentAmount = 7.0;
          if (selectedIndex == 3) {
            currentAmount = double.tryParse(
              customController.text.replaceAll(',', '.'),
            );
          }

          final bool isButtonEnabled =
              selectedIndex != null &&
              currentAmount != null &&
              currentAmount > 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.favorite, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Support Developer',
                    style: TextStyle(fontSize: 18),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KotoView is a 100% free app with no ads.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  _buildDonateOptionTile(
                    isSelected: selectedIndex == 0,
                    icon: '☕',
                    title: 'A quick coffee',
                    amount: '€2',
                    subtitle: 'To wake up in the morning.',
                    onTap: () => setDialogState(() => selectedIndex = 0),
                  ),
                  const SizedBox(height: 6),
                  _buildDonateOptionTile(
                    isSelected: selectedIndex == 1,
                    icon: '🥐',
                    title: 'Cappuccino with croissant',
                    amount: '€5',
                    subtitle: "So there's no working on an empty stomach.",
                    onTap: () => setDialogState(() => selectedIndex = 1),
                  ),
                  const SizedBox(height: 6),
                  _buildDonateOptionTile(
                    isSelected: selectedIndex == 2,
                    icon: '🍺',
                    title: 'Cold beer after a hard day',
                    amount: '€7',
                    subtitle: 'Because working hard is thirsty business.',
                    onTap: () => setDialogState(() => selectedIndex = 2),
                  ),
                  const SizedBox(height: 6),
                  _buildDonateOptionTile(
                    isSelected: selectedIndex == 3,
                    icon: '🎁',
                    title: 'Custom Amount',
                    amount: selectedIndex == 3 && currentAmount != null
                        ? '€${currentAmount.toStringAsFixed(currentAmount.truncateToDouble() == currentAmount ? 0 : 2)}'
                        : 'Custom',
                    subtitle: 'Because any support is valuable.',
                    onTap: () => setDialogState(() => selectedIndex = 3),
                  ),
                  if (selectedIndex == 3) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Enter amount in € (max 20€)',
                        hintText: 'e.g. 10',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixText: '€',
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(
                          val.replaceAll(',', '.'),
                        );

                        if (parsed != null && parsed > 20) {
                          customController.text = '20';
                          customController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: customController.text.length),
                          );
                        }

                        setDialogState(() {});
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    selectedIndex == null
                        ? 'Select an option above:'
                        : 'Choose a payment method (${currentAmount != null ? "${currentAmount.toStringAsFixed(currentAmount.truncateToDouble() == currentAmount ? 0 : 2)}€" : ""}):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selectedIndex == null
                          ? Colors.deepOrange
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isButtonEnabled
                                ? Colors.black
                                : Colors.grey.shade300,
                            foregroundColor: isButtonEnabled
                                ? Colors.white
                                : Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            Icons.credit_card,
                            size: 18,
                            color: isButtonEnabled
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                          label: const FittedBox(
                            child: Text(
                              'Revolut',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          onPressed: !isButtonEnabled
                              ? null
                              : () async {
                                  final amountStr =
                                      currentAmount!.truncateToDouble() ==
                                          currentAmount
                                      ? currentAmount.toInt().toString()
                                      : currentAmount.toStringAsFixed(2);

                                  final Uri url = Uri.parse(
                                    'https://revolut.me/kostadc1ug/${amountStr}EUR',
                                  );

                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isButtonEnabled
                                ? const Color(0xFF003087)
                                : Colors.grey.shade300,
                            foregroundColor: isButtonEnabled
                                ? Colors.white
                                : Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            Icons.payment,
                            size: 18,
                            color: isButtonEnabled
                                ? Colors.lightBlueAccent
                                : Colors.grey,
                          ),
                          label: const FittedBox(
                            child: Text(
                              'PayPal',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          onPressed: !isButtonEnabled
                              ? null
                              : () async {
                                  final amountStr = currentAmount!
                                      .toStringAsFixed(2);

                                  final Uri url = Uri.parse(
                                    'https://www.paypal.com/donate/?business=kotocadastre@atomicmail.io&amount=$amountStr&currency_code=EUR',
                                  );

                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDonateOptionTile({
    required bool isSelected,
    required String icon,
    required String title,
    required String amount,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE9FE) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'KotoView',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset('assets/icons/app_icon.png', width: 44, height: 44),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'A lightweight, fast, and 100% free open-source PDF and CAD (DXF/DWG) viewer with support for BGS 2005 and global coordinate systems.',
        ),
        const SizedBox(height: 12),
        const Text(
          '• Licensed under GNU General Public License v3.0 (GPLv3)\n'
          '• DWG conversion powered by GNU LibreDWG\n'
          '• 100% free and open-source software (FOSS)',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _showCoordinateSettings() async {
    await CoordinateSettingsDialog.show(context);
    if (mounted) setState(() {});
  }

  Widget _buildSourceHeader(ThemeData theme) {
    String titleText = '';
    String subtitleText = '';

    if (_currentMode == FileSourceMode.recent) {
      titleText = 'Recent Files';
      subtitleText = 'Recently opened files (PDF, DXF, DWG)';
    } else if (_currentMode == FileSourceMode.custom) {
      if (_customFolderPath != null && _customFolderPath!.isNotEmpty) {
        final parts = _customFolderPath!
            .split(Platform.pathSeparator)
            .where((s) => s.isNotEmpty)
            .toList();
        titleText = parts.isNotEmpty ? parts.last : 'Custom Folder';
        subtitleText = _customFolderPath!;
      } else {
        titleText = 'Custom Folder';
        subtitleText = 'No folder selected';
      }
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == '__recent__') {
                    await _switchMode(FileSourceMode.recent);
                  } else if (value == '__add_new__') {
                    await _pickCustomFolder();
                  } else {
                    await _selectCustomFolder(value);
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentMode == FileSourceMode.recent
                          ? Icons.history_rounded
                          : Icons.folder_special_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  titleText,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                          Text(
                            subtitleText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                itemBuilder: (context) {
                  final List<PopupMenuEntry<String>> items = [];

                  // 1. Recent Files
                  items.add(
                    PopupMenuItem<String>(
                      value: '__recent__',
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded, color: Colors.orange),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Recent Files',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (_currentMode == FileSourceMode.recent)
                            Icon(
                              Icons.check,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );

                  items.add(const PopupMenuDivider());

                  // 2. Saved Custom Folders
                  if (_customFolderList.isNotEmpty) {
                    for (final folderPath in _customFolderList) {
                      final parts = folderPath
                          .split(Platform.pathSeparator)
                          .where((s) => s.isNotEmpty)
                          .toList();
                      final folderName =
                          parts.isNotEmpty ? parts.last : folderPath;
                      final isSelected =
                          _currentMode == FileSourceMode.custom &&
                          _customFolderPath == folderPath;

                      items.add(
                        PopupMenuItem<String>(
                          value: folderPath,
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                color: isSelected
                                    ? Colors.purple
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      folderName,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      folderPath,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    }

                    items.add(const PopupMenuDivider());
                  }

                  // 3. Add Custom Folder
                  items.add(
                    const PopupMenuItem<String>(
                      value: '__add_new__',
                      child: Row(
                        children: [
                          Icon(
                            Icons.create_new_folder_outlined,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 12),
                          Text('Add Custom Folder...'),
                        ],
                      ),
                    ),
                  );

                  return items;
                },
              ),
            ),

            PopupMenuButton<SortOption>(
              initialValue: _currentSort,
              onSelected: _switchSort,
              tooltip: 'Sort by',
              icon: const Icon(Icons.sort),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortOption.date,
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        color: _currentSort == SortOption.date
                            ? theme.colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: _currentSort == SortOption.date
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortOption.name,
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_by_alpha,
                        color: _currentSort == SortOption.name
                            ? theme.colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: _currentSort == SortOption.name
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_currentMode == FileSourceMode.custom) ...[
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: 'Add Folder',
                onPressed: _pickCustomFolder,
              ),
              if (_customFolderPath != null && _customFolderPath!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  tooltip: 'Remove Folder from list',
                  onPressed: () =>
                      _confirmRemoveCustomFolder(_customFolderPath!),
                ),
            ],
            if (_currentMode == FileSourceMode.recent && _pdfFiles.isNotEmpty)
              TextButton(
                onPressed: _clearAllRecent,
                child: const Text('Clear'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: FileCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            final count = _getCategoryCount(cat);

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(
                  cat == FileCategory.all
                      ? Icons.auto_awesome_mosaic_rounded
                      : cat == FileCategory.cad2d
                          ? Icons.draw_rounded
                          : cat == FileCategory.cad3d
                              ? Icons.view_in_ar_rounded
                              : cat == FileCategory.pcb
                                  ? Icons.memory_rounded
                                  : Icons.description_rounded,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.primary,
                ),
                label: Text(
                  '${cat.label} ($count)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
                backgroundColor: theme.colorScheme.surface,
                selectedColor: theme.colorScheme.primary,
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.dividerColor.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (_) {
                  setState(() => _selectedCategory = cat);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search in ${_selectedCategory.label}...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (val) {
          setState(() => _searchQuery = val.trim());
        },
      ),
    );
  }

  Widget _buildFormatBadge(String label, IconData icon, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('KotoView', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.public_rounded),
            tooltip: 'Coordinate System Settings',
            onPressed: _showCoordinateSettings,
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Color(0xFF7C3AED)),
            tooltip: 'Support Developer',
            onPressed: _showSupportDeveloperDialog,
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () => widget.onToggleTheme(!widget.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFiles,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Open Documents, CAD & 3D',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select PDF, CAD, 3D, Excel, Text, or Markdown files to view or share.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickAndOpenFile,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text(
                                'Browse Files',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                            _buildFormatBadge('PDF', Icons.picture_as_pdf_rounded, const Color(0xFFC7D2FE)),
                            _buildFormatBadge('CAD', Icons.draw_rounded, const Color(0xFF6EE7B7)),
                            _buildFormatBadge('3D', Icons.view_in_ar_rounded, const Color(0xFFA5F3FC)),
                            _buildFormatBadge('STEP', Icons.layers_rounded, const Color(0xFFC7D2FE)),
                            _buildFormatBadge('PCB', Icons.memory_rounded, const Color(0xFF6EE7B7)),
                            _buildFormatBadge('PLT', Icons.architecture_rounded, const Color(0xFFFDE68A)),
                            _buildFormatBadge('XLSX', Icons.table_chart_rounded, const Color(0xFF86EFAC)),
                            _buildFormatBadge('DOCX', Icons.article_rounded, const Color(0xFF93C5FD)),
                            _buildFormatBadge('EPS', Icons.gesture_rounded, const Color(0xFFD8B4FE)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              _buildSourceHeader(theme),
              SliverToBoxAdapter(child: _buildCategoryFilterBar(theme)),
              if (_pdfFiles.isNotEmpty) SliverToBoxAdapter(child: _buildSearchBar(theme)),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredFiles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(
                          _selectedCategory == FileCategory.all
                              ? Icons.folder_copy_outlined
                              : _selectedCategory == FileCategory.cad2d
                                  ? Icons.draw_outlined
                                  : _selectedCategory == FileCategory.cad3d
                                      ? Icons.view_in_ar_outlined
                                      : _selectedCategory == FileCategory.pcb
                                          ? Icons.memory_outlined
                                          : Icons.description_outlined,
                          size: 64,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching files for "$_searchQuery"'
                              : 'No ${_selectedCategory.label} files found',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 17,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try searching for a different keyword or switch category.'
                              : 'Use "Browse Files" to open or view ${_selectedCategory.label} documents.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                        ),
                        if (_currentMode == FileSourceMode.custom && _searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickCustomFolder,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Select Folder'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = _filteredFiles[index];
                      final fileExists = File(item.path).existsSync();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            onTap: () {
                              if (fileExists) {
                                _openFileScreen(item.path);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'File no longer exists on the device.',
                                    ),
                                  ),
                                );

                                if (_currentMode == FileSourceMode.recent) {
                                  _removeRecentFile(item.path);
                                } else {
                                  _loadFiles();
                                }
                              }
                            },
                            onLongPress: () {
                              if (fileExists) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      ShareOptionsSheet(filePath: item.path),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  FileTypeIcon(type: item.fileType),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${item.formattedSize} • ${dateFormat.format(item.lastOpened)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share_outlined,
                                      size: 22,
                                    ),
                                    tooltip: 'Share',
                                    onPressed: () {
                                      if (fileExists) {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) =>
                                              ShareOptionsSheet(
                                                filePath: item.path,
                                              ),
                                        );
                                      }
                                    },
                                  ),
                                  if (_currentMode == FileSourceMode.recent)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      tooltip: 'Remove from recent',
                                      onPressed: () =>
                                          _removeRecentFile(item.path),
                                    )
                                  else
                                    const Icon(Icons.chevron_right, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }, childCount: _pdfFiles.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
