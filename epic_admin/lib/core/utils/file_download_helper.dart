import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart' as helper;

class FileDownloadHelper {
  static void downloadFile(String content, String fileName) {
    helper.downloadFile(content, fileName);
  }

  static void downloadBytes(List<int> bytes, String fileName, String mimeType) {
    helper.downloadBytes(bytes, fileName, mimeType);
  }
}
