# Management API Documentation

This document covers the management API capabilities available in the Dart SDK, which correspond to the features available in the backend management UI.

> **Note**: All management API operations require superuser authentication (🔐).

## Table of Contents

- [Settings Service](#settings-service)
  - [Application Configuration](#application-configuration)
  - [Mail Configuration](#mail-configuration)
  - [Storage Configuration](#storage-configuration)
  - [Backup Configuration](#backup-configuration)
  - [Log Configuration](#log-configuration)
- [Backup Service](#backup-service)
- [Log Service](#log-service)
- [Cron Service](#cron-service)
- [Health Service](#health-service)
- [Collection Service](#collection-service)

---

## Settings Service

The Settings Service provides comprehensive management of application settings, matching the capabilities available in the backend management UI.

### Application Configuration

Manage application settings including meta information, trusted proxy, rate limits, and batch configuration.

#### Get Application Settings

```dart
final settings = await pb.settings.getApplicationSettings();
// Returns: Map containing meta, trustedProxy, rateLimits, batch
```

**Example:**
```dart
final appSettings = await pb.settings.getApplicationSettings();
print(appSettings['meta']?['appName']); // Application name
print(appSettings['rateLimits']?['rules']); // Rate limit rules
```

#### Update Application Settings

```dart
await pb.settings.updateApplicationSettings(
  meta: {
    'appName': 'My App',
    'appURL': 'https://example.com',
    'hideControls': false,
  },
  trustedProxy: {
    'headers': ['X-Forwarded-For'],
    'useLeftmostIP': true,
  },
  rateLimits: {
    'enabled': true,
    'rules': [
      {
        'label': 'api/users',
        'duration': 3600,
        'maxRequests': 100,
      }
    ],
  },
  batch: {
    'enabled': true,
    'maxRequests': 100,
    'interval': 200,
  },
);
```

#### Individual Settings Updates

**Update Meta Settings:**
```dart
await pb.settings.updateMeta(
  appName: 'My App',
  appURL: 'https://example.com',
  senderName: 'My App',
  senderAddress: 'noreply@example.com',
  hideControls: false,
);
```

**Update Trusted Proxy:**
```dart
await pb.settings.updateTrustedProxy(
  headers: ['X-Forwarded-For', 'X-Real-IP'],
  useLeftmostIP: true,
);
```

**Update Rate Limits:**
```dart
await pb.settings.updateRateLimits(
  enabled: true,
  rules: [
    {
      'label': 'api/users',
      'audience': 'public',
      'duration': 3600,
      'maxRequests': 100,
    }
  ],
);
```

**Update Batch Configuration:**
```dart
await pb.settings.updateBatch(
  enabled: true,
  maxRequests: 100,
  timeout: 30,
  maxBodySize: 10485760,
);
```

---

### Mail Configuration

Manage SMTP email settings and sender information.

#### Get Mail Settings

```dart
final mailSettings = await pb.settings.getMailSettings();
// Returns: Map containing meta (senderName, senderAddress) and smtp
```

**Example:**
```dart
final mail = await pb.settings.getMailSettings();
print(mail['meta']?['senderName']); // Sender name
print(mail['smtp']?['host']); // SMTP host
```

#### Update Mail Settings

Update both sender info and SMTP configuration in one call:

```dart
await pb.settings.updateMailSettings(
  senderName: 'My App',
  senderAddress: 'noreply@example.com',
  smtp: {
    'enabled': true,
    'host': 'smtp.example.com',
    'port': 587,
    'username': 'user@example.com',
    'password': 'password',
    'authMethod': 'PLAIN',
    'tls': true,
    'localName': 'localhost',
  },
);
```

#### Update SMTP Only

```dart
await pb.settings.updateSMTP(
  enabled: true,
  host: 'smtp.example.com',
  port: 587,
  username: 'user@example.com',
  password: 'password',
  authMethod: 'PLAIN',
  tls: true,
  localName: 'localhost',
);
```

#### Test Email

Send a test email to verify SMTP configuration:

```dart
await pb.settings.testMail(
  'test@example.com',
  template: 'verification', // verification, password-reset, email-change, otp, login-alert
  collectionIdOrName: '_superusers', // Optional, defaults to _superusers
);
```

**Email Templates:**
- `verification` - Email verification template
- `password-reset` - Password reset template
- `email-change` - Email change confirmation template
- `otp` - One-time password template
- `login-alert` - Login alert template

---

### Storage Configuration

Manage S3 storage configuration for file storage.

#### Get Storage S3 Configuration

```dart
final s3Config = await pb.settings.getStorageS3();
// Returns: Map containing enabled, bucket, region, endpoint, accessKey, secret, forcePathStyle
```

#### Update Storage S3 Configuration

```dart
await pb.settings.updateStorageS3(
  enabled: true,
  bucket: 'my-bucket',
  region: 'us-east-1',
  endpoint: 'https://s3.amazonaws.com',
  accessKey: 'ACCESS_KEY',
  secret: 'SECRET_KEY',
  forcePathStyle: false,
);
```

#### Test Storage S3 Connection

```dart
await pb.settings.testStorageS3();
// Returns void, throws exception if connection fails
```

---

### Backup Configuration

Manage auto-backup scheduling and S3 storage for backups.

#### Get Backup Settings

```dart
final backupSettings = await pb.settings.getBackupSettings();
// Returns: Map containing cron, cronMaxKeep, s3
```

**Example:**
```dart
final backups = await pb.settings.getBackupSettings();
print(backups['cron']); // Cron expression (e.g., "0 0 * * *")
print(backups['cronMaxKeep']); // Maximum backups to keep
```

#### Update Backup Settings

```dart
await pb.settings.updateBackupSettings(
  cron: '0 0 * * *', // Daily at midnight (empty string to disable)
  cronMaxKeep: 10, // Keep maximum 10 backups
  s3: {
    'enabled': true,
    'bucket': 'backup-bucket',
    'region': 'us-east-1',
    'endpoint': 'https://s3.amazonaws.com',
    'accessKey': 'ACCESS_KEY',
    'secret': 'SECRET_KEY',
    'forcePathStyle': false,
  },
);
```

#### Set Auto-Backup Schedule

```dart
// Enable daily backups at midnight, keep 10 backups
await pb.settings.setAutoBackupSchedule('0 0 * * *', cronMaxKeep: 10);

// Disable auto-backup
await pb.settings.disableAutoBackup();
```

**Common Cron Expressions:**
- `'0 0 * * *'` - Daily at midnight
- `'0 0 * * 0'` - Weekly on Sunday at midnight
- `'0 0 1 * *'` - Monthly on the 1st at midnight
- `'0 0 * * 1,3'` - Twice weekly (Monday and Wednesday)

#### Test Backups S3 Connection

```dart
await pb.settings.testBackupsS3();
// Returns void, throws exception if connection fails
```

---

### Log Configuration

Manage log retention and logging settings.

#### Get Log Settings

```dart
final logSettings = await pb.settings.getLogSettings();
// Returns: Map containing maxDays, minLevel, logIP, logAuthId
```

#### Update Log Settings

```dart
await pb.settings.updateLogSettings(
  maxDays: 30, // Retain logs for 30 days
  minLevel: 0, // Minimum log level (negative=debug/info, 0=warning, positive=error)
  logIP: true, // Log IP addresses
  logAuthId: true, // Log authentication IDs
);
```

#### Individual Log Settings

```dart
// Set log retention days
await pb.settings.setLogRetentionDays(30);

// Set minimum log level
await pb.settings.setMinLogLevel(0); // -100 to 100

// Enable/disable IP logging
await pb.settings.setLogIPAddresses(true);

// Enable/disable auth ID logging
await pb.settings.setLogAuthIds(true);
```

**Log Levels:**
- Negative values: Debug/Info levels
- `0`: Default/Warning level
- Positive values: Error levels

---

## Backup Service

Manage application backups - create, list, upload, delete, and restore backups.

### List All Backups

```dart
final backups = await pb.backups.getFullList();
// Returns: List<BackupFileInfo> with key, size, modified
```

**Example:**
```dart
final backups = await pb.backups.getFullList();
for (final backup in backups) {
  print('${backup.key}: ${backup.size} bytes, modified: ${backup.modified}');
}
```

### Create Backup

```dart
await pb.backups.create('backup-2024-01-01');
// Creates a new backup with the specified basename
```

### Upload Backup

Upload an existing backup file:

```dart
import 'package:http/http.dart' as http;

final file = http.MultipartFile.fromBytes(
  'file',
  backupData,
  filename: 'backup.zip',
);
await pb.backups.upload(file);
```

### Delete Backup

```dart
await pb.backups.delete('backup-2024-01-01');
// Deletes the specified backup file
```

### Restore Backup

```dart
await pb.backups.restore('backup-2024-01-01');
// Restores the application from the specified backup
```

**⚠️ Warning**: Restoring a backup will replace all current application data!

### Get Backup Download URL

```dart
// First, get a file token
final token = await pb.files.getToken();

// Then build the download URL
final url = pb.backups.getDownloadURL(token, 'backup-2024-01-01');
print(url); // Full URI to download the backup
```

---

## Log Service

Query and analyze application logs.

### List Logs

```dart
final result = await pb.logs.getList(
  page: 1,
  perPage: 30,
  filter: 'level >= 0',
  sort: '-created',
);
// Returns: ResultList<LogModel> with page, perPage, totalItems, totalPages, items
```

**Example with filtering:**
```dart
// Get error logs from the last 24 hours
final yesterday = DateTime.now().subtract(const Duration(days: 1));

final errorLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'level > 0 && created >= "${yesterday.toIso8601String()}"',
  sort: '-created',
);

for (final log in errorLogs.items) {
  print('[${log.level}] ${log.message}');
}
```

### Get Single Log

```dart
final log = await pb.logs.getOne('log-id');
// Returns: LogModel with full log details
```

### Get Log Statistics

```dart
final stats = await pb.logs.getStats(
  query: {'filter': 'level >= 0'}, // Optional filter
);
// Returns: List<LogStat> with total, date - hourly statistics
```

**Example:**
```dart
final stats = await pb.logs.getStats();
for (final stat in stats) {
  print('${stat.date}: ${stat.total} requests');
}
```

---

## Cron Service

Manage and execute cron jobs.

### List All Cron Jobs

```dart
final cronJobs = await pb.crons.getFullList();
// Returns: List<CronJob> with id, expression
```

**Example:**
```dart
final cronJobs = await pb.crons.getFullList();
for (final job in cronJobs) {
  print('Job ${job.id}: ${job.expression}');
}
```

### Run Cron Job

Manually trigger a cron job:

```dart
await pb.crons.run('job-id');
// Executes the specified cron job immediately
```

**Example:**
```dart
final cronJobs = await pb.crons.getFullList();
final backupJob = cronJobs.firstWhere(
  (job) => job.id.contains('backup'),
  orElse: () => cronJobs.first,
);
await pb.crons.run(backupJob.id);
print('Backup job executed manually');
```

---

## Health Service

Check the health status of the API.

### Check Health

```dart
final health = await pb.health.check();
// Returns: Health status information
```

**Example:**
```dart
try {
  final health = await pb.health.check();
  print('API is healthy: $health');
} catch (error) {
  print('Health check failed: $error');
}
```

---

## Collection Service

Manage collections (schemas) programmatically.

### List Collections

```dart
final collections = await pb.collections.getList(page: 1, perPage: 30);
// Returns: Paginated list of collections
```

### Get Collection

```dart
final collection = await pb.collections.getOne('collection-id-or-name');
// Returns: Full collection schema
```

### Create Collection

```dart
final collection = await pb.collections.create(
  body: {
    'name': 'posts',
    'type': 'base',
    'schema': [
      {
        'name': 'title',
        'type': 'text',
        'required': true,
      },
      {
        'name': 'content',
        'type': 'editor',
        'required': false,
      }
    ],
  },
);
```

### Update Collection

```dart
await pb.collections.update(
  'collection-id',
  body: {
    'schema': [
      // Updated schema
    ],
  },
);
```

### Delete Collection

```dart
await pb.collections.delete('collection-id');
```

### Truncate Collection

Delete all records in a collection (keeps the schema):

```dart
await pb.collections.truncate('collection-id');
```

### Import Collections

```dart
final collections = [
  {
    'name': 'collection1',
    // ... collection schema
  },
  {
    'name': 'collection2',
    // ... collection schema
  }
];

await pb.collections.import(
  collections,
  deleteMissing: false, // false = don't delete missing collections
);
```

---

## Complete Example: Automated Backup Management

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.collection('_superusers').authWithPassword(
  'admin@example.com',
  'password',
);

// Check current backup settings
final backupSettings = await pb.settings.getBackupSettings();
print('Current backup schedule: ${backupSettings['cron']}');

// List all existing backups
final backups = await pb.backups.getFullList();
print('Found ${backups.length} backups');

// Create a new backup
final today = DateTime.now().toIso8601String().split('T')[0];
await pb.backups.create('manual-backup-$today');
print('Backup created successfully');

// Get updated backup list
final updatedBackups = await pb.backups.getFullList();
print('Now have ${updatedBackups.length} backups');

// Configure auto-backup (daily at 2 AM, keep 7 backups)
await pb.settings.setAutoBackupSchedule('0 2 * * *', cronMaxKeep: 7);
print('Auto-backup configured');

// Test backup S3 connection if configured
try {
  await pb.settings.testBackupsS3();
  print('S3 backup storage is working');
} catch (error) {
  print('S3 backup storage test failed: $error');
}
```

---

## Complete Example: Log Monitoring

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.collection('_superusers').authWithPassword(
  'admin@example.com',
  'password',
);

// Get log settings
final logSettings = await pb.settings.getLogSettings();
print('Log retention: ${logSettings['maxDays']} days');
print('Minimum log level: ${logSettings['minLevel']}');

// Get recent error logs
final errorLogs = await pb.logs.getList(
  page: 1,
  perPage: 20,
  filter: 'level > 0',
  sort: '-created',
);

print('Found ${errorLogs.totalItems} error logs');
for (final log in errorLogs.items) {
  print('[${log.level}] ${log.message} - ${log.created}');
}

// Get hourly statistics for the last 24 hours
final yesterday = DateTime.now().subtract(const Duration(days: 1));
final stats = await pb.logs.getStats(
  query: {
    'filter': 'created >= "${yesterday.toIso8601String()}"',
  },
);

print('Hourly request statistics:');
for (final stat in stats) {
  print('${stat.date}: ${stat.total} requests');
}

// Update log settings to retain logs for 14 days
await pb.settings.setLogRetentionDays(14);
print('Log retention updated to 14 days');
```

---

## Complete Example: Application Configuration Management

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.collection('_superusers').authWithPassword(
  'admin@example.com',
  'password',
);

// Get current application settings
final appSettings = await pb.settings.getApplicationSettings();
print('App Name: ${appSettings['meta']?['appName']}');
print('App URL: ${appSettings['meta']?['appURL']}');

// Update application configuration
await pb.settings.updateApplicationSettings(
  meta: {
    'appName': 'My Production App',
    'appURL': 'https://api.example.com',
    'hideControls': false,
  },
  rateLimits: {
    'enabled': true,
    'rules': [
      {
        'label': 'api/users',
        'duration': 3600,
        'maxRequests': 100,
      },
      {
        'label': 'api/posts',
        'duration': 3600,
        'maxRequests': 200,
      }
    ],
  },
  batch: {
    'enabled': true,
    'maxRequests': 100,
    'interval': 200,
  },
);

print('Application settings updated');

// Configure trusted proxy
await pb.settings.updateTrustedProxy(
  headers: ['X-Forwarded-For', 'X-Real-IP'],
  useLeftmostIP: true,
);

print('Trusted proxy configured');
```

---

## Error Handling

All management API methods can throw `ClientException`. Always handle errors appropriately:

```dart
try {
  await pb.backups.create('my-backup');
  print('Backup created successfully');
} on ClientException catch (error) {
  if (error.statusCode == 401) {
    print('Authentication required');
  } else if (error.statusCode == 403) {
    print('Superuser access required');
  } else {
    print('Error: ${error.response}');
  }
} catch (error) {
  print('Unexpected error: $error');
}
```

---

## Notes

1. **Authentication**: All management API operations require superuser authentication. Use `pb.collection('_superusers').authWithPassword()` to authenticate.

2. **Rate Limiting**: Be mindful of rate limits when making multiple management API calls.

3. **Backup Safety**: Always test backup restoration in a safe environment before using in production.

4. **Log Retention**: Setting appropriate log retention helps manage storage usage.

5. **Cron Jobs**: Manual cron execution is useful for testing but should be used carefully in production.

6. **File Upload**: When uploading backups, use `http.MultipartFile` with the field name `'file'`.

For more information on specific services, see:
- [Settings API](./SETTINGS_API.md) - Detailed settings documentation
- [Backups API](./BACKUPS_API.md) - Detailed backup operations
- [Logs API](./LOGS_API.md) - Detailed log operations
- [Collections API](./COLLECTION_API.md) - Collection management

