import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/aircraft.dart';
import '../services/media_service.dart';
import '../services/aircraft_settings_service.dart';
import '../l10n/app_localizations.dart';

class AircraftDocumentsWidget extends StatefulWidget {
  final Aircraft aircraft;

  const AircraftDocumentsWidget({super.key, required this.aircraft});

  @override
  State<AircraftDocumentsWidget> createState() =>
      _AircraftDocumentsWidgetState();
}

class _AircraftDocumentsWidgetState extends State<AircraftDocumentsWidget> {
  final MediaService _mediaService = MediaService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final documents = widget.aircraft.documentsPaths ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.documents,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _isLoading ? null : _addDocument,
                tooltip: AppLocalizations.of(context)!.addDocument,
              ),
            ],
          ),
        ),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          ),

        if (documents.isEmpty && !_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noDocumentsYet,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.addAfmPohDocuments,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        if (documents.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final docPath = documents[index];
              final file = _mediaService.getFile(docPath);

              return _buildDocumentTile(file, docPath);
            },
          ),
      ],
    );
  }

  Widget _buildDocumentTile(File? file, String docPath) {
    final fileName = _mediaService.getFileName(docPath);
    final isImage = _mediaService.isImage(docPath);
    final extension = _mediaService.getFileExtension(docPath);
    final exists = file != null;

    IconData icon;
    Color iconColor;

    if (!exists) {
      icon = Icons.broken_image;
      iconColor = Colors.red;
    } else if (isImage) {
      icon = Icons.image;
      iconColor = Colors.blue;
    } else {
      switch (extension) {
        case '.pdf':
          icon = Icons.picture_as_pdf;
          iconColor = Colors.red;
          break;
        case '.doc':
        case '.docx':
          icon = Icons.description;
          iconColor = Colors.blue.shade700;
          break;
        case '.txt':
          icon = Icons.text_snippet;
          iconColor = Colors.white;
          break;
        default:
          icon = Icons.insert_drive_file;
          iconColor = Colors.white;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, size: 40, color: iconColor),
        title: Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: exists
            ? Text(AppLocalizations.of(context)!.tapToOpen, style: TextStyle(color: const Color(0x99FFFFFF)))
            : Text(AppLocalizations.of(context)!.fileNotFound, style: const TextStyle(color: Colors.red)),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteDocument(docPath),
          tooltip: AppLocalizations.of(context)!.delete,
        ),
        onTap: exists ? () => _openDocument(file) : null,
      ),
    );
  }

  Future<void> _addDocument() async {
    // Show dialog to let user choose between camera or gallery for image documents
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addDocumentImage),
        content: Text(
          AppLocalizations.of(context)!.youCanAddDocumentImages,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: Text(AppLocalizations.of(context)!.takePhoto),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: Text(AppLocalizations.of(context)!.chooseFromGallery),
          ),
        ],
      ),
    );

    if (source == null) return;

    setState(() => _isLoading = true);

    try {
      String? documentPath;
      if (source == ImageSource.camera) {
        documentPath = await _mediaService.takePhoto();
      } else {
        documentPath = await _mediaService.pickImageFromGallery();
      }

      if (documentPath != null) {
        await _addDocumentToAircraft(documentPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorAddingDocument(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addDocumentToAircraft(String documentPath) async {
    final aircraftService = context.read<AircraftSettingsService>();
    final updatedDocuments = List<String>.from(
      widget.aircraft.documentsPaths ?? [],
    );
    updatedDocuments.add(documentPath);

    final updatedAircraft = widget.aircraft.copyWith(
      documentsPaths: updatedDocuments,
      updatedAt: DateTime.now(),
    );

    await aircraftService.updateAircraft(updatedAircraft);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.documentAddedSuccessfully)),
      );
    }
  }

  Future<void> _deleteDocument(String documentPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteDocument),
        content: Text(
          AppLocalizations.of(context)!.areYouSureDeleteDocument(_mediaService.getFileName(documentPath)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        // Delete from storage
        await _mediaService.deleteDocument(documentPath);

        // Update aircraft
        if (!mounted) return;
        final aircraftService = context.read<AircraftSettingsService>();
        final updatedDocuments = List<String>.from(
          widget.aircraft.documentsPaths ?? [],
        );
        updatedDocuments.remove(documentPath);

        final updatedAircraft = widget.aircraft.copyWith(
          documentsPaths: updatedDocuments,
          updatedAt: DateTime.now(),
        );

        await aircraftService.updateAircraft(updatedAircraft);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.documentDeleted)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errorDeletingDocument(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _openDocument(File file) async {
    try {
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not open document';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorOpeningDocument(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
