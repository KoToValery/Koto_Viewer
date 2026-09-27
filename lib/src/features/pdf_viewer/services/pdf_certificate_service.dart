import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_certificate_models.dart';

class PdfCertificateService {
  /// Quick check if the PDF contains any digital signatures or signature fields.
  static Future<bool> hasSignatures(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // 1. Check with syncfusion
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      for (int i = 0; i < doc.form.fields.count; i++) {
        if (doc.form.fields[i] is PdfSignatureField) {
          doc.dispose();
          return true;
        }
      }
      doc.dispose();

      // 2. Check for signature dictionary in PDF byte stream
      return _containsSigDictionary(bytes);
    } catch (e) {
      debugPrint('PdfCertificateService.hasSignatures error: $e');
      return false;
    }
  }

  /// Extracts all digital signature and certificate details from a PDF file.
  static Future<List<PdfCertificateInfo>> extractCertificates(String filePath) async {
    final results = <PdfCertificateInfo>[];
    try {
      final file = File(filePath);
      if (!await file.exists()) return results;
      final bytes = await file.readAsBytes();

      // 1. Check for standard /Type /Sig dictionaries in the PDF byte stream
      final sigDicts = _findSignatureDictionaries(bytes);
      for (final dict in sigDicts) {
        results.add(dict);
      }

      // 2. Check for PdfSignatureField in document form fields
      try {
        final doc = PdfDocument(inputBytes: bytes);
        for (int i = 0; i < doc.form.fields.count; i++) {
          final field = doc.form.fields[i];
          if (field is PdfSignatureField) {
            final fieldName = field.name ?? 'Signature';
            // Only add if not already captured by the raw dictionary scanner
            final alreadyPresent = results.any((r) =>
                (r.signerName != null && fieldName.contains(r.signerName!)) ||
                (r.reason != null && field.tooltip == r.reason));
            if (!alreadyPresent) {
              results.add(PdfCertificateInfo(
                signerName: fieldName,
                reason: field.tooltip,
                hasSignatureField: true,
              ));
            }
          }
        }
        doc.dispose();
      } catch (e) {
        debugPrint('PdfDocument signature fields scan error: $e');
      }

      return results;
    } catch (e, stack) {
      debugPrint('PdfCertificateService.extractCertificates error: $e\n$stack');
      return results;
    }
  }

  /// Inspects an external certificate file (.cer, .crt, .pfx, .p12).
  static Future<PdfCertificateInfo?> readExternalCertificate(
    Uint8List bytes, {
    String? password,
  }) async {
    // 1. Try PFX / PKCS#12 if password is provided or file could be PKCS#12
    if (password != null) {
      try {
        final cert = PdfCertificate(bytes, password);
        return PdfCertificateInfo(
          signerName: cert.subjectName,
          issuerName: cert.issuerName,
          serialNumber: cert.serialNumber.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':'),
          validFrom: cert.validFrom,
          validTo: cert.validTo,
          hasSignatureField: false,
        );
      } catch (e) {
        debugPrint('PdfCertificate PFX load error: $e');
      }
    }

    // 2. Check for PEM format (-----BEGIN CERTIFICATE-----)
    try {
      final text = latin1.decode(bytes);
      if (text.contains('-----BEGIN CERTIFICATE-----')) {
        final base64Str = text
            .replaceAll('-----BEGIN CERTIFICATE-----', '')
            .replaceAll('-----END CERTIFICATE-----', '')
            .replaceAll(RegExp(r'\s+'), '');
        final derBytes = base64Decode(base64Str);
        return _parseX509Der(Uint8List.fromList(derBytes));
      }
    } catch (_) {}

    // 3. Try parsing as raw DER
    return _parseX509Der(bytes);
  }

  static bool _containsSigDictionary(Uint8List bytes) {
    final latin = latin1.decode(bytes);
    return latin.contains('/Type /Sig') ||
        latin.contains('/Type/Sig') ||
        latin.contains('/SubFilter /adbe.pkcs7') ||
        latin.contains('/SubFilter/adbe.pkcs7') ||
        latin.contains('/SubFilter /ETSI.CAdES') ||
        latin.contains('/SubFilter/ETSI.CAdES');
  }

  /// Scans the raw PDF byte stream for signature dictionaries.
  static List<PdfCertificateInfo> _findSignatureDictionaries(Uint8List bytes) {
    final results = <PdfCertificateInfo>[];
    final latin = latin1.decode(bytes);

    final pattern = RegExp(
      r'<<[^>]*?/Type\s*/Sig[^>]*?>>',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = pattern.allMatches(latin);
    for (final match in matches) {
      final dictText = match.group(0)!;
      final signerName = _extractPdfString(dictText, 'Name');
      final reason = _extractPdfString(dictText, 'Reason');
      final location = _extractPdfString(dictText, 'Location');
      final contactInfo = _extractPdfString(dictText, 'ContactInfo');
      final filter = _extractPdfName(dictText, 'Filter');
      final subFilter = _extractPdfName(dictText, 'SubFilter');
      final signDate = _extractPdfDate(dictText, 'M');

      // Attempt to extract X.509 certificate data from /Contents <hex...>
      String? issuerName;
      String? certSubject;
      DateTime? validFrom;
      DateTime? validTo;
      String? serialNumber;

      final contentsMatch = RegExp(r'/Contents\s*<([0-9a-fA-F\s]+)>').firstMatch(dictText);
      if (contentsMatch != null) {
        try {
          final hex = contentsMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
          final contentBytes = _hexToBytes(hex);
          final certInfo = _parseX509Der(contentBytes);
          if (certInfo != null) {
            issuerName = certInfo.issuerName;
            certSubject = certInfo.signerName;
            validFrom = certInfo.validFrom;
            validTo = certInfo.validTo;
            serialNumber = certInfo.serialNumber;
          }
        } catch (e) {
          debugPrint('Error parsing /Contents hex: $e');
        }
      }

      results.add(PdfCertificateInfo(
        signerName: signerName ?? certSubject,
        issuerName: issuerName,
        signDate: signDate,
        validFrom: validFrom,
        validTo: validTo,
        reason: reason,
        location: location,
        contactInfo: contactInfo,
        filter: filter,
        subFilter: subFilter,
        serialNumber: serialNumber,
        hasSignatureField: true,
      ));
    }

    return results;
  }

  static String? _extractPdfString(String dict, String key) {
    // Literal string: /Key (value)
    final litMatch = RegExp('/$key\\s*\\((.*?)\\)', dotAll: true).firstMatch(dict);
    if (litMatch != null) {
      return _cleanPdfLiteral(litMatch.group(1)!);
    }
    // Hex string: /Key <hex>
    final hexMatch = RegExp('/$key\\s*<([0-9a-fA-F]+)>').firstMatch(dict);
    if (hexMatch != null) {
      try {
        final bytes = _hexToBytes(hexMatch.group(1)!);
        // Check for UTF-16 BE BOM (0xFE 0xFF)
        if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
          return _decodeUtf16Be(bytes.sublist(2));
        }
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {}
    }
    return null;
  }

  static String? _extractPdfName(String dict, String key) {
    final match = RegExp('/$key\\s*/([A-Za-z0-9._-]+)').firstMatch(dict);
    return match?.group(1);
  }

  static DateTime? _extractPdfDate(String dict, String key) {
    // PDF Date format: (D:YYYYMMDDHHmmSSOHH'mm')
    final match = RegExp('/$key\\s*\\(D:([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})?([0-9]{2})?([0-9]{2})?.*?\\)').firstMatch(dict);
    if (match != null) {
      try {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        final hour = match.group(4) != null ? int.parse(match.group(4)!) : 0;
        final minute = match.group(5) != null ? int.parse(match.group(5)!) : 0;
        final second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
        return DateTime(year, month, day, hour, minute, second);
      } catch (_) {}
    }
    return null;
  }

  static String _cleanPdfLiteral(String raw) {
    // Handle PDF string escapes: \n, \r, \t, \(, \), \\, \ooo
    return raw
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }

  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      hex = '${hex}0';
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static String _decodeUtf16Be(Uint8List bytes) {
    final codeUnits = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(codeUnits);
  }

  /// Lightweight in-memory scanner for ASN.1 DER structures to extract
  /// X.509 Common Name (CN), Organization (O), Issuer, and Validity dates.
  static PdfCertificateInfo? _parseX509Der(Uint8List bytes) {
    if (bytes.length < 20) return null;

    try {
      final latin = latin1.decode(bytes);

      String? cn;
      String? org;
      String? issuer;
      DateTime? validFrom;
      DateTime? validTo;

      // Scan for common OIDs in ASN.1 DER
      // CN: 2.5.4.3 => bytes: 0x55, 0x04, 0x03
      final cnMatches = _findAsn1StringsAfterOid(bytes, [0x55, 0x04, 0x03]);
      if (cnMatches.isNotEmpty) {
        cn = cnMatches.first;
        if (cnMatches.length > 1) {
          issuer = cnMatches.last;
        }
      }

      // Organization: 2.5.4.10 => bytes: 0x55, 0x04, 0x0A
      final orgMatches = _findAsn1StringsAfterOid(bytes, [0x55, 0x04, 0x0A]);
      if (orgMatches.isNotEmpty) {
        org = orgMatches.first;
        if (orgMatches.length > 1 && issuer == null) {
          issuer = orgMatches.last;
        }
      }

      // Scan for UTCTime (0x17) or GeneralizedTime (0x18) dates
      final datePattern = RegExp(r'([0-9]{2}|[0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})Z');
      final dateMatches = datePattern.allMatches(latin).toList();
      if (dateMatches.length >= 2) {
        validFrom = _parseAsn1Date(dateMatches[0].group(0)!);
        validTo = _parseAsn1Date(dateMatches[1].group(0)!);
      }

      if (cn != null || org != null || issuer != null) {
        return PdfCertificateInfo(
          signerName: cn,
          organization: org,
          issuerName: issuer,
          validFrom: validFrom,
          validTo: validTo,
          hasSignatureField: true,
        );
      }
    } catch (e) {
      debugPrint('Error in _parseX509Der: $e');
    }
    return null;
  }

  static List<String> _findAsn1StringsAfterOid(Uint8List bytes, List<int> oid) {
    final results = <String>[];
    for (int i = 0; i <= bytes.length - oid.length - 4; i++) {
      bool match = true;
      for (int j = 0; j < oid.length; j++) {
        if (bytes[i + j] != oid[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        // Next bytes in DER: tag (0x0C = UTF8String, 0x13 = PrintableString, 0x14 = T61String, 0x1E = BMPString), then length
        final offset = i + oid.length;
        if (offset + 1 < bytes.length) {
          final tag = bytes[offset];
          final len = bytes[offset + 1];
          if ((tag == 0x0C || tag == 0x13 || tag == 0x14 || tag == 0x16) &&
              offset + 2 + len <= bytes.length &&
              len > 0) {
            final strBytes = bytes.sublist(offset + 2, offset + 2 + len);
            try {
              final str = utf8.decode(strBytes, allowMalformed: true).trim();
              if (str.isNotEmpty && !results.contains(str)) {
                results.add(str);
              }
            } catch (_) {}
          }
        }
      }
    }
    return results;
  }

  static DateTime? _parseAsn1Date(String dateStr) {
    try {
      if (dateStr.length == 13 && dateStr.endsWith('Z')) {
        // UTCTime: YYMMDDHHMMSSZ
        int year = int.parse(dateStr.substring(0, 2));
        year += (year >= 50 ? 1900 : 2000);
        final month = int.parse(dateStr.substring(2, 4));
        final day = int.parse(dateStr.substring(4, 6));
        final hour = int.parse(dateStr.substring(6, 8));
        final minute = int.parse(dateStr.substring(8, 10));
        final second = int.parse(dateStr.substring(10, 12));
        return DateTime.utc(year, month, day, hour, minute, second);
      } else if (dateStr.length == 15 && dateStr.endsWith('Z')) {
        // GeneralizedTime: YYYYMMDDHHMMSSZ
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        final hour = int.parse(dateStr.substring(8, 10));
        final minute = int.parse(dateStr.substring(10, 12));
        final second = int.parse(dateStr.substring(12, 14));
        return DateTime.utc(year, month, day, hour, minute, second);
      }
    } catch (_) {}
    return null;
  }
}
