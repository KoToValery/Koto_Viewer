import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/services/file_source_service.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final mode = await FileSourceService.getSourceMode();
    final sort = await FileSourceService.getSortOption();
    final customPath = await FileSourceService.getCustomFolderPath();
    final files = await FileSourceService.getPdfFilesForCurrentSource();

    if (mounted) {
      setState(() {
        _currentMode = mode;
        _currentSort = sort;
        _customFolderPath = customPath;
        _pdfFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchMode(FileSourceMode newMode) async {
    if (newMode == FileSourceMode.custom) {
      if (_customFolderPath == null || _customFolderPath!.isEmpty) {
        final success = await _pickCustomFolder();
        if (!success) return;
      }
    }
    await FileSourceService.setSourceMode(newMode);
    await _loadFiles();
  }
  
  Future<void> _switchSort(SortOption newSort) async {
    await FileSourceService.setSortOption(newSort);
    await _loadFiles();
  }

  Future<bool> _pickCustomFolder() async {
    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        await FileSourceService.setCustomFolderPath(selectedDirectory);
        await FileSourceService.setSourceMode(FileSourceMode.custom);
        await _loadFiles();
        return true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking folder: $e')),
        );
      }
    }
    return false;
  }

  Future<void> _pickAndOpenPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        _openPdfScreen(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    }
  }

  void _openPdfScreen(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      final stat = file.statSync();
      final name = filePath.split(Platform.pathSeparator).last;
      await RecentFilesService.addRecentFile(
        PdfItem(
          path: filePath,
          name: name,
          sizeInBytes: stat.size,
          lastOpened: DateTime.now(),
        ),
      );
    }

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(filePath: filePath),
        ),
      );
      _loadFiles();
    }
  }

  Future<void> _removeRecentFile(String path) async {
    await RecentFilesService.removeRecentFile(path);
    _loadFiles();
  }

  Future<void> _clearAllRecent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Recent Files'),
        content: const Text('Are you sure you want to clear your recent files history?'),
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
      _loadFiles();
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
            currentAmount = double.tryParse(customController.text.replaceAll(',', '.'));
          }

          final bool isButtonEnabled = selectedIndex != null &&
              currentAmount != null &&
              currentAmount > 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.favorite, color: Colors.pinkAccent),
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
                    'Koto PDF Viewer is a 100% free app with no ads.',
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
                    subtitle: 'So there\'s no working on an empty stomach.',
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Enter amount in € (max 20€)',
                        hintText: 'e.g. 10',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixText: '€',
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.replaceAll(',', '.'));
                        if (parsed != null && parsed > 20) {
                          customController.text = '20';
                          customController.selection = TextSelection.fromPosition(
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
                      color: selectedIndex == null ? Colors.deepOrange : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isButtonEnabled ? Colors.black : Colors.grey.shade300,
                            foregroundColor: isButtonEnabled ? Colors.white : Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.credit_card, size: 18, color: isButtonEnabled ? Colors.blueAccent : Colors.grey),
                          label: const FittedBox(child: Text('Revolut', style: TextStyle(fontWeight: FontWeight.bold))),
                          onPressed: !isButtonEnabled
                              ? null
                              : () async {
                                  final amountStr = currentAmount!.truncateToDouble() == currentAmount
                                      ? currentAmount.toInt().toString()
                                      : currentAmount.toStringAsFixed(2);
                                  final Uri url = Uri.parse('https://revolut.me/kostadc1ug/${amountStr}EUR');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isButtonEnabled ? const Color(0xFF003087) : Colors.grey.shade300,
                            foregroundColor: isButtonEnabled ? Colors.white : Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.payment, size: 18, color: isButtonEnabled ? Colors.lightBlueAccent : Colors.grey),
                          label: const FittedBox(child: Text('PayPal', style: TextStyle(fontWeight: FontWeight.bold))),
                          onPressed: !isButtonEnabled
                              ? null
                              : () async {
                                  final amountStr = currentAmount!.toStringAsFixed(2);
                                  final Uri url = Uri.parse('https://www.paypal.com/donate/?business=kotocadastre@atomicmail.io&amount=$amountStr&currency_code=EUR');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
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
          color: isSelected ? Colors.pink.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.pinkAccent : Colors.grey.shade300,
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.pinkAccent),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Koto PDF Viewer',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.picture_as_pdf,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'A lightweight, fast, and 100% free PDF viewer designed to complement your mobile apps.',
        ),
      ],
    );
  }

  Widget _buildSourceHeader(ThemeData theme) {
    String subtitleText = '';
    if (_currentMode == FileSourceMode.recent) {
      subtitleText = 'Recently opened PDF files';
    } else if (_currentMode == FileSourceMode.custom) {
      subtitleText = _customFolderPath != null && _customFolderPath!.isNotEmpty
          ? _customFolderPath!
          : 'No folder selected';
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: PopupMenuButton<FileSourceMode>(
                initialValue: _currentMode,
                onSelected: _switchMode,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                  _currentMode.label,
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
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: FileSourceMode.recent,
                    child: Row(
                      children: const [
                        Icon(Icons.history_rounded, color: Colors.orange),
                        SizedBox(width: 12),
                        Text('Recent Files'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: FileSourceMode.custom,
                    child: Row(
                      children: const [
                        Icon(Icons.folder_open_rounded, color: Colors.purple),
                        SizedBox(width: 12),
                        Text('Custom Folder'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Sort Button
            PopupMenuButton<SortOption>(
              initialValue: _currentSort,
              onSelected: _switchSort,
              tooltip: 'Sort by',
              icon: const Icon(Icons.sort),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortOption.date,
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range, 
                        color: _currentSort == SortOption.date ? theme.colorScheme.primary : Colors.grey
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: _currentSort == SortOption.date ? FontWeight.bold : FontWeight.normal
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
                        color: _currentSort == SortOption.name ? theme.colorScheme.primary : Colors.grey
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: _currentSort == SortOption.name ? FontWeight.bold : FontWeight.normal
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_currentMode == FileSourceMode.custom)
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: 'Change Folder',
                onPressed: _pickCustomFolder,
              ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Koto PDF Viewer',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            tooltip: 'Support Developer',
            onPressed: _showSupportDeveloperDialog,
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
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
              // Hero Action Section
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
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Open PDF Document',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select any PDF file from your phone storage to view immediately.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickAndOpenPdf,
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
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // File Source Selector Header
              _buildSourceHeader(theme),

              // PDF Files List or Empty State
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_pdfFiles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 64,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentMode == FileSourceMode.custom && (_customFolderPath == null || _customFolderPath!.isEmpty)
                              ? 'No folder selected'
                              : 'No PDF files found',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentMode == FileSourceMode.custom
                                  ? 'Tap the folder icon to select a directory.'
                                  : 'Recently opened PDF files will appear here.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_currentMode == FileSourceMode.custom) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickCustomFolder,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Select Folder'),
                          ),
                        ]
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _pdfFiles[index];
                        final fileExists = File(item.path).existsSync();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 44,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade100),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.red.shade400,
                                    size: 28,
                                  ),
                                ),
                              ),
                              title: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${item.formattedSize} • ${dateFormat.format(item.lastOpened)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ),
                              trailing: _currentMode == FileSourceMode.recent
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      tooltip: 'Remove from recent',
                                      onPressed: () => _removeRecentFile(item.path),
                                    )
                                  : const Icon(Icons.chevron_right, size: 20),
                              onTap: () {
                                if (fileExists) {
                                  _openPdfScreen(item.path);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('File no longer exists on the device.'),
                                    ),
                                  );
                                  if (_currentMode == FileSourceMode.recent) {
                                    _removeRecentFile(item.path);
                                  } else {
                                    _loadFiles();
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                      childCount: _pdfFiles.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
