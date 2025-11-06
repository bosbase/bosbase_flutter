# Health API - Dart SDK Documentation

## Overview

The Health API provides a simple endpoint to check the health status of the server. It returns basic health information and, when authenticated as a superuser, provides additional diagnostic information about the server state.

**Key Features:**
- No authentication required for basic health check
- Superuser authentication provides additional diagnostic data
- Lightweight endpoint for monitoring and health checks
- Supports both GET and HEAD methods

**Backend Endpoints:**
- `GET /api/health` - Check health status
- `HEAD /api/health` - Check health status (HEAD method)

**Note**: The health endpoint is publicly accessible, but superuser authentication provides additional information.

## Authentication

Basic health checks do not require authentication:

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Basic health check (no auth required)
final health = await pb.health.check();
\`\`\`

For additional diagnostic information, authenticate as a superuser:

\`\`\`dart
// Authenticate as superuser for extended health data
await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
final health = await pb.health.check();
\`\`\`

## Health Check Response Structure

### Basic Response (Guest/Regular User)

\`\`\`dart
HealthCheck(
  code: 200,
  message: "API is healthy.",
  data: {},
)
\`\`\`

### Superuser Response

\`\`\`dart
HealthCheck(
  code: 200,
  message: "API is healthy.",
  data: {
    'canBackup': bool,           // Whether backup operations are allowed
    'realIP': String,            // Real IP address of the client
    'requireS3': bool,           // Whether S3 storage is required
    'possibleProxyHeader': String // Detected proxy header (if behind reverse proxy)
  },
)
\`\`\`

## Check Health Status

Returns the health status of the API server.

### Basic Usage

\`\`\`dart
// Simple health check
final health = await pb.health.check();

print(health.message); // "API is healthy."
print(health.code);    // 200
\`\`\`

### With Superuser Authentication

\`\`\`dart
// Authenticate as superuser first
await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');

// Get extended health information
final health = await pb.health.check();

print(health.data['canBackup']);           // true/false
print(health.data['realIP']);              // "192.168.1.100"
print(health.data['requireS3']);           // false
print(health.data['possibleProxyHeader']); // "" or header name
\`\`\`

## Response Fields

### Common Fields (All Users)

| Field | Type | Description |
|-------|------|-------------|
| \`code\` | int | HTTP status code (always 200 for healthy server) |
| \`message\` | String | Health status message ("API is healthy.") |
| \`data\` | Map<String, dynamic> | Health data (empty for non-superusers, populated for superusers) |

### Superuser-Only Fields (in \`data\`)

| Field | Type | Description |
|-------|------|-------------|
| \`canBackup\` | bool | \`true\` if backup/restore operations can be performed, \`false\` if a backup/restore is currently in progress |
| \`realIP\` | String | The real IP address of the client (useful when behind proxies) |
| \`requireS3\` | bool | \`true\` if S3 storage is required (local fallback disabled), \`false\` otherwise |
| \`possibleProxyHeader\` | String | Detected proxy header name (e.g., "X-Forwarded-For", "CF-Connecting-IP") if the server appears to be behind a reverse proxy, empty string otherwise |

## Use Cases

### 1. Basic Health Monitoring

\`\`\`dart
Future<bool> checkServerHealth() async {
  try {
    final health = await pb.health.check();
    
    if (health.code == 200 && health.message == "API is healthy.") {
      print('✓ Server is healthy');
      return true;
    } else {
      print('✗ Server health check failed');
      return false;
    }
  } catch (e) {
    print('✗ Health check error: $e');
    return false;
  }
}

// Use in monitoring
Timer.periodic(Duration(minutes: 1), (_) async {
  final isHealthy = await checkServerHealth();
  if (!isHealthy) {
    // Alert or take action
    print('Server health check failed!');
  }
});
\`\`\`

### 2. Backup Readiness Check

\`\`\`dart
Future<bool> canPerformBackup() async {
  try {
    // Authenticate as superuser
    await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
    
    final health = await pb.health.check();
    
    final canBackup = health.data['canBackup'] as bool? ?? false;
    
    if (!canBackup) {
      print('⚠️ Backup operation is currently in progress');
      return false;
    }
    
    print('✓ Backup operations are allowed');
    return true;
  } catch (e) {
    print('Failed to check backup readiness: $e');
    return false;
  }
}

// Use before creating backups
if (await canPerformBackup()) {
  await pb.backups.create('backup.zip');
}
\`\`\`

### 3. Monitoring Dashboard

\`\`\`dart
class HealthMonitor {
  final Bosbase pb;
  bool isSuperuser = false;

  HealthMonitor(this.pb);

  Future<bool> authenticateAsSuperuser(String email, String password) async {
    try {
      await pb.collection('_superusers').authWithPassword(email, password);
      isSuperuser = true;
      return true;
    } catch (e) {
      print('Superuser authentication failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final health = await pb.health.check();
      
      final status = <String, dynamic>{
        'healthy': health.code == 200,
        'message': health.message,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      if (isSuperuser && health.data.isNotEmpty) {
        status['diagnostics'] = {
          'canBackup': health.data['canBackup'],
          'realIP': health.data['realIP'],
          'requireS3': health.data['requireS3'],
          'behindProxy': health.data['possibleProxyHeader'] != null &&
                         (health.data['possibleProxyHeader'] as String).isNotEmpty,
          'proxyHeader': health.data['possibleProxyHeader'] ?? '',
        };
      }
      
      return status;
    } catch (e) {
      return {
        'healthy': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}

// Usage
final monitor = HealthMonitor(pb);
await monitor.authenticateAsSuperuser('admin@example.com', 'password');
final status = await monitor.getHealthStatus();
print('Health Status: $status');
\`\`\`

### 4. Load Balancer Health Check

\`\`\`dart
import 'package:http/http.dart' as http;

// Simple health check for load balancers
Future<bool> simpleHealthCheck() async {
  try {
    final health = await pb.health.check();
    return health.code == 200;
  } catch (e) {
    return false;
  }
}

// Use in server route for load balancer
Future<void> handleHealthCheck(HttpRequest request) async {
  final isHealthy = await simpleHealthCheck();
  if (isHealthy) {
    request.response
      ..statusCode = 200
      ..write(jsonEncode({'status': 'healthy'}))
      ..close();
  } else {
    request.response
      ..statusCode = 503
      ..write(jsonEncode({'status': 'unhealthy'}))
      ..close();
  }
}
\`\`\`

### 5. Proxy Detection

\`\`\`dart
Future<Map<String, dynamic>> checkProxySetup() async {
  await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
  
  final health = await pb.health.check();
  final proxyHeader = health.data['possibleProxyHeader'] as String? ?? '';
  
  if (proxyHeader.isNotEmpty) {
    print('⚠️ Server appears to be behind a reverse proxy');
    print('   Detected proxy header: $proxyHeader');
    print('   Real IP: ${health.data['realIP']}');
    
    // Provide guidance on trusted proxy configuration
    print('   Ensure TrustedProxy settings are configured correctly in admin panel');
  } else {
    print('✓ No reverse proxy detected (or properly configured)');
  }
  
  return {
    'behindProxy': proxyHeader.isNotEmpty,
    'proxyHeader': proxyHeader.isNotEmpty ? proxyHeader : null,
    'realIP': health.data['realIP'] ?? null,
  };
}
\`\`\`

### 6. Pre-Flight Checks

\`\`\`dart
Future<Map<String, dynamic>> preFlightCheck() async {
  final checks = <String, dynamic>{
    'serverHealthy': false,
    'canBackup': false,
    'storageConfigured': false,
    'issues': <String>[],
  };
  
  try {
    // Basic health check
    final health = await pb.health.check();
    checks['serverHealthy'] = health.code == 200;
    
    if (!checks['serverHealthy']) {
      (checks['issues'] as List<String>).add('Server health check failed');
      return checks;
    }
    
    // Authenticate as superuser for extended checks
    try {
      await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
      
      final detailedHealth = await pb.health.check();
      
      final canBackup = detailedHealth.data['canBackup'] as bool? ?? false;
      final requireS3 = detailedHealth.data['requireS3'] as bool? ?? false;
      
      checks['canBackup'] = canBackup;
      checks['storageConfigured'] = !requireS3;
      
      if (!canBackup) {
        (checks['issues'] as List<String>).add('Backup operations are currently unavailable');
      }
      
      if (requireS3) {
        (checks['issues'] as List<String>).add('S3 storage is required but may not be configured');
      }
    } catch (authError) {
      (checks['issues'] as List<String>).add('Superuser authentication failed - limited diagnostics available');
    }
  } catch (e) {
    (checks['issues'] as List<String>).add('Health check error: $e');
  }
  
  return checks;
}

// Use before critical operations
final checks = await preFlightCheck();
final issues = checks['issues'] as List<String>;
if (issues.isNotEmpty) {
  print('Pre-flight check issues: $issues');
  // Handle issues before proceeding
}
\`\`\`

### 7. Automated Backup Scheduler

\`\`\`dart
class BackupScheduler {
  final Bosbase pb;

  BackupScheduler(this.pb);

  Future<bool> waitForBackupAvailability({Duration maxWait = const Duration(minutes: 5)}) async {
    final startTime = DateTime.now();
    const checkInterval = Duration(seconds: 5);
    
    while (DateTime.now().difference(startTime) < maxWait) {
      try {
        final health = await pb.health.check();
        
        final canBackup = health.data['canBackup'] as bool? ?? false;
        
        if (canBackup) {
          return true;
        }
        
        print('Backup in progress, waiting...');
        await Future.delayed(checkInterval);
      } catch (e) {
        print('Health check failed: $e');
        return false;
      }
    }
    
    print('Timeout waiting for backup availability');
    return false;
  }

  Future<void> scheduleBackup(String backupName) async {
    // Wait for backup operations to be available
    final isAvailable = await waitForBackupAvailability();
    
    if (!isAvailable) {
      throw Exception('Backup operations are not available');
    }
    
    // Create the backup
    await pb.backups.create(backupName);
    print('Backup "$backupName" created');
  }
}

// Usage
final scheduler = BackupScheduler(pb);
await scheduler.scheduleBackup('scheduled_backup.zip');
\`\`\`

## Error Handling

\`\`\`dart
Future<Map<String, dynamic>> safeHealthCheck() async {
  try {
    final health = await pb.health.check();
    return {
      'success': true,
      'data': health.toJson(),
    };
  } catch (e) {
    // Network errors, server down, etc.
    return {
      'success': false,
      'error': e.toString(),
      'code': (e is ClientException) ? e.statusCode : 0,
    };
  }
}

// Handle different error scenarios
final result = await safeHealthCheck();
if (!result['success'] as bool) {
  final code = result['code'] as int;
  if (code == 0) {
    print('Network error or server unreachable');
  } else {
    print('Server returned error: $code');
  }
}
\`\`\`

## Best Practices

1. **Monitoring**: Use health checks for regular monitoring (e.g., every 30-60 seconds)
2. **Load Balancers**: Configure load balancers to use the health endpoint for health checks
3. **Pre-flight Checks**: Check \`canBackup\` before initiating backup operations
4. **Error Handling**: Always handle errors gracefully as the server may be down
5. **Rate Limiting**: Don't poll the health endpoint too frequently (avoid spamming)
6. **Caching**: Consider caching health check results for a few seconds to reduce load
7. **Logging**: Log health check results for troubleshooting and monitoring
8. **Alerting**: Set up alerts for consecutive health check failures
9. **Superuser Auth**: Only authenticate as superuser when you need diagnostic information
10. **Proxy Configuration**: Use \`possibleProxyHeader\` to detect and configure reverse proxy settings

## Response Codes

| Code | Meaning |
|------|---------|
| 200 | Server is healthy |
| Network Error | Server is unreachable or down |

## Limitations

- **No Detailed Metrics**: The health endpoint does not provide detailed performance metrics
- **Basic Status Only**: Returns basic status, not detailed system information
- **Superuser Required**: Extended diagnostics require superuser authentication
- **No Historical Data**: Only returns current status, no historical health data

## Head Method Support

The health endpoint also supports the HEAD method for lightweight checks:

\`\`\`dart
import 'package:http/http.dart' as http;

// Using HEAD method
final response = await http.head(Uri.parse('http://127.0.0.1:8090/api/health'));

if (response.statusCode == 200) {
  print('Server is healthy');
}
\`\`\`

## Related Documentation

- [Backups API](./BACKUPS_API.md) - Using \`canBackup\` to check backup readiness
- [Authentication](./AUTHENTICATION.md) - Superuser authentication
- [Settings API](./SETTINGS_API.md) - Configuring trusted proxy settings
