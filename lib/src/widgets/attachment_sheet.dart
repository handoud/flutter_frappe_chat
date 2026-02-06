import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/permissions.dart';

class AttachmentSheet extends StatelessWidget {
  final Function(File) onFileSelected;

  const AttachmentSheet({Key? key, required this.onFileSelected})
      : super(key: key);

  Future<void> _pickImage(ImageSource source) async {
    // Check permissions if needed (camera usually handled by plugin or OS)
    if (source == ImageSource.camera) {
      if (!await ChatPermissions.requestCamera()) return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      onFileSelected(File(pickedFile.path));
    }
  }

  Future<void> _pickFile() async {
    // Permission might be needed for older androids
    if (!await ChatPermissions.requestStorage()) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      onFileSelected(File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 500));
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Gallery'),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 500));
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('File'),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 500));
              _pickFile();
            },
          ),
        ],
      ),
    );
  }
}
