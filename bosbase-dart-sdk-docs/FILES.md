# Files Upload and Handling - Dart SDK Documentation

## Overview

BosBase allows you to upload and manage files through file fields in your collections. Files are stored with sanitized names and a random suffix for security (e.g., `test_52iwbgds7l.png`).

**Key Features:**
- Upload multiple files per field
- Maximum file size: ~8GB (2^53-1 bytes)
- Automatic filename sanitization and random suffix
- Image thumbnails support
- Protected files with token-based access
- File modifiers for append/prepend/delete operations

**Backend Endpoints:**
- `POST /api/files/token` - Get file access token for protected files
- `GET /api/files/{collection}/{recordId}/{filename}` - Download file

## File Field Configuration

Before uploading files, you must add a file field to your collection:

\`\`\`dart
var collection = await pb.collections.getOne('example');

final fields = List<Map<String, dynamic>>.from(collection.fields);
fields.add({
  'name': 'documents',
  'type': 'file',
  'maxSelect': 5,        // Maximum number of files (1 for single file)
  'maxSize': 5242880,    // 5MB in bytes (optional, default: 5MB)
  'mimeTypes': ['image/jpeg', 'image/png', 'application/pdf'],
  'thumbs': ['100x100', '300x300'],  // Thumbnail sizes for images
  'protected': false     // Require token for access
});

await pb.collections.update('example', body: {'fields': fields});
\`\`\`

## Uploading Files

### Basic Upload with Create

When creating a new record, you can upload files directly:

\`\`\`dart
import 'package:bosbase/bosbase.dart';
import 'package:http/http.dart' as http;

final pb = Bosbase('http://localhost:8090');

// Create record and upload multiple files
final record = await pb.collection('example').create(
  body: {
    'title': 'Hello world!',
  },
  files: [
    http.MultipartFile.fromString(
      'documents',
      'content 1...',
      filename: 'file1.txt',
    ),
    http.MultipartFile.fromString(
      'documents',
      'content 2...',
      filename: 'file2.txt',
    ),
  ],
);
\`\`\`

### Upload with Real Files

\`\`\`dart
import 'dart:io';
import 'package:bosbase/bosbase.dart';
import 'package:http/http.dart' as http;

// Upload files from file system
final file1 = File('/path/to/file1.txt');
final file2 = File('/path/to/file2.txt');

final record = await pb.collection('example').create(
  body: {'title': 'Document Set'},
  files: [
    await http.MultipartFile.fromPath('documents', file1.path),
    await http.MultipartFile.fromPath('documents', file2.path),
  ],
);
\`\`\`

### Upload with Update

\`\`\`dart
// Update record and upload new files
final updatedRecord = await pb.collection('example').update(
  'RECORD_ID',
  body: {'title': 'Updated title'},
  files: [
    await http.MultipartFile.fromPath('documents', '/path/to/file3.txt'),
  ],
);
\`\`\`

### Append Files (Using + Modifier)

For multiple file fields, use the `+` modifier to append files:

\`\`\`dart
// Append files to existing ones
await pb.collection('example').update(
  'RECORD_ID',
  files: [
    http.MultipartFile.fromString(
      'documents+',  // + suffix for append
      'content 4...',
      filename: 'file4.txt',
    ),
  ],
);

// Or prepend files (files will appear first)
await pb.collection('example').update(
  'RECORD_ID',
  files: [
    http.MultipartFile.fromString(
      '+documents',  // + prefix for prepend
      'content 0...',
      filename: 'file0.txt',
    ),
  ],
);
\`\`\`

## Deleting Files

### Delete All Files

\`\`\`dart
// Delete all files in a field (set to empty array)
await pb.collection('example').update(
  'RECORD_ID',
  body: {
    'documents': [],
  },
);
\`\`\`

### Delete Specific Files (Using - Modifier)

\`\`\`dart
// Delete individual files by filename
await pb.collection('example').update(
  'RECORD_ID',
  body: {
    'documents-': ['file1.pdf', 'file2.txt'],
  },
);
\`\`\`

## File URLs

### Get File URL

Each uploaded file can be accessed via its URL:

```
http://localhost:8090/api/files/COLLECTION_ID_OR_NAME/RECORD_ID/FILENAME
```

**Using SDK:**

\`\`\`dart
final record = await pb.collection('example').getOne('RECORD_ID');

// Single file field (returns string)
final filename = record.getStringValue('image');
final url = pb.files.getURL(record, filename);

// Multiple file field (returns array)
final files = record.getListValue<String>('documents');
final firstFile = files[0];
final url = pb.files.getURL(record, firstFile);
\`\`\`

### Image Thumbnails

If your file field has thumbnail sizes configured, you can request thumbnails:

\`\`\`dart
final record = await pb.collection('example').getOne('RECORD_ID');
final filename = record.getStringValue('avatar');  // Image file

// Get thumbnail with specific size
final thumbUrl = pb.files.getURL(
  record,
  filename,
  thumb: '100x300',  // Width x Height
);
\`\`\`

**Thumbnail Formats:**

- `WxH` (e.g., `100x300`) - Crop to WxH viewbox from center
- `WxHt` (e.g., `100x300t`) - Crop to WxH viewbox from top
- `WxHb` (e.g., `100x300b`) - Crop to WxH viewbox from bottom
- `WxHf` (e.g., `100x300f`) - Fit inside WxH viewbox (no cropping)
- `0xH` (e.g., `0x300`) - Resize to H height, preserve aspect ratio
- `Wx0` (e.g., `100x0`) - Resize to W width, preserve aspect ratio

**Supported Image Formats:**
- JPEG (`.jpg`, `.jpeg`)
- PNG (`.png`)
- GIF (`.gif` - first frame only)
- WebP (`.webp` - stored as PNG)

**Example:**

\`\`\`dart
final record = await pb.collection('products').getOne('PRODUCT_ID');
final image = record.getStringValue('image');

// Different thumbnail sizes
final thumbSmall = pb.files.getURL(record, image, thumb: '100x100');
final thumbMedium = pb.files.getURL(record, image, thumb: '300x300f');
final thumbLarge = pb.files.getURL(record, image, thumb: '800x600');
final thumbHeight = pb.files.getURL(record, image, thumb: '0x400');
final thumbWidth = pb.files.getURL(record, image, thumb: '600x0');
\`\`\`

### Force Download

To force browser download instead of preview:

\`\`\`dart
final url = pb.files.getURL(
  record,
  filename,
  download: true,  // Force download
);
\`\`\`

## Protected Files

By default, all files are publicly accessible if you know the full URL. For sensitive files, you can mark the field as "Protected" in the collection settings.

### Setting Up Protected Files

\`\`\`dart
var collection = await pb.collections.getOne('example');

final fields = List<Map<String, dynamic>>.from(collection.fields);
final fileFieldIndex = fields.indexWhere((f) => f['name'] == 'documents');

if (fileFieldIndex != -1) {
  fields[fileFieldIndex] = {
    ...fields[fileFieldIndex],
    'protected': true,
  };
  await pb.collections.update('example', body: {'fields': fields});
}
\`\`\`

### Accessing Protected Files

Protected files require authentication and a file token:

\`\`\`dart
// Step 1: Authenticate
await pb.collection('users').authWithPassword('user@example.com', 'password123');

// Step 2: Get file token (valid for ~2 minutes)
final fileToken = await pb.files.getToken();

// Step 3: Get protected file URL with token
final record = await pb.collection('example').getOne('RECORD_ID');
final url = pb.files.getURL(
  record,
  record.getStringValue('privateDocument'),
  token: fileToken,
);
\`\`\`

**Important:**
- File tokens are short-lived (~2 minutes)
- Only authenticated users satisfying the collection's `viewRule` can access protected files
- Tokens must be regenerated when they expire

### Complete Protected File Example

\`\`\`dart
Future<String?> loadProtectedImage(String recordId, String filename) async {
  try {
    // Check if authenticated
    if (!pb.authStore.isValid) {
      throw Exception('Not authenticated');
    }

    // Get fresh token
    final token = await pb.files.getToken();

    // Get file URL
    final record = await pb.collection('example').getOne(recordId);
    final url = pb.files.getURL(record, filename, token: token);

    return url.toString();
  } on ClientException catch (e) {
    if (e.statusCode == 404) {
      print('File not found or access denied');
    } else if (e.statusCode == 401) {
      print('Authentication required');
      pb.authStore.clear();
    }
    rethrow;
  }
}
\`\`\`

## Complete Examples

### Example 1: Image Upload with Thumbnails

\`\`\`dart
import 'dart:io';
import 'package:bosbase/bosbase.dart';
import 'package:http/http.dart' as http;

final pb = Bosbase('http://localhost:8090');
await pb.admins.authWithPassword('admin@example.com', 'password');

// Create collection with image field and thumbnails
final collection = await pb.collections.createBase('products', body: {
  'fields': [
    {'name': 'name', 'type': 'text', 'required': true},
    {
      'name': 'image',
      'type': 'file',
      'maxSelect': 1,
      'mimeTypes': ['image/jpeg', 'image/png'],
      'thumbs': ['100x100', '300x300', '800x600f']  // Thumbnail sizes
    }
  ]
});

// Upload product with image
final imageFile = File('/path/to/product.jpg');
final product = await pb.collection('products').create(
  body: {'name': 'My Product'},
  files: [
    await http.MultipartFile.fromPath('image', imageFile.path),
  ],
);

// Display thumbnail in UI
final thumbnailUrl = pb.files.getURL(
  product,
  product.getStringValue('image'),
  thumb: '300x300',
);

// Use in Flutter Image widget
// Image.network(thumbnailUrl.toString())
\`\`\`

### Example 2: File Picker in Flutter

\`\`\`dart
import 'package:file_picker/file_picker.dart';
import 'package:bosbase/bosbase.dart';
import 'package:http/http.dart' as http;

Future<void> uploadFiles() async {
  // Pick files
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.any,
  );

  if (result != null) {
    final files = result.files;
    
    // Convert to MultipartFile
    final multipartFiles = await Future.wait(
      files.map((file) async {
        if (file.path != null) {
          return await http.MultipartFile.fromPath(
            'documents',
            file.path!,
            filename: file.name,
          );
        } else if (file.bytes != null) {
          return http.MultipartFile.fromBytes(
            'documents',
            file.bytes!,
            filename: file.name,
          );
        }
        throw Exception('File has no path or bytes');
      }),
    );

    // Upload
    final record = await pb.collection('example').create(
      body: {'title': 'Uploaded Files'},
      files: multipartFiles,
    );

    print('Uploaded: ${record.getStringListValue('documents')}');
  }
}
\`\`\`

### Example 3: File Management

\`\`\`dart
class FileManager {
  final String collectionId;
  final String recordId;

  FileManager(this.collectionId, this.recordId);

  Future<RecordModel> load() async {
    return await pb.collection(collectionId).getOne(recordId);
  }

  Future<void> deleteFile(String filename) async {
    await pb.collection(collectionId).update(
      recordId,
      body: {
        'documents-': [filename],
      },
    );
  }

  Future<void> addFiles(List<http.MultipartFile> files) async {
    // Convert to append modifier files
    final appendFiles = files.map((file) {
      return http.MultipartFile(
        'documents+',
        file.filename ?? 'file',
        file.length ?? 0,
        file.finalize(),
        headers: file.headers,
      );
    }).toList();

    await pb.collection(collectionId).update(
      recordId,
      files: appendFiles,
    );
  }

  List<String> getFileUrls(RecordModel record) {
    final files = record.getListValue<String>('documents');
    return files.map((filename) {
      return pb.files.getURL(record, filename).toString();
    }).toList();
  }
}

// Usage
final manager = FileManager('example', 'RECORD_ID');
final record = await manager.load();
final urls = manager.getFileUrls(record);
\`\`\`

### Example 4: Protected Document Viewer

\`\`\`dart
import 'package:url_launcher/url_launcher.dart';

Future<void> viewProtectedDocument(String recordId, String filename) async {
  // Authenticate if needed
  if (!pb.authStore.isValid) {
    await pb.collection('users').authWithPassword('user@example.com', 'pass');
  }

  // Get token
  String token;
  try {
    token = await pb.files.getToken();
  } catch (e) {
    print('Failed to get file token: $e');
    return;
  }

  // Get record and file URL
  final record = await pb.collection('documents').getOne(recordId);
  final url = pb.files.getURL(record, filename, token: token);

  // Open in browser
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  }
}
\`\`\`

### Example 5: Image Gallery with Thumbnails

\`\`\`dart
Future<List<String>> getGalleryThumbnails(String recordId) async {
  final record = await pb.collection('gallery').getOne(recordId);
  final images = record.getListValue<String>('images');

  return images.map((filename) {
    // Thumbnail for grid view
    final thumbUrl = pb.files.getURL(
      record,
      filename,
      thumb: '200x200f',  // Fit inside 200x200
    );
    return thumbUrl.toString();
  }).toList();
}
\`\`\`

## File Field Modifiers

### Summary

- **No modifier** - Replace all files: `documents: []` or files array
- **`+` suffix** - Append files: `documents+` in file field name
- **`+` prefix** - Prepend files: `+documents` in file field name
- **`-` suffix** - Delete files: `documents-: ['file1.pdf']` in body

## Best Practices

1. **File Size Limits**: Always validate file sizes on the client before upload
2. **MIME Types**: Configure allowed MIME types in collection field settings
3. **Thumbnails**: Pre-generate common thumbnail sizes for better performance
4. **Protected Files**: Use protected files for sensitive documents (ID cards, contracts)
5. **Token Refresh**: Refresh file tokens before they expire for protected files
6. **Error Handling**: Handle 404 errors for missing files and 401 for protected file access
7. **Filename Sanitization**: Files are automatically sanitized, but validate on client side too

## Error Handling

\`\`\`dart
try {
  final record = await pb.collection('example').create(
    body: {'title': 'Test'},
    files: [
      await http.MultipartFile.fromPath('documents', '/path/to/file.txt'),
    ],
  );
} on ClientException catch (e) {
  if (e.statusCode == 413) {
    print('File too large');
  } else if (e.statusCode == 400) {
    print('Invalid file type or field validation failed');
  } else if (e.statusCode == 403) {
    print('Insufficient permissions');
  } else {
    print('Upload failed: ${e.message}');
  }
}
\`\`\`

## Storage Options

By default, BosBase stores files in `pb_data/storage` on the local filesystem. For production, you can configure S3-compatible storage (AWS S3, MinIO, Wasabi, DigitalOcean Spaces, etc.) from:
**Dashboard > Settings > Files storage**

This is configured server-side and doesn't require SDK changes.

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection and field configuration
- [Authentication](./AUTHENTICATION.md) - Required for protected files
