import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/permissions.dart';

/// A file chosen for upload, held in memory.
typedef PickedAttachment = ({String name, List<int> bytes});

/// Bottom sheet offering camera, gallery and file pickers.
class AttachmentSheet extends StatelessWidget {
  /// Called with the chosen file's name and bytes.
  final void Function(PickedAttachment attachment) onFileSelected;

  /// Called when a picker fails or a permission is refused.
  final void Function(String message)? onError;

  const AttachmentSheet({
    super.key,
    required this.onFileSelected,
    this.onError,
  });

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera &&
        !await ChatPermissions.requestCamera()) {
      onError?.call('Camera access is needed to take a photo');
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      onFileSelected((name: picked.name, bytes: await picked.readAsBytes()));
    } catch (e) {
      onError?.call('Could not open the picker: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(withData: true);
      final file = result?.files.singleOrNull;
      if (file == null) return;

      final bytes = file.bytes;
      if (bytes == null) {
        onError?.call('Could not read ${file.name}');
        return;
      }

      onFileSelected((name: file.name, bytes: bytes));
    } catch (e) {
      onError?.call('Could not open the file picker: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_outlined),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('File'),
            onTap: () {
              Navigator.pop(context);
              _pickFile();
            },
          ),
        ],
      ),
    );
  }
}
