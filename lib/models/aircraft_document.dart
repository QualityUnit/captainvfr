import 'package:hive/hive.dart';

part 'aircraft_document.g.dart';

/// Type of aircraft document
enum DocumentType {
  registration,
  airworthiness,
  radioLicense,
  insurance,
  insuranceDeclarations,
  weightBalance,
  equipmentList,
  stc,
  fieldApproval,
  maintenanceRecord,
  other,
}

/// Aircraft document
@HiveType(typeId: 56)
class AircraftDocument extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String aircraftId;

  @HiveField(2)
  String name;

  @HiveField(3)
  int documentType; // DocumentType enum index

  @HiveField(4)
  String filePath; // Local file path

  @HiveField(5)
  String? fileType; // pdf, jpg, png, etc.

  @HiveField(6)
  int? fileSizeBytes;

  @HiveField(7)
  DateTime? expirationDate;

  @HiveField(8)
  String? notes;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  String? documentNumber; // Certificate number, policy number, etc.

  @HiveField(12)
  String? issuingAuthority; // FAA, insurance company, etc.

  AircraftDocument({
    required this.id,
    required this.aircraftId,
    required this.name,
    required this.documentType,
    required this.filePath,
    this.fileType,
    this.fileSizeBytes,
    this.expirationDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.documentNumber,
    this.issuingAuthority,
  });

  DocumentType get type => DocumentType.values[documentType];

  /// Check if document is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Check if document expires soon (within 30 days)
  bool get expiresSoon {
    if (expirationDate == null) return false;
    final daysUntilExpiration = expirationDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiration <= 30 && daysUntilExpiration > 0;
  }

  /// Days until expiration
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    return expirationDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aircraft_id': aircraftId,
      'name': name,
      'document_type': documentType,
      'file_path': filePath,
      'file_type': fileType,
      'file_size_bytes': fileSizeBytes,
      'expiration_date': expirationDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'document_number': documentNumber,
      'issuing_authority': issuingAuthority,
    };
  }

  factory AircraftDocument.fromMap(Map<String, dynamic> map) {
    return AircraftDocument(
      id: map['id'] ?? '',
      aircraftId: map['aircraft_id'] ?? '',
      name: map['name'] ?? '',
      documentType: map['document_type'] ?? 0,
      filePath: map['file_path'] ?? '',
      fileType: map['file_type'],
      fileSizeBytes: map['file_size_bytes'],
      expirationDate: map['expiration_date'] != null
          ? DateTime.parse(map['expiration_date'])
          : null,
      notes: map['notes'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      documentNumber: map['document_number'],
      issuingAuthority: map['issuing_authority'],
    );
  }

  AircraftDocument copyWith({
    String? id,
    String? aircraftId,
    String? name,
    int? documentType,
    String? filePath,
    String? fileType,
    int? fileSizeBytes,
    DateTime? expirationDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? documentNumber,
    String? issuingAuthority,
  }) {
    return AircraftDocument(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      name: name ?? this.name,
      documentType: documentType ?? this.documentType,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      expirationDate: expirationDate ?? this.expirationDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentNumber: documentNumber ?? this.documentNumber,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
    );
  }
}

/// Helper class for document type display
class DocumentTypeHelper {
  static String getDisplayName(DocumentType type) {
    switch (type) {
      case DocumentType.registration:
        return 'Registration Certificate';
      case DocumentType.airworthiness:
        return 'Airworthiness Certificate';
      case DocumentType.radioLicense:
        return 'Radio Station License';
      case DocumentType.insurance:
        return 'Insurance Policy';
      case DocumentType.insuranceDeclarations:
        return 'Insurance Declarations';
      case DocumentType.weightBalance:
        return 'Weight & Balance Report';
      case DocumentType.equipmentList:
        return 'Equipment List';
      case DocumentType.stc:
        return 'STC (Supplemental Type Certificate)';
      case DocumentType.fieldApproval:
        return 'Field Approval';
      case DocumentType.maintenanceRecord:
        return 'Maintenance Record';
      case DocumentType.other:
        return 'Other Document';
    }
  }

  static String getIcon(DocumentType type) {
    switch (type) {
      case DocumentType.registration:
      case DocumentType.airworthiness:
      case DocumentType.radioLicense:
        return '📜';
      case DocumentType.insurance:
      case DocumentType.insuranceDeclarations:
        return '🛡️';
      case DocumentType.weightBalance:
        return '⚖️';
      case DocumentType.equipmentList:
        return '📋';
      case DocumentType.stc:
      case DocumentType.fieldApproval:
        return '✅';
      case DocumentType.maintenanceRecord:
        return '🔧';
      case DocumentType.other:
        return '📄';
    }
  }

  static bool requiresExpiration(DocumentType type) {
    return type == DocumentType.registration ||
        type == DocumentType.airworthiness ||
        type == DocumentType.radioLicense ||
        type == DocumentType.insurance ||
        type == DocumentType.insuranceDeclarations;
  }
}
