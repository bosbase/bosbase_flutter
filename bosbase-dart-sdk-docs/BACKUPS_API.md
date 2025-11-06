# Backups API - Dart SDK Documentation

## Overview

The Backups API provides endpoints for managing application data backups. You can create backups, upload existing backup files, download backups, delete backups, and restore the application from a backup.

**Key Features:**
- List all available backup files
- Create new backups with custom names or auto-generated names
- Upload existing backup ZIP files
- Download backup files (requires file token)
- Delete backup files
- Restore the application from a backup (restarts the app)

**Backend Endpoints:**
- `GET /api/backups` - List backups
- `POST /api/backups` - Create backup
- `POST /api/backups/upload` - Upload backup
- `GET /api/backups/{key}` - Download backup
- `DELETE /api/backups/{key}` - Delete backup
- `POST /api/backups/{key}/restore` - Restore backup

**Note**: All Backups API operations require superuser authentication (except download which requires a superuser file token).

## Authentication

All Backups API operations require superuser authentication:

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
\`\`\`

**Downloading backups** requires a superuser file token (obtained via \`pb.files.getToken()\`), but does not require the Authorization header.

## Backup File Structure

Each backup file contains:
- \`key\`: The filename/key of the backup file (String)
- \`size\`: File size in bytes (int)
- \`modified\`: ISO 8601 timestamp of when the backup was last modified (String)

\`\`\`dart
class BackupFileInfo {
  String key;
  int size;
  String modified;
}
\`\`\`

## List Backups

Returns a list of all available backup files with their metadata.

### Basic Usage

\`\`\`dart
// Get all backups
final backups = await pb.backups.getFullList();

print(backups);
// [
//   BackupFileInfo(
//     key: "pb_backup_20230519162514.zip",
//     modified: "2023-05-19T16:25:57.542Z",
//     size: 251316185
//   ),
//   BackupFileInfo(
//     key: "pb_backup_20230518162514.zip",
//     modified: "2023-05-18T16:25:57.542Z",
//     size: 251314010
//   )
// ]
\`\`\`

### Working with Backup Lists

\`\`\`dart
// Sort backups by modification date (newest first)
final backups = await pb.backups.getFullList();
backups.sort((a, b) => DateTime.parse(b.modified).compareTo(DateTime.parse(a.modified)));

// Find the most recent backup
final mostRecent = backups.isNotEmpty ? backups.first : null;

// Filter backups by size (larger than 100MB)
final largeBackups = backups.where((backup) => backup.size > 100 * 1024 * 1024).toList();

// Get total storage used by backups
final totalSize = backups.fold<int>(0, (sum, backup) => sum + backup.size);
print('Total backup storage: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
\`\`\`

## Create Backup

Creates a new backup of the application data. The backup process is asynchronous and may take some time depending on the size of your data.

### Basic Usage

\`\`\`dart
// Create backup with custom name
await pb.backups.create('my_backup_2024.zip');

// Create backup with auto-generated name (pass empty string or let backend generate)
await pb.backups.create('');
\`\`\`

### Backup Name Format

Backup names must follow the format: \`[a-z0-9_-].zip\`
- Only lowercase letters, numbers, underscores, and hyphens
- Must end with \`.zip\`
- Maximum length: 150 characters
- Must be unique (no existing backup with the same name)

### Examples

\`\`\`dart
// Create a named backup
Future<void> createNamedBackup(String name) async {
  try {
    await pb.backups.create(name);
    print('Backup "$name" creation initiated');
  } on ClientException catch (e) {
    if (e.statusCode == 400) {
      print('Invalid backup name or backup already exists');
    } else {
      print('Failed to create backup: $e');
    }
  }
}

// Create backup with timestamp
Future<String> createTimestampedBackup() async {
  final timestamp = DateTime.now().toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-')
      .substring(0, 19);
  final name = 'backup_$timestamp.zip';
  await pb.backups.create(name);
  return name;
}
\`\`\`

### Important Notes

- **Asynchronous Process**: Backup creation happens in the background. The API returns immediately (204 No Content).
- **Concurrent Operations**: Only one backup or restore operation can run at a time. If another operation is in progress, you'll receive a 400 error.
- **Storage**: Backups are stored in the configured backup filesystem (local or S3).
- **S3 Consistency**: For S3 storage, the backup file may not be immediately available after creation due to eventual consistency.

## Upload Backup

Uploads an existing backup ZIP file to the server. This is useful for restoring backups created elsewhere or for importing backups.

### Basic Usage

\`\`\`dart
import 'package:http/http.dart' as http;
import 'dart:io';

// Upload from a file
final file = File('backup.zip');
final multipartFile = await http.MultipartFile.fromPath('file', file.path);
await pb.backups.upload(multipartFile);

// Upload from bytes
final bytes = await File('backup.zip').readAsBytes();
final multipartFile = http.MultipartFile.fromBytes('file', bytes, filename: 'backup.zip');
await pb.backups.upload(multipartFile);
\`\`\`

### File Requirements

- **MIME Type**: Must be \`application/zip\`
- **Format**: Must be a valid ZIP archive
- **Name**: Must be unique (no existing backup with the same name)
- **Validation**: The file will be validated before upload

### Examples

\`\`\`dart
// Upload backup from file
Future<void> uploadBackupFromFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print('File not found: $filePath');
      return;
    }
    
    final multipartFile = await http.MultipartFile.fromPath('file', file.path);
    await pb.backups.upload(multipartFile);
    print('Backup uploaded successfully');
  } on ClientException catch (e) {
    if (e.statusCode == 400) {
      print('Invalid file or file already exists');
    } else {
      print('Upload failed: $e');
    }
  }
}

// Upload backup from URL (e.g., downloading from another server)
Future<void> uploadBackupFromURL(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    print('Failed to download backup from URL');
    return;
  }
  
  final filename = url.split('/').last.isEmpty ? 'backup.zip' : url.split('/').last;
  final multipartFile = http.MultipartFile.fromBytes('file', response.bodyBytes, filename: filename);
  await pb.backups.upload(multipartFile);
}
\`\`\`

## Download Backup

Downloads a backup file. Requires a superuser file token for authentication.

### Basic Usage

\`\`\`dart
import 'dart:io';
import 'package:http/http.dart' as http;

// Get file token
final token = await pb.files.getToken();

// Build download URL
final url = pb.backups.getDownloadURL(token, 'pb_backup_20230519162514.zip');

// Download the file
final response = await http.get(url);
if (response.statusCode == 200) {
  final file = File('pb_backup_20230519162514.zip');
  await file.writeAsBytes(response.bodyBytes);
  print('Backup downloaded successfully');
}
\`\`\`

### Download URL Structure

The download URL format is:
\`\`\`
/api/backups/{key}?token={fileToken}
\`\`\`

### Examples

\`\`\`dart
// Download backup function
Future<void> downloadBackup(String backupKey, String savePath) async {
  try {
    // Get file token (valid for short period)
    final token = await pb.files.getToken();
    
    // Build download URL
    final url = pb.backups.getDownloadURL(token, backupKey);
    
    // Download the file
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      print('Backup downloaded to: $savePath');
    } else {
      print('Failed to download backup: ${response.statusCode}');
    }
  } catch (e) {
    print('Failed to download backup: $e');
  }
}

// Download and save backup with custom name
Future<void> downloadBackupAs(String backupKey, String saveAs) async {
  final token = await pb.files.getToken();
  final url = pb.backups.getDownloadURL(token, backupKey);
  
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final file = File(saveAs);
    await file.writeAsBytes(response.bodyBytes);
  }
}
\`\`\`

## Delete Backup

Deletes a backup file from the server.

### Basic Usage

\`\`\`dart
await pb.backups.delete('pb_backup_20230519162514.zip');
\`\`\`

### Important Notes

- **Active Backups**: Cannot delete a backup that is currently being created or restored
- **No Undo**: Deletion is permanent
- **File System**: The file will be removed from the backup filesystem

### Examples

\`\`\`dart
// Delete backup with confirmation check
Future<bool> deleteBackupWithConfirmation(String backupKey) async {
  // In a real app, you would use a dialog/confirmation widget
  // For this example, we'll assume confirmation is handled elsewhere
  try {
    await pb.backups.delete(backupKey);
    print('Backup deleted successfully');
    return true;
  } on ClientException catch (e) {
    if (e.statusCode == 400) {
      print('Backup is currently in use and cannot be deleted');
    } else if (e.statusCode == 404) {
      print('Backup not found');
    } else {
      print('Failed to delete backup: $e');
    }
    return false;
  }
}

// Delete old backups (older than 30 days)
Future<void> deleteOldBackups() async {
  final backups = await pb.backups.getFullList();
  final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
  
  final oldBackups = backups.where((backup) {
    final modified = DateTime.parse(backup.modified);
    return modified.isBefore(thirtyDaysAgo);
  }).toList();
  
  for (final backup in oldBackups) {
    try {
      await pb.backups.delete(backup.key);
      print('Deleted old backup: ${backup.key}');
    } catch (e) {
      print('Failed to delete ${backup.key}: $e');
    }
  }
}
\`\`\`

## Restore Backup

Restores the application from a backup file. **This operation will restart the application**.

### Basic Usage

\`\`\`dart
await pb.backups.restore('pb_backup_20230519162514.zip');
\`\`\`

### Important Warnings

⚠️ **CRITICAL**: Restoring a backup will:
1. Replace all current application data with data from the backup
2. **Restart the application process**
3. Any unsaved changes will be lost
4. The application will be unavailable during the restore process

### Prerequisites

- **Disk Space**: Recommended to have at least **2x the backup size** in free disk space
- **UNIX Systems**: Restore is primarily supported on UNIX-based systems (Linux, macOS)
- **No Concurrent Operations**: Cannot restore if another backup or restore is in progress
- **Backup Existence**: The backup file must exist on the server

### Restore Process

The restore process performs the following steps:
1. Downloads the backup file to a temporary location
2. Extracts the backup to a temporary directory
3. Moves current \`pb_data\` content to a temporary location (to be deleted on next app start)
4. Moves extracted backup content to \`pb_data\`
5. Restarts the application

### Examples

\`\`\`dart
// Restore backup with confirmation check
Future<bool> restoreBackupWithConfirmation(String backupKey) async {
  // In a real app, you would use a dialog/confirmation widget
  // This is a critical operation, so always require explicit confirmation
  try {
    await pb.backups.restore(backupKey);
    print('Restore initiated. Application will restart...');
    return true;
  } on ClientException catch (e) {
    if (e.statusCode == 400) {
      if (e.message?.contains('another backup/restore') == true) {
        print('Another backup or restore operation is in progress');
      } else {
        print('Invalid or missing backup file');
      }
    } else {
      print('Failed to restore backup: $e');
    }
    return false;
  }
}
\`\`\`

## Complete Examples

### Example 1: Backup Manager Class

\`\`\`dart
class BackupManager {
  final Bosbase pb;

  BackupManager(this.pb);

  Future<List<BackupFileInfo>> list() async {
    final backups = await pb.backups.getFullList();
    backups.sort((a, b) => DateTime.parse(b.modified).compareTo(DateTime.parse(a.modified)));
    return backups;
  }

  Future<String> create({String? name}) async {
    final backupName = name ?? _generateTimestampedName();
    await pb.backups.create(backupName);
    return backupName;
  }

  Future<Uri> downloadUrl(String key) async {
    final token = await pb.files.getToken();
    return pb.backups.getDownloadURL(token, key);
  }

  Future<void> delete(String key) async {
    await pb.backups.delete(key);
  }

  Future<bool> restore(String key) async {
    await pb.backups.restore(key);
    return true;
  }

  Future<int> cleanup({int daysOld = 30}) async {
    final backups = await list();
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    
    final toDelete = backups.where((b) => DateTime.parse(b.modified).isBefore(cutoff)).toList();
    
    int deleted = 0;
    for (final backup in toDelete) {
      try {
        await delete(backup.key);
        print('Deleted: ${backup.key}');
        deleted++;
      } catch (e) {
        print('Failed to delete ${backup.key}: $e');
      }
    }
    
    return deleted;
  }

  String _generateTimestampedName() {
    final timestamp = DateTime.now().toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    return 'backup_$timestamp.zip';
  }
}

// Usage
final manager = BackupManager(pb);
final backups = await manager.list();
await manager.create();
\`\`\`

### Example 2: Automated Backup Strategy

\`\`\`dart
enum BackupStrategy { daily, weekly, monthly }

class AutomatedBackup {
  final Bosbase pb;
  final BackupStrategy strategy;
  final int maxBackups;

  AutomatedBackup(this.pb, {this.strategy = BackupStrategy.daily, this.maxBackups = 7});

  Future<void> createScheduledBackup() async {
    try {
      final name = _generateBackupName();
      await pb.backups.create(name);
      print('Created backup: $name');
      
      await _cleanupOldBackups();
    } catch (e) {
      print('Backup creation failed: $e');
    }
  }

  String _generateBackupName() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    switch (strategy) {
      case BackupStrategy.daily:
        return 'daily_$dateStr.zip';
      case BackupStrategy.weekly:
        final week = (now.day / 7).ceil();
        return 'weekly_${now.year}_W$week.zip';
      case BackupStrategy.monthly:
        return 'monthly_${now.year}_${now.month.toString().padLeft(2, '0')}.zip';
    }
  }

  Future<void> _cleanupOldBackups() async {
    final backups = await pb.backups.getFullList();
    final sorted = backups.toList()
      ..sort((a, b) => DateTime.parse(b.modified).compareTo(DateTime.parse(a.modified)));
    
    if (sorted.length > maxBackups) {
      final toDelete = sorted.skip(maxBackups);
      for (final backup in toDelete) {
        try {
          await pb.backups.delete(backup.key);
          print('Cleaned up old backup: ${backup.key}');
        } catch (e) {
          print('Failed to delete ${backup.key}: $e');
        }
      }
    }
  }
}

// Setup daily automated backups
final autoBackup = AutomatedBackup(pb, strategy: BackupStrategy.daily);

// Run backup (could be called from a timer or scheduler)
Timer.periodic(Duration(days: 1), (_) {
  autoBackup.createScheduledBackup();
});
\`\`\`

### Example 3: Backup Migration Tool

\`\`\`dart
import 'package:http/http.dart' as http;

class BackupMigrator {
  final Bosbase sourcePb;
  final Bosbase targetPb;

  BackupMigrator(this.sourcePb, this.targetPb);

  Future<void> migrateBackup(String backupKey) async {
    print('Migrating backup: $backupKey');
    
    // Step 1: Download from source
    print('Downloading from source...');
    final sourceToken = await sourcePb.files.getToken();
    final downloadUrl = sourcePb.backups.getDownloadURL(sourceToken, backupKey);
    final response = await http.get(downloadUrl);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download backup from source');
    }
    
    // Step 2: Create multipart file
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      response.bodyBytes,
      filename: backupKey,
    );
    
    // Step 3: Upload to target
    print('Uploading to target...');
    await targetPb.backups.upload(multipartFile);
    
    print('Migration completed');
  }

  Future<void> migrateAllBackups() async {
    final backups = await sourcePb.backups.getFullList();
    
    for (final backup in backups) {
      try {
        await migrateBackup(backup.key);
        print('✓ Migrated: ${backup.key}');
      } catch (e) {
        print('✗ Failed to migrate ${backup.key}: $e');
      }
    }
  }
}

// Usage
final migrator = BackupMigrator(sourcePb, targetPb);
await migrator.migrateAllBackups();
\`\`\`

### Example 4: Backup Health Check

\`\`\`dart
Future<bool> checkBackupHealth() async {
  final backups = await pb.backups.getFullList();
  
  if (backups.isEmpty) {
    print('⚠️ No backups found!');
    return false;
  }
  
  // Check for recent backup (within last 7 days)
  final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
  
  final recentBackups = backups.where((b) {
    final modified = DateTime.parse(b.modified);
    return modified.isAfter(sevenDaysAgo);
  }).toList();
  
  if (recentBackups.isEmpty) {
    print('⚠️ No backups found in the last 7 days');
  } else {
    print('✓ Found ${recentBackups.length} recent backup(s)');
  }
  
  // Check total storage
  final totalSize = backups.fold<int>(0, (sum, b) => sum + b.size);
  final totalSizeMB = (totalSize / 1024 / 1024).toStringAsFixed(2);
  print('Total backup storage: $totalSizeMB MB');
  
  // Check largest backup
  if (backups.isNotEmpty) {
    final largest = backups.reduce((max, b) => b.size > max.size ? b : max);
    final largestSizeMB = (largest.size / 1024 / 1024).toStringAsFixed(2);
    print('Largest backup: ${largest.key} ($largestSizeMB MB)');
  }
  
  return true;
}
\`\`\`

## Error Handling

\`\`\`dart
// Handle common backup errors
Future<void> handleBackupError(String operation, List<dynamic> args) async {
  try {
    switch (operation) {
      case 'create':
        await pb.backups.create(args[0] as String);
        break;
      case 'delete':
        await pb.backups.delete(args[0] as String);
        break;
      case 'restore':
        await pb.backups.restore(args[0] as String);
        break;
      // ... other operations
    }
  } on ClientException catch (e) {
    switch (e.statusCode) {
      case 400:
        if (e.message?.contains('another backup/restore') == true) {
          print('Another backup or restore operation is in progress');
        } else if (e.message?.contains('already exists') == true) {
          print('Backup with this name already exists');
        } else {
          print('Invalid request: ${e.message}');
        }
        break;
      
      case 401:
        print('Not authenticated');
        break;
      
      case 403:
        print('Not a superuser');
        break;
      
      case 404:
        print('Backup not found');
        break;
      
      default:
        print('Unexpected error: $e');
    }
    rethrow;
  }
}
\`\`\`

## Best Practices

1. **Regular Backups**: Create backups regularly (daily, weekly, or based on your needs)
2. **Naming Convention**: Use clear, consistent naming (e.g., \`backup_YYYY-MM-DD.zip\`)
3. **Backup Rotation**: Implement cleanup to remove old backups and prevent storage issues
4. **Test Restores**: Periodically test restoring backups to ensure they work
5. **Off-site Storage**: Download and store backups in a separate location
6. **Pre-Restore Backup**: Always create a backup before restoring (if possible)
7. **Monitor Storage**: Monitor backup storage usage to prevent disk space issues
8. **Documentation**: Document your backup and restore procedures
9. **Automation**: Use cron jobs or schedulers for automated backups
10. **Verification**: Verify backup integrity after creation/download

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Concurrent Operations**: Only one backup or restore can run at a time
- **Restore Restart**: Restoring a backup restarts the application
- **UNIX Systems**: Restore primarily works on UNIX-based systems
- **Disk Space**: Restore requires significant free disk space (2x backup size recommended)
- **S3 Consistency**: S3 backups may not be immediately available after creation
- **Active Backups**: Cannot delete backups that are currently being created or restored

## Related Documentation

- [File API](./FILE_API.md) - File handling and tokens
- [Crons API](./CRONS_API.md) - Automated backup scheduling
- [Collection API](./COLLECTION_API.md) - Collection management
