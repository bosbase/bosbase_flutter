# File API - Dart SDK Documentation

## Overview

The File API provides endpoints for downloading and accessing files stored in collection records. It supports thumbnail generation for images, protected file access with tokens, and force download options.

**Key Features:**
- Download files from collection records
- Generate thumbnails for images (crop, fit, resize)
- Protected file access with short-lived tokens
- Force download option for any file type
- Automatic content-type detection
- Support for Range requests and caching

**Backend Endpoints:**
- `GET /api/files/{collection}/{recordId}/{filename}` - Download/fetch file
- `POST /api/files/token` - Generate protected file token

## Download / Fetch File

Downloads a single file resource from a record.

### Basic Usage

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Get a record with a file field
final record = await pb.collection('posts').getOne('RECORD_ID');

// Get the file URL
final fileUrl = pb.files.getURL(record, record['image'] as String);

// Use in Flutter widget
Image.network(fileUrl.toString())
\`\`\`

### File URL Structure

The file URL follows this pattern:
\`\`\`
/api/files/{collectionIdOrName}/{recordId}/{filename}
\`\`\`

Example:
\`\`\`
http://127.0.0.1:8090/api/files/posts/abc123/photo_xyz789.jpg
\`\`\`

## Thumbnails

Generate thumbnails for image files on-the-fly.

### Thumbnail Formats

The following thumbnail formats are supported:

| Format | Example | Description |
|--------|---------|-------------|
| \`WxH\` | \`100x300\` | Crop to WxH viewbox (from center) |
| \`WxHt\` | \`100x300t\` | Crop to WxH viewbox (from top) |
| \`WxHb\` | \`100x300b\` | Crop to WxH viewbox (from bottom) |
| \`WxHf\` | \`100x300f\` | Fit inside WxH viewbox (without cropping) |
| \`0xH\` | \`0x300\` | Resize to H height preserving aspect ratio |
| \`Wx0\` | \`100x0\` | Resize to W width preserving aspect ratio |

### Using Thumbnails

\`\`\`dart
// Get thumbnail URL
final thumbUrl = pb.files.getURL(
  record,
  record['image'] as String,
  thumb: '100x100',
);

// Different thumbnail sizes
final smallThumb = pb.files.getURL(
  record,
  record['image'] as String,
  thumb: '50x50',
);

final mediumThumb = pb.files.getURL(
  record,
  record['image'] as String,
  thumb: '200x200',
);

final largeThumb = pb.files.getURL(
  record,
  record['image'] as String,
  thumb: '500x500',
);

// Fit thumbnail (no cropping)
final fitThumb = pb.files.getURL(
  record,
  record['image'] as String,
  thumb: '200x200f',
);

// Resize to specific width
final widthThumb = pb.files.getURL(
  record,
  record['image'] as String,
  thumb: '300x0',
);

// Resize to specific height
final heightThumb = pb.files.getURL(
  record,
  record['image'] as String,
  thumb: '0x200',
);
\`\`\`

### Thumbnail Examples in Flutter

\`\`\`dart
import 'package:flutter/material.dart';

// Small thumbnail
Image.network(
  pb.files.getURL(record, filename, thumb: '100x100').toString(),
)

// Medium thumbnail with fit
Image.network(
  pb.files.getURL(record, filename, thumb: '300x300f').toString(),
)

// Responsive thumbnail using FadeInImage
FadeInImage.assetNetwork(
  placeholder: 'assets/placeholder.png',
  image: pb.files.getURL(record, filename, thumb: '400x400').toString(),
  width: 400,
  height: 400,
  fit: BoxFit.cover,
)
\`\`\`

### Thumbnail Behavior

- **Image Files Only**: Thumbnails are only generated for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Non-Image Files**: For non-image files, the thumb parameter is ignored and the original file is returned
- **Caching**: Thumbnails are cached and reused if already generated
- **Fallback**: If thumbnail generation fails, the original file is returned
- **Field Configuration**: Thumb sizes must be defined in the file field's \`thumbs\` option or use default \`100x100\`

## Protected Files

Protected files require a special token for access, even if you're authenticated.

### Getting a File Token

\`\`\`dart
// Must be authenticated first
await pb.collection('users').authWithPassword('user@example.com', 'password');

// Get file token
final token = await pb.files.getToken();

print(token); // Short-lived JWT token
\`\`\`

### Using Protected File Token

\`\`\`dart
// Get protected file URL with token
final protectedFileUrl = pb.files.getURL(
  record,
  record['document'] as String,
  token: token,
);

// Download or display the file
final response = await http.get(protectedFileUrl);
final bytes = response.bodyBytes;

// Use the file (e.g., save to local storage or display)
\`\`\`

### Protected File Example

\`\`\`dart
Future<void> displayProtectedImage(String recordId) async {
  // Authenticate
  await pb.collection('users').authWithPassword('user@example.com', 'password');
  
  // Get record
  final record = await pb.collection('documents').getOne(recordId);
  
  // Get file token
  final token = await pb.files.getToken();
  
  // Get protected file URL
  final imageUrl = pb.files.getURL(
    record,
    record['thumbnail'] as String,
    token: token,
    thumb: '300x300',
  );
  
  // Display image (in Flutter)
  // Image.network(imageUrl.toString())
}
\`\`\`

### Token Lifetime

- File tokens are short-lived (typically expires after a few minutes)
- Tokens are associated with the authenticated user/superuser
- Generate a new token if the previous one expires

## Force Download

Force files to download instead of being displayed in the browser.

\`\`\`dart
// Force download
final downloadUrl = pb.files.getURL(
  record,
  record['document'] as String,
  download: true,
);

// Download file using http package
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> downloadFile(Uri url, String filename) async {
  final response = await http.get(url);
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(response.bodyBytes);
}
\`\`\`

## Complete Examples

### Example 1: Image Gallery (Flutter)

\`\`\`dart
import 'package:flutter/material.dart';

class ImageGallery extends StatelessWidget {
  final String recordId;
  
  const ImageGallery({Key? key, required this.recordId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecordModel>(
      future: pb.collection('posts').getOne(recordId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final record = snapshot.data!;
        final images = (record['images'] as List?)?.cast<String>() ?? [];
        
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final filename = images[index];
            final thumbUrl = pb.files.getURL(
              record,
              filename,
              thumb: '200x200',
            );
            
            return GestureDetector(
              onTap: () {
                // Show full image
                final fullUrl = pb.files.getURL(record, filename);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewer(fullUrl),
                  ),
                );
              },
              child: Image.network(thumbUrl.toString()),
            );
          },
        );
      },
    );
  }
}
\`\`\`

### Example 2: File Download Handler

\`\`\`dart
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> downloadFile(String recordId, String filename) async {
  final record = await pb.collection('documents').getOne(recordId);
  
  // Get download URL
  final downloadUrl = pb.files.getURL(
    record,
    filename,
    download: true,
  );
  
  // Download file
  final response = await http.get(downloadUrl);
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(response.bodyBytes);
  
  print('File downloaded to: ${file.path}');
}
\`\`\`

### Example 3: Protected File Viewer

\`\`\`dart
Future<Uri?> getProtectedFileUrl(String recordId) async {
  // Authenticate
  if (!pb.authStore.isValid) {
    await pb.collection('users').authWithPassword('user@example.com', 'password');
  }
  
  // Get record
  final record = await pb.collection('private_docs').getOne(recordId);
  
  // Get token
  String? token;
  try {
    token = await pb.files.getToken();
  } catch (e) {
    print('Failed to get file token: $e');
    return null;
  }
  
  // Get file URL
  return pb.files.getURL(
    record,
    record['file'] as String,
    token: token,
  );
}
\`\`\`

### Example 4: Responsive Image Widget (Flutter)

\`\`\`dart
import 'package:flutter/material.dart';

class ResponsiveImage extends StatelessWidget {
  final RecordModel record;
  final String fieldName;
  
  const ResponsiveImage({
    Key? key,
    required this.record,
    required this.fieldName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filename = record[fieldName] as String?;
    if (filename == null) {
      return SizedBox.shrink();
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    String thumbSize;
    
    if (screenWidth < 600) {
      thumbSize = '300x300';
    } else if (screenWidth < 1200) {
      thumbSize = '400x400';
    } else {
      thumbSize = '800x800';
    }
    
    final imageUrl = pb.files.getURL(record, filename, thumb: thumbSize);
    
    return Image.network(
      imageUrl.toString(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return CircularProgressIndicator();
      },
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.error);
      },
    );
  }
}
\`\`\`

### Example 5: Multiple Files with Thumbnails

\`\`\`dart
Widget buildFileList(String recordId) {
  return FutureBuilder<RecordModel>(
    future: pb.collection('attachments').getOne(recordId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return CircularProgressIndicator();
      }
      
      final record = snapshot.data!;
      final files = (record['files'] as List?)?.cast<String>() ?? [];
      
      return ListView.builder(
        itemCount: files.length,
        itemBuilder: (context, index) {
          final filename = files[index];
          final ext = filename.split('.').last.toLowerCase();
          final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
          
          return ListTile(
            leading: isImage
                ? Image.network(
                    pb.files.getURL(record, filename, thumb: '100x100').toString(),
                    width: 50,
                    height: 50,
                  )
                : Icon(Icons.insert_drive_file),
            title: Text(filename),
            trailing: IconButton(
              icon: Icon(Icons.download),
              onPressed: () {
                downloadFile(recordId, filename);
              },
            ),
          );
        },
      );
    },
  );
}
\`\`\`

### Example 6: Image Upload Preview with Thumbnail

\`\`\`dart
Widget buildImagePreview(RecordModel record, String filename) {
  // Get thumbnail for preview
  final previewUrl = pb.files.getURL(
    record,
    filename,
    thumb: '200x200f',  // Fit to 200x200 without cropping
  );
  
  return GestureDetector(
    onTap: () {
      // Show full image
      final fullUrl = pb.files.getURL(record, filename);
      // Navigate to full image view
    },
    child: Image.network(
      previewUrl.toString(),
      fit: BoxFit.cover,
    ),
  );
}
\`\`\`

## Error Handling

\`\`\`dart
Future<void> loadFile(RecordModel record, String filename) async {
  try {
    final fileUrl = pb.files.getURL(record, filename);
    
    // Verify URL is valid
    if (fileUrl.isEmpty) {
      throw Exception('Invalid file URL');
    }
    
    // Load image
    final response = await http.get(fileUrl);
    if (response.statusCode == 200) {
      print('File loaded successfully');
    } else {
      print('Failed to load file: ${response.statusCode}');
    }
    
  } catch (e) {
    print('File access error: $e');
  }
}
\`\`\`

### Protected File Token Error Handling

\`\`\`dart
Future<Uri?> getProtectedFileUrl(RecordModel record, String filename) async {
  try {
    // Get token
    final token = await pb.files.getToken();
    
    // Get file URL
    return pb.files.getURL(record, filename, token: token);
    
  } on ClientException catch (e) {
    if (e.statusCode == 401) {
      print('Not authenticated');
      // Redirect to login
    } else if (e.statusCode == 403) {
      print('No permission to access file');
    } else {
      print('Failed to get file token: $e');
    }
    return null;
  } catch (e) {
    print('Error: $e');
    return null;
  }
}
\`\`\`

## Best Practices

1. **Use Thumbnails for Lists**: Use thumbnails when displaying images in lists/grids to reduce bandwidth
2. **Lazy Loading**: Use Flutter's \`Image.network\` with loading builders for better UX
3. **Cache Tokens**: Store file tokens and reuse them until they expire
4. **Error Handling**: Always handle file loading errors gracefully
5. **Content-Type**: Let the server handle content-type detection automatically
6. **Range Requests**: The API supports Range requests for efficient video/audio streaming
7. **Caching**: Files are cached with a 30-day cache-control header
8. **Security**: Always use tokens for protected files, never expose them in client-side code

## Thumbnail Size Guidelines

| Use Case | Recommended Size |
|----------|-----------------|
| Profile picture | \`100x100\` or \`150x150\` |
| List thumbnails | \`200x200\` or \`300x300\` |
| Card images | \`400x400\` or \`500x500\` |
| Gallery previews | \`300x300f\` (fit) or \`400x400f\` |
| Hero images | Use original or \`800x800f\` |
| Avatar | \`50x50\` or \`75x75\` |

## Limitations

- **Thumbnails**: Only work for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Protected Files**: Require authentication to get tokens
- **Token Expiry**: File tokens expire after a short period (typically minutes)
- **File Size**: Large files may take time to generate thumbnails on first request
- **Thumb Sizes**: Must match sizes defined in field configuration or use default \`100x100\`

## Related Documentation

- [Files Upload and Handling](./FILES.md) - Uploading and managing files
- [API Records](./API_RECORDS.md) - Working with records
- [Collections](./COLLECTIONS.md) - Collection configuration
