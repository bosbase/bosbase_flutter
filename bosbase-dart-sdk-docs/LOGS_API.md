# Logs API - Dart SDK Documentation

## Overview

The Logs API provides endpoints for viewing and analyzing application logs. All operations require superuser authentication and allow you to query request logs, filter by various criteria, and get aggregated statistics.

**Key Features:**
- List and paginate logs
- View individual log entries
- Filter logs by status, URL, method, IP, etc.
- Sort logs by various fields
- Get hourly aggregated statistics
- Filter statistics by criteria

**Backend Endpoints:**
- `GET /api/logs` - List logs
- `GET /api/logs/{id}` - View log
- `GET /api/logs/stats` - Get statistics

**Note**: All Logs API operations require superuser authentication.

## Authentication

All Logs API operations require superuser authentication:

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
\`\`\`

## List Logs

Returns a paginated list of logs with support for filtering and sorting.

### Basic Usage

\`\`\`dart
// Basic list
final result = await pb.logs.getList();

print(result.page);        // 1
print(result.perPage);     // 30
print(result.totalItems);  // Total logs count
print(result.items);       // List of log entries
\`\`\`

### Log Entry Structure

Each log entry contains:

\`\`\`dart
{
  'id': 'ai5z3aoed6809au',
  'created': '2024-10-27 09:28:19.524Z',
  'level': 0,
  'message': 'GET /api/collections/posts/records',
  'data': {
    'auth': '_superusers',
    'execTime': 2.392327,
    'method': 'GET',
    'referer': 'http://localhost:8090/_/',
    'remoteIP': '127.0.0.1',
    'status': 200,
    'type': 'request',
    'url': '/api/collections/posts/records?page=1',
    'userAgent': 'Mozilla/5.0...',
    'userIP': '127.0.0.1'
  }
}
\`\`\`

### Filtering Logs

\`\`\`dart
// Filter by HTTP status code
final errorLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.status >= 400',
);

// Filter by method
final getLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.method = "GET"',
);

// Filter by URL pattern
final apiLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.url ~ "/api/"',
);

// Filter by IP address
final ipLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.remoteIP = "127.0.0.1"',
);

// Filter by execution time (slow requests)
final slowLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.execTime > 1.0',
);

// Filter by log level
final errorLevelLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'level > 0',
);

// Filter by date range
final recentLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'created >= "2024-10-27 00:00:00"',
);
\`\`\`

### Complex Filters

\`\`\`dart
// Multiple conditions
final complexFilter = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.status >= 400 && data.method = "POST" && data.execTime > 0.5',
);

// Exclude superuser requests
final userLogs = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.auth != "_superusers"',
);

// Specific endpoint errors
final endpointErrors = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.url ~ "/api/collections/posts/records" && data.status >= 400',
);

// Errors or slow requests
final problems = await pb.logs.getList(
  page: 1,
  perPage: 50,
  filter: 'data.status >= 400 || data.execTime > 2.0',
);
\`\`\`

### Sorting Logs

\`\`\`dart
// Sort by creation date (newest first)
final recent = await pb.logs.getList(
  page: 1,
  perPage: 50,
  sort: '-created',
);

// Sort by execution time (slowest first)
final slowest = await pb.logs.getList(
  page: 1,
  perPage: 50,
  sort: '-data.execTime',
);

// Sort by status code
final byStatus = await pb.logs.getList(
  page: 1,
  perPage: 50,
  sort: 'data.status',
);

// Sort by rowid (most efficient)
final byRowId = await pb.logs.getList(
  page: 1,
  perPage: 50,
  sort: '-rowid',
);

// Multiple sort fields
final multiSort = await pb.logs.getList(
  page: 1,
  perPage: 50,
  sort: '-created,level',
);
\`\`\`

## View Log

Retrieve a single log entry by ID:

\`\`\`dart
// Get specific log
final log = await pb.logs.getOne('ai5z3aoed6809au');

print(log.message);
print(log.data['status']);
print(log.data['execTime']);
\`\`\`

### Log Details

\`\`\`dart
Future<void> analyzeLog(String logId) async {
  final log = await pb.logs.getOne(logId);
  
  print('Log ID: ${log.id}');
  print('Created: ${log.created}');
  print('Level: ${log.level}');
  print('Message: ${log.message}');
  
  if (log.data['type'] == 'request') {
    print('Method: ${log.data['method']}');
    print('URL: ${log.data['url']}');
    print('Status: ${log.data['status']}');
    print('Execution Time: ${log.data['execTime']} ms');
    print('Remote IP: ${log.data['remoteIP']}');
    print('User Agent: ${log.data['userAgent']}');
    print('Auth Collection: ${log.data['auth']}');
  }
}
\`\`\`

## Logs Statistics

Get hourly aggregated statistics for logs:

### Basic Usage

\`\`\`dart
// Get all statistics
final stats = await pb.logs.getStats();

// Each stat entry contains:
// LogStat(date: DateTime, total: 4)
\`\`\`

### Filtered Statistics

\`\`\`dart
// Statistics for errors only
final errorStats = await pb.logs.getStats(
  filter: 'data.status >= 400',
);

// Statistics for specific endpoint
final endpointStats = await pb.logs.getStats(
  filter: 'data.url ~ "/api/collections/posts/records"',
);

// Statistics for slow requests
final slowStats = await pb.logs.getStats(
  filter: 'data.execTime > 1.0',
);

// Statistics excluding superuser requests
final userStats = await pb.logs.getStats(
  filter: 'data.auth != "_superusers"',
);
\`\`\`

### Visualizing Statistics

\`\`\`dart
Future<List<ChartDataPoint>> getChartData() async {
  final stats = await pb.logs.getStats(
    filter: 'created >= "2024-10-27 00:00:00"',
  );
  
  return stats.map((stat) => ChartDataPoint(
    x: stat.date,
    y: stat.total,
  )).toList();
}
\`\`\`

## Filter Syntax

Logs support filtering with a flexible syntax similar to records filtering.

### Supported Fields

**Direct Fields:**
- \`id\` - Log ID
- \`created\` - Creation timestamp
- \`updated\` - Update timestamp
- \`level\` - Log level (0 = info, higher = warnings/errors)
- \`message\` - Log message

**Data Fields (nested):**
- \`data.status\` - HTTP status code
- \`data.method\` - HTTP method (GET, POST, etc.)
- \`data.url\` - Request URL
- \`data.execTime\` - Execution time in seconds
- \`data.remoteIP\` - Remote IP address
- \`data.userIP\` - User IP address
- \`data.userAgent\` - User agent string
- \`data.referer\` - Referer header
- \`data.auth\` - Auth collection ID
- \`data.type\` - Log type (usually "request")

### Filter Operators

| Operator | Description | Example |
|----------|-------------|---------|
| \`=\` | Equal | \`data.status = 200\` |
| \`!=\` | Not equal | \`data.status != 200\` |
| \`>\` | Greater than | \`data.status > 400\` |
| \`>=\` | Greater than or equal | \`data.status >= 400\` |
| \`<\` | Less than | \`data.execTime < 0.5\` |
| \`<=\` | Less than or equal | \`data.execTime <= 1.0\` |
| \`~\` | Contains/Like | \`data.url ~ "/api/"\` |
| \`!~\` | Not contains | \`data.url !~ "/admin/"\` |
| \`?=\` | Any equal | \`data.method ?= "GET,POST"\` |
| \`?!=\` | Any not equal | \`data.method ?!= "DELETE"\` |
| \`?>\` | Any greater | \`data.status ?> "400,500"\` |
| \`?>=\` | Any greater or equal | \`data.status ?>= "400,500"\` |
| \`?<\` | Any less | \`data.execTime ?< "0.5,1.0"\` |
| \`?<=\` | Any less or equal | \`data.execTime ?<= "1.0,2.0"\` |
| \`?~\` | Any contains | \`data.url ?~ "/api/,/admin/"\` |
| \`?!~\` | Any not contains | \`data.url ?!~ "/test/,/debug/"\` |

### Logical Operators

- \`&&\` - AND
- \`||\` - OR
- \`()\` - Grouping

### Filter Examples

\`\`\`dart
// Simple equality
filter: 'data.method = "GET"'

// Range filter
filter: 'data.status >= 400 && data.status < 500'

// Pattern matching
filter: 'data.url ~ "/api/collections/"'

// Complex logic
filter: '(data.status >= 400 || data.execTime > 2.0) && data.method = "POST"'

// Exclude patterns
filter: 'data.url !~ "/admin/" && data.auth != "_superusers"'

// Date range
filter: 'created >= "2024-10-27 00:00:00" && created <= "2024-10-28 00:00:00"'
\`\`\`

## Sort Options

Supported sort fields:

- \`@random\` - Random order
- \`rowid\` - Row ID (most efficient, use negative for DESC)
- \`id\` - Log ID
- \`created\` - Creation date
- \`updated\` - Update date
- \`level\` - Log level
- \`message\` - Message text
- \`data.*\` - Any data field (e.g., \`data.status\`, \`data.execTime\`)

\`\`\`dart
// Sort examples
sort: '-created'              // Newest first
sort: 'data.execTime'         // Fastest first
sort: '-data.execTime'        // Slowest first
sort: '-rowid'                // Most efficient (newest)
sort: 'level,-created'        // By level, then newest
\`\`\`

## Complete Examples

### Example 1: Error Monitoring Dashboard

\`\`\`dart
Future<ErrorMetrics> getErrorMetrics() async {
  // Get error logs from last 24 hours
  final yesterday = DateTime.now().subtract(Duration(days: 1));
  final dateFilter = 'created >= "${yesterday.toIso8601String().split('T')[0]} 00:00:00"';
  
  // 4xx errors
  final clientErrors = await pb.logs.getList(
    page: 1,
    perPage: 100,
    filter: '$dateFilter && data.status >= 400 && data.status < 500',
    sort: '-created',
  );
  
  // 5xx errors
  final serverErrors = await pb.logs.getList(
    page: 1,
    perPage: 100,
    filter: '$dateFilter && data.status >= 500',
    sort: '-created',
  );
  
  // Get hourly statistics
  final errorStats = await pb.logs.getStats(
    filter: '$dateFilter && data.status >= 400',
  );
  
  return ErrorMetrics(
    clientErrors: clientErrors.items,
    serverErrors: serverErrors.items,
    stats: errorStats,
  );
}
\`\`\`

### Example 2: Performance Analysis

\`\`\`dart
Future<Map<String, EndpointStats>> analyzePerformance() async {
  // Get slow requests
  final slowRequests = await pb.logs.getList(
    page: 1,
    perPage: 50,
    filter: 'data.execTime > 1.0',
    sort: '-data.execTime',
  );
  
  // Analyze by endpoint
  final endpointStats = <String, EndpointStats>{};
  for (final log in slowRequests.items) {
    final url = log.data['url'].toString().split('?')[0]; // Remove query params
    endpointStats.putIfAbsent(url, () => EndpointStats());
    
    endpointStats[url]!.count++;
    endpointStats[url]!.totalTime += log.data['execTime'] as num;
    endpointStats[url]!.maxTime = max(
      endpointStats[url]!.maxTime,
      log.data['execTime'] as num,
    );
  }
  
  // Calculate averages
  endpointStats.forEach((url, stats) {
    stats.avgTime = stats.totalTime / stats.count;
  });
  
  return endpointStats;
}

class EndpointStats {
  int count = 0;
  double totalTime = 0;
  double maxTime = 0;
  double avgTime = 0;
}
\`\`\`

### Example 3: Security Monitoring

\`\`\`dart
Future<SecurityReport> monitorSecurity() async {
  // Failed authentication attempts
  final authFailures = await pb.logs.getList(
    page: 1,
    perPage: 100,
    filter: 'data.url ~ "/api/collections/" && data.url ~ "/auth-with-password" && data.status >= 400',
    sort: '-created',
  );
  
  // Suspicious IPs (multiple failed attempts)
  final ipCounts = <String, int>{};
  for (final log in authFailures.items) {
    final ip = log.data['remoteIP'].toString();
    ipCounts[ip] = (ipCounts[ip] ?? 0) + 1;
  }
  
  final suspiciousIPs = ipCounts.entries
      .where((entry) => entry.value >= 5)
      .map((entry) => SuspiciousIP(ip: entry.key, attempts: entry.value))
      .toList();
  
  return SecurityReport(
    totalFailures: authFailures.totalItems,
    suspiciousIPs: suspiciousIPs,
  );
}

class SuspiciousIP {
  final String ip;
  final int attempts;
  SuspiciousIP({required this.ip, required this.attempts});
}

class SecurityReport {
  final int totalFailures;
  final List<SuspiciousIP> suspiciousIPs;
  SecurityReport({required this.totalFailures, required this.suspiciousIPs});
}
\`\`\`

### Example 4: Log Viewer Widget (Flutter)

\`\`\`dart
class LogViewerWidget extends StatefulWidget {
  @override
  _LogViewerWidgetState createState() => _LogViewerWidgetState();
}

class _LogViewerWidgetState extends State<LogViewerWidget> {
  final pb = Bosbase('http://127.0.0.1:8090');
  int currentPage = 1;
  final int perPage = 50;
  String filter = '';
  String sort = '-created';
  List<LogModel> logs = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    setState(() => isLoading = true);
    try {
      final result = await pb.logs.getList(
        page: currentPage,
        perPage: perPage,
        filter: filter.isEmpty ? null : filter,
        sort: sort,
      );
      setState(() {
        logs = result.items;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading logs: $e');
    }
  }

  Future<void> searchLogs(String searchTerm) async {
    setState(() {
      filter = 'message ~ "$searchTerm" || data.url ~ "$searchTerm"';
      currentPage = 1;
    });
    await loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Logs')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final status = log.data['status'] as int?;
                return ListTile(
                  title: Text(log.message),
                  subtitle: Text('${log.data['method']} ${log.data['url']}'),
                  trailing: status != null
                      ? Chip(
                          label: Text('$status'),
                          color: MaterialStateProperty.all(
                            status >= 400 ? Colors.red : Colors.green,
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
\`\`\`

## Error Handling

\`\`\`dart
try {
  final logs = await pb.logs.getList(
    page: 1,
    perPage: 50,
    filter: 'data.status >= 400',
  );
} on ClientException catch (e) {
  if (e.statusCode == 401) {
    print('Not authenticated');
  } else if (e.statusCode == 403) {
    print('Not a superuser');
  } else if (e.statusCode == 400) {
    print('Invalid filter: ${e.response}');
  } else {
    print('Unexpected error: $e');
  }
} catch (e) {
  print('Error: $e');
}
\`\`\`

## Best Practices

1. **Use Filters**: Always use filters to narrow down results, especially for large log datasets
2. **Paginate**: Use pagination instead of fetching all logs at once
3. **Efficient Sorting**: Use \`-rowid\` for default sorting (most efficient)
4. **Filter Statistics**: Always filter statistics for meaningful insights
5. **Monitor Errors**: Regularly check for 4xx/5xx errors
6. **Performance Tracking**: Monitor execution times for slow endpoints
7. **Security Auditing**: Track authentication failures and suspicious activity
8. **Archive Old Logs**: Consider deleting or archiving old logs to maintain performance

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Data Fields**: Only fields in the \`data\` object are filterable
- **Statistics**: Statistics are aggregated hourly
- **Performance**: Large log datasets may be slow to query
- **Storage**: Logs accumulate over time and may need periodic cleanup

## Log Levels

- **0**: Info (normal requests)
- **> 0**: Warnings/Errors (non-200 status codes, exceptions, etc.)

Higher values typically indicate more severe issues.

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - User authentication
- [API Records](./API_RECORDS.md) - Record operations
- [Collection API](./COLLECTION_API.md) - Collection management
