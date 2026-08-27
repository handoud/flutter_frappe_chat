import 'dart:io';

/// Reads a file from disk into memory, for upload.
///
/// Kept in one place so the rest of the package does not import `dart:io`.
Future<({String name, List<int> bytes})> readFileForUpload(String path) async {
  final file = File(path);
  return (
    name: path.split(Platform.pathSeparator).last.split('/').last,
    bytes: await file.readAsBytes(),
  );
}
