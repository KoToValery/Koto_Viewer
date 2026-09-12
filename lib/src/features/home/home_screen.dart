import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/services/file_source_service.dart';
import '../../core/services/android_saf_service.dart';
import '../../core/services/dwg_converter_service.dart';
import '../../core/services/file_opener_service.dart';
import '../../core/widgets/coordinate_settings_dialog.dart';
import 'widgets/share_options_sheet.dart';
import 'widgets/app_info_dialog.dart';

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
      case KotoFileType.pptx:        return _buildPptIcon();
      case KotoFileType.rtf:
        return _buildRtfIcon();
      case KotoFileType.eps:
        return _buildEpsIcon();
      case KotoFileType.cdr:
        return _buildCdrIcon();
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
      case KotoFileType.ifc:
      case KotoFileType.fbx:
        return _buildIfcIcon();
      case KotoFileType.threeMf:
        return _buildThreeMfIcon();
      case KotoFileType.zip:
        return _buildZipIcon();
      case KotoFileType.cbz:
      case KotoFileType.cbr:
      case KotoFileType.cbt:
        return _buildComicIcon();
      case KotoFileType.epub:
        return _buildEpubIcon();
      case KotoFileType.fb2:
        return _buildFb2Icon();
      case KotoFileType.gpx:
        return _buildGpxIcon();
      case KotoFileType.kml:
        return _buildKmlIcon();
      case KotoFileType.kmz:
        return _buildKmzIcon();
      case KotoFileType.geojson:
        return _buildGeoJsonIcon();
      case KotoFileType.code:
        return _buildCodeIcon();
      case KotoFileType.lottie:
        return _buildLottieIcon();
      case KotoFileType.font:
        return _buildFontIcon();
      case KotoFileType.ico:
        return _buildIcoIcon();
      case KotoFileType.psd:
        return _buildPsdIcon();
      case KotoFileType.image:
        return _buildImageIcon();
      case KotoFileType.csv:
        return _buildCsvIcon();
      case KotoFileType.jupyter:
        return _buildJupyterIcon();
      case KotoFileType.dicom:
        return _buildDicomIcon();
      default:
        return _buildGenericIcon();
    }
  }

  Widget _buildCsvIcon() {
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
              Icons.grid_on_rounded,
              color: const Color(0xFF16A34A),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'CSV',
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

  Widget _buildJupyterIcon() {
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
              Icons.science_rounded,
              color: const Color(0xFFD97706),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'IPYNB',
              style: TextStyle(
                fontSize: width * 0.16,
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

  Widget _buildDicomIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0EA5E9)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medical_services_outlined,
              color: const Color(0xFF0EA5E9),
              size: width * 0.52,
            ),
            const SizedBox(height: 1),
            Text(
              'DCM',
              style: TextStyle(
                fontSize: width * 0.18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0EA5E9),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code_rounded,
              color: const Color(0xFF94A3B8),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'CODE',
              style: TextStyle(
                fontSize: width * 0.16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLottieIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8B4FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.animation_rounded,
              color: const Color(0xFF9333EA),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'LOTTIE',
              style: TextStyle(
                fontSize: width * 0.14,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF9333EA),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.font_download_rounded,
              color: const Color(0xFF4F46E5),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'FONT',
              style: TextStyle(
                fontSize: width * 0.16,
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

  Widget _buildIcoIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.web_asset_rounded,
              color: const Color(0xFF2563EB),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'ICO',
              style: TextStyle(
                fontSize: width * 0.16,
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

  Widget _buildPsdIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_filter_rounded,
              color: const Color(0xFF7C3AED),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'PSD',
              style: TextStyle(
                fontSize: width * 0.16,
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

  Widget _buildImageIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF472B6)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_rounded,
              color: const Color(0xFFDB2777),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'IMG',
              style: TextStyle(
                fontSize: width * 0.16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFDB2777),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpubIcon() {
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
              Icons.menu_book_rounded,
              color: const Color(0xFFD97706),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'EPUB',
              style: TextStyle(
                fontSize: width * 0.16,
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

  Widget _buildThreeMfIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB2EBF2)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar_rounded,
              color: const Color(0xFF00ACC1),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              '3MF',
              style: TextStyle(
                fontSize: width * 0.18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF00ACC1),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFb2Icon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBCFE8)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_rounded,
              color: const Color(0xFFDB2777),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'FB2',
              style: TextStyle(
                fontSize: width * 0.18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFDB2777),
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComicIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              color: const Color(0xFFE11D48),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'CBZ',
              style: TextStyle(
                fontSize: width * 0.18,
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

  Widget _buildCdrIcon() {
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
              Icons.palette_rounded,
              color: const Color(0xFF16A34A),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'CDR',
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

  Widget _buildIfcIcon() {
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
              Icons.domain_rounded,
              color: const Color(0xFF16A34A),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'IFC',
              style: TextStyle(
                fontSize: width * 0.18,
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

  Widget _buildZipIcon() {
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
              Icons.folder_zip_rounded,
              color: const Color(0xFF059669),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'ZIP',
              style: TextStyle(
                fontSize: width * 0.18,
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

  Widget _buildGpxIcon() {
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
              Icons.terrain_rounded,
              color: const Color(0xFF16A34A),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'GPX',
              style: TextStyle(
                fontSize: width * 0.18,
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

  Widget _buildKmlIcon() {
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
              Icons.route_rounded,
              color: const Color(0xFF0D9488),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'KML',
              style: TextStyle(
                fontSize: width * 0.18,
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

  Widget _buildKmzIcon() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_rounded,
              color: const Color(0xFF2563EB),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'KMZ',
              style: TextStyle(
                fontSize: width * 0.18,
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

  Widget _buildGeoJsonIcon() {
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
              Icons.explore_rounded,
              color: const Color(0xFFEA580C),
              size: width * 0.58,
            ),
            const SizedBox(height: 1),
            Text(
              'GEO',
              style: TextStyle(
                fontSize: width * 0.18,
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
  List<PdfItem> _filteredFiles = [];
  Map<FileCategory, int> _categoryCounts = {};
  bool _isLoading = true;
  FileSourceMode _currentMode = FileSourceMode.recent;
  SortOption _currentSort = SortOption.date;
  String? _customFolderPath;
  List<String> _customFolderList = [];
  Map<String, String> _customFolderNames = {};
  bool _includeSubfolders = false;
  FileCategory _selectedCategory = FileCategory.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFiles();
    RecentFilesService.recentFilesNotifier.addListener(_onRecentFilesChanged);
  }

  void _onRecentFilesChanged() {
    if (mounted) {
      _loadFiles();
    }
  }

  @override
  void dispose() {
    RecentFilesService.recentFilesNotifier.removeListener(_onRecentFilesChanged);
    _searchController.dispose();
    super.dispose();
  }

  int _getCategoryCount(FileCategory cat) {
    return _categoryCounts[cat] ?? 0;
  }

  void _recomputeCategoryCounts() {
    final counts = <FileCategory, int>{
      FileCategory.all: _pdfFiles.length,
    };
    for (final f in _pdfFiles) {
      counts[f.category] = (counts[f.category] ?? 0) + 1;
    }
    _categoryCounts = counts;
  }

  void _updateFilteredFiles() {
    final query = _searchQuery.toLowerCase();
    _filteredFiles = _pdfFiles.where((f) {
      final matchesCategory =
          _selectedCategory == FileCategory.all || f.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          f.name.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    final mode = await FileSourceService.getSourceMode();
    final sort = await FileSourceService.getSortOption();
    final customPath = await FileSourceService.getCustomFolderPath();
    final customFolders = await FileSourceService.getCustomFolderList();
    final customFolderNames = await FileSourceService.getCustomFolderNames();
    final includeSubfolders = await FileSourceService.getIncludeSubfolders();
    final files = await FileSourceService.getPdfFilesForCurrentSource();

    if (mounted) {
      setState(() {
        _currentMode = mode;
        _currentSort = sort;
        _customFolderPath = customPath;
        _customFolderList = customFolders;
        _customFolderNames = customFolderNames;
        _includeSubfolders = includeSubfolders;
        _pdfFiles = files;
        _recomputeCategoryCounts();
        _updateFilteredFiles();
        _isLoading = false;
      });
    }

    _resolveMissingFolderNames(customFolders);
  }

  /// Asynchronously queries Android OS for display names of any folders that
  /// are not yet cached or currently have opaque/ugly internal IDs.
  Future<void> _resolveMissingFolderNames(List<String> folders) async {
    if (folders.isEmpty) return;
    final toResolve = <String>[];
    for (final f in folders) {
      final cached = _customFolderNames[f];
      if (cached == null ||
          cached.trim().isEmpty ||
          AndroidSafService.isOpaqueProviderId(cached)) {
        if (AndroidSafService.isSafUri(f)) {
          toResolve.add(f);
        } else {
          final parts = f
              .split(Platform.pathSeparator)
              .where((s) => s.isNotEmpty)
              .toList();
          final name = parts.isNotEmpty
              ? AndroidSafService.safeDecodeUtf8(parts.last)
              : f;
          _customFolderNames[f] = name;
          await FileSourceService.setCustomFolderName(f, name);
        }
      }
    }

    if (toResolve.isEmpty) return;

    final resolved = await AndroidSafService.getFolderDisplayNames(toResolve);
    bool changed = false;
    for (final entry in resolved.entries) {
      if (entry.value.trim().isNotEmpty &&
          !AndroidSafService.isOpaqueProviderId(entry.value)) {
        _customFolderNames[entry.key] = entry.value.trim();
        changed = true;
      }
    }

    // Fallback query for any still unresolved
    for (final uri in toResolve) {
      final current = _customFolderNames[uri];
      if (current == null ||
          current.trim().isEmpty ||
          AndroidSafService.isOpaqueProviderId(current)) {
        final single = await AndroidSafService.getFolderDisplayName(uri);
        if (single != null &&
            single.trim().isNotEmpty &&
            !AndroidSafService.isOpaqueProviderId(single)) {
          _customFolderNames[uri] = single.trim();
          changed = true;
        } else {
          _customFolderNames[uri] = AndroidSafService.folderNameFromSafUri(uri);
          changed = true;
        }
      }
    }

    if (changed) {
      await FileSourceService.saveCustomFolderNames(_customFolderNames);
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _getFolderName(String path) {
    final cached = _customFolderNames[path];
    if (cached != null &&
        cached.trim().isNotEmpty &&
        !AndroidSafService.isOpaqueProviderId(cached)) {
      return cached;
    }
    if (AndroidSafService.isSafUri(path)) {
      return AndroidSafService.folderNameFromSafUri(path);
    }
    final parts =
        path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? AndroidSafService.safeDecodeUtf8(parts.last) : path;
  }

  String _getFolderSubtitle(String path) {
    if (AndroidSafService.isSafUri(path)) {
      return AndroidSafService.folderSubtitleFromSafUri(path);
    }
    return AndroidSafService.safeDecodeUtf8(path);
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
    final String folderName = _getFolderName(path);

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

  Future<void> _showRenameFolderDialog(String folderPath) async {
    final currentName = _getFolderName(folderPath);
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder display name',
          ),
          onSubmitted: (val) => Navigator.pop(context, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await FileSourceService.setCustomFolderName(folderPath, newName);
      if (mounted) {
        setState(() {
          _customFolderNames[folderPath] = newName;
        });
      }
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
      final String? selectedDirectory;

      if (Platform.isAndroid) {
        // On Android, file_picker's getDirectoryPath() internally converts the
        // SAF tree URI to a real filesystem path via StorageManager reflection.
        // For cloud providers (Google Drive, etc.) this conversion fails and
        // returns "/" — which then causes a Permission Denied error when scanned.
        //
        // We bypass file_picker entirely and launch ACTION_OPEN_DOCUMENT_TREE
        // directly, always receiving the raw SAF tree URI (content://...).
        selectedDirectory = await AndroidSafService.pickDirectory();
      } else {
        final initialDir = await _getDownloadDirectoryPath();
        selectedDirectory = await FilePicker.platform.getDirectoryPath(
          initialDirectory: initialDir,
        );
      }

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        // Safeguard: reject paths that look invalid (e.g. "/" or single-char paths)
        // which can happen if a picker fails silently.
        if (selectedDirectory == '/' || selectedDirectory == '\\') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not access the selected folder. Please try again.'),
              ),
            );
          }
          return false;
        }

        // Resolve human-readable display name immediately
        String? displayName;
        if (AndroidSafService.isSafUri(selectedDirectory)) {
          displayName =
              await AndroidSafService.getFolderDisplayName(selectedDirectory);
          if (displayName == null ||
              displayName.trim().isEmpty ||
              AndroidSafService.isOpaqueProviderId(displayName)) {
            displayName =
                AndroidSafService.folderNameFromSafUri(selectedDirectory);
          }
        } else {
          final parts = selectedDirectory
              .split(Platform.pathSeparator)
              .where((s) => s.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) {
            displayName = AndroidSafService.safeDecodeUtf8(parts.last);
          }
        }

        await FileSourceService.addCustomFolder(
          selectedDirectory,
          displayName: displayName,
        );
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
        if (!FileSourceService.isSupportedFile(filePath)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please select a supported CAD, PCB, 3D, Vector, or Document file.',
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
    await FileOpenerService.openFile(
      context: context,
      filePath: filePath,
    );
    if (mounted) {
      await _loadFiles();
    }
  }

  Future<void> _removeRecentFile(String path) async {
    await RecentFilesService.removeRecentFile(path);
    // Also delete the converted DXF cache so the file is re-converted on next open.
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    if (ext == 'dwg' || ext == 'dxf') {
      await DwgConverterService.clearCacheForFile(path);
    }
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
      // Clear the entire DWG conversion cache so nothing stale remains.
      await DwgConverterService.clearCache();
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
                    'KoTo Viewer is a 100% free app with no ads.',
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
    AppInfoDialog.show(context);
  }

  void _showCoordinateSettings() async {
    await CoordinateSettingsDialog.show(context);
    if (mounted) setState(() {});
  }

  IconData _getCategoryIcon(FileCategory cat) {
    switch (cat) {
      case FileCategory.all:
        return Icons.auto_awesome_mosaic_rounded;
      case FileCategory.cad2d:
        return Icons.draw_rounded;
      case FileCategory.cad3d:
        return Icons.view_in_ar_rounded;
      case FileCategory.pcb:
        return Icons.memory_rounded;
      case FileCategory.routes:
        return Icons.terrain_rounded;
      case FileCategory.documents:
        return Icons.description_rounded;
    }
  }

  Widget _buildCategoryDropdown(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isCustomCategory = _selectedCategory != FileCategory.all;

    return PopupMenuButton<FileCategory>(
      initialValue: _selectedCategory,
      onSelected: (cat) {
        setState(() {
          _selectedCategory = cat;
          _updateFilteredFiles();
        });
      },
      tooltip: 'Filter by category',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isCustomCategory
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCustomCategory
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.dividerColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCategoryIcon(_selectedCategory),
              size: 17,
              color: isCustomCategory
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 85),
              child: Text(
                '${_selectedCategory.shortLabel} (${_getCategoryCount(_selectedCategory)})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCustomCategory
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.textTheme.bodyMedium?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return FileCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          final count = _getCategoryCount(cat);

          return PopupMenuItem<FileCategory>(
            value: cat,
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(cat),
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildSourceHeader(ThemeData theme) {
    String titleText = '';
    String subtitleText = '';

    if (_currentMode == FileSourceMode.recent) {
      titleText = 'Recent Files';
      subtitleText = 'Recently opened files (PDF, DXF, DWG)';
    } else if (_currentMode == FileSourceMode.custom) {
      if (_customFolderPath != null && _customFolderPath!.isNotEmpty) {
        titleText = _getFolderName(_customFolderPath!);
        subtitleText = _getFolderSubtitle(_customFolderPath!);
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
                            children: [
                              Flexible(
                                child: Text(
                                  titleText,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 20),
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
                      final String folderName = _getFolderName(folderPath);
                      final String folderSubtitle = _getFolderSubtitle(folderPath);
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
                                      folderSubtitle,
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
            const SizedBox(width: 8),
            _buildCategoryDropdown(theme),
            PopupMenuButton<SortOption>(
              initialValue: _currentSort,
              onSelected: _switchSort,
              tooltip: 'Sort by',
              icon: const Icon(Icons.sort, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
              // Toggle subfolders
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  _includeSubfolders
                      ? Icons.account_tree_rounded
                      : Icons.account_tree_outlined,
                  size: 20,
                  color: _includeSubfolders
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: _includeSubfolders
                    ? 'Include subfolders: ON'
                    : 'Include subfolders: OFF',
                onPressed: () async {
                  final next = !_includeSubfolders;
                  await FileSourceService.setIncludeSubfolders(next);
                  setState(() => _includeSubfolders = next);
                  await _loadFiles();
                },
              ),
              if (_customFolderPath != null && _customFolderPath!.isNotEmpty) ...[
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.drive_file_rename_outline, size: 20),
                  tooltip: 'Rename Folder',
                  onPressed: () =>
                      _showRenameFolderDialog(_customFolderPath!),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'Remove Folder from list',
                  onPressed: () =>
                      _confirmRemoveCustomFolder(_customFolderPath!),
                ),
              ],
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
                    setState(() {
                      _searchQuery = '';
                      _updateFilteredFiles();
                    });
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
          setState(() {
            _searchQuery = val.trim();
            _updateFilteredFiles();
          });
        },
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
              child: Text('KoToViewer', overflow: TextOverflow.ellipsis),
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
                          'Open Drawings, Models & Documents',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickAndOpenFile,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text(
                                'Browse Files',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_mosaic_rounded,
                                    size: 15,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PDF • DWG • 3D • PCB • Office',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              _buildSourceHeader(theme),
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
                      // For Android SAF content URIs, File.existsSync() always
                      // returns false. Treat them as existing — opening will
                      // copy via ContentResolver and fail gracefully if needed.
                      final fileExists = AndroidSafService.isSafUri(item.path)
                          ? true
                          : File(item.path).existsSync();

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
                    }, childCount: _filteredFiles.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
