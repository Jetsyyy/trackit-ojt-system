import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

export 'package:file_picker/file_picker.dart' show FileType;

/// A picked file with its contents already read, so it can be uploaded on
/// web and Android alike.
class PickedFile {
  final String name;
  // Nullable to match the old PlatformFile API used by the screens; always
  // filled in by pickFilesWithData.
  final Uint8List? bytes;

  const PickedFile({required this.name, required this.bytes});

  int get size => bytes?.length ?? 0;

  String? get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1 ? null : name.substring(dot + 1);
  }
}

/// The files the user picked; [files] is empty when they cancelled.
class PickedFiles {
  final List<PickedFile> files;
  const PickedFiles(this.files);
}

/// Opens the system file picker and reads the chosen file(s). Returns null
/// when the user cancels.
Future<PickedFiles?> pickFilesWithData({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  bool allowMultiple = false,
}) async {
  final List<PlatformFile> chosen;
  if (allowMultiple) {
    chosen = await FilePicker.pickFiles(type: type, allowedExtensions: allowedExtensions);
  } else {
    final one = await FilePicker.pickFile(type: type, allowedExtensions: allowedExtensions);
    chosen = one == null ? const [] : [one];
  }
  if (chosen.isEmpty) return null;
  final files = <PickedFile>[];
  for (final f in chosen) {
    files.add(PickedFile(name: f.name, bytes: await f.readAsBytes()));
  }
  return PickedFiles(files);
}
