class PdfCertificateInfo {
  final String? signerName;
  final String? issuerName;
  final String? organization;
  final String? organizationalUnit;
  final String? country;
  final String? serialNumber;
  final DateTime? signDate;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? reason;
  final String? location;
  final String? contactInfo;
  final String? filter;
  final String? subFilter;
  final bool hasSignatureField;

  const PdfCertificateInfo({
    this.signerName,
    this.issuerName,
    this.organization,
    this.organizationalUnit,
    this.country,
    this.serialNumber,
    this.signDate,
    this.validFrom,
    this.validTo,
    this.reason,
    this.location,
    this.contactInfo,
    this.filter,
    this.subFilter,
    this.hasSignatureField = true,
  });

  bool get isExpired {
    if (validTo == null) return false;
    return DateTime.now().isAfter(validTo!);
  }

  bool get isNotYetValid {
    if (validFrom == null) return false;
    return DateTime.now().isBefore(validFrom!);
  }

  String get displaySigner {
    if (signerName != null && signerName!.trim().isNotEmpty) {
      return signerName!.trim();
    }
    if (organization != null && organization!.trim().isNotEmpty) {
      return organization!.trim();
    }
    return 'Unknown Signer';
  }
}
