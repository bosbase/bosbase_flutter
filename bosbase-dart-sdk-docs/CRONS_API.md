# Crons API - Dart SDK Documentation

## Overview

The Crons API provides endpoints for viewing and manually triggering scheduled cron jobs. All operations require superuser authentication and allow you to list registered cron jobs and execute them on-demand.

**Key Features:**
- List all registered cron jobs
- View cron job schedules (cron expressions)
- Manually trigger cron jobs
- Built-in system jobs for maintenance tasks

**Backend Endpoints:**
- `GET /api/crons` - List cron jobs
- `POST /api/crons/{jobId}` - Run cron job

**Note**: All Crons API operations require superuser authentication.

## Authentication

All Crons API operations require superuser authentication:

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
\`\`\`

## List Cron Jobs

Returns a list of all registered cron jobs with their IDs and schedule expressions.

### Basic Usage

\`\`\`dart
// Get all cron jobs
final jobs = await pb.crons.getFullList();

print(jobs);
// [
//   CronJob(id: "__pbLogsCleanup__", expression: "0 */6 * * *"),
//   CronJob(id: "__pbDBOptimize__", expression: "0 0 * * *"),
//   CronJob(id: "__pbMFACleanup__", expression: "0 * * * *"),
//   CronJob(id: "__pbOTPCleanup__", expression: "0 * * * *")
// ]
\`\`\`

### Cron Job Structure

Each cron job contains:

\`\`\`dart
class CronJob {
  String id;        // Unique identifier for the job
  String expression; // Cron expression defining the schedule
}
\`\`\`

### Built-in System Jobs

The following cron jobs are typically registered by default:

| Job ID | Expression | Description | Schedule |
|--------|-----------|-------------|----------|
| \`__pbLogsCleanup__\` | \`0 */6 * * *\` | Cleans up old log entries | Every 6 hours |
| \`__pbDBOptimize__\` | \`0 0 * * *\` | Optimizes database | Daily at midnight |
| \`__pbMFACleanup__\` | \`0 * * * *\` | Cleans up expired MFA records | Every hour |
| \`__pbOTPCleanup__\` | \`0 * * * *\` | Cleans up expired OTP codes | Every hour |

### Working with Cron Jobs

\`\`\`dart
// List all cron jobs
final jobs = await pb.crons.getFullList();

// Find a specific job
final logsCleanup = jobs.firstWhere(
  (job) => job.id == '__pbLogsCleanup__',
  orElse: () => CronJob(id: '', expression: ''),
);

if (logsCleanup.id.isNotEmpty) {
  print('Logs cleanup runs: ${logsCleanup.expression}');
}

// Filter system jobs
final systemJobs = jobs.where((job) => job.id.startsWith('__pb')).toList();

// Filter custom jobs
final customJobs = jobs.where((job) => !job.id.startsWith('__pb')).toList();
\`\`\`

## Run Cron Job

Manually trigger a cron job to execute immediately.

### Basic Usage

\`\`\`dart
// Run a specific cron job
await pb.crons.run('__pbLogsCleanup__');
\`\`\`

### Use Cases

\`\`\`dart
// Trigger logs cleanup manually
Future<void> cleanupLogsNow() async {
  await pb.crons.run('__pbLogsCleanup__');
  print('Logs cleanup triggered');
}

// Trigger database optimization
Future<void> optimizeDatabase() async {
  await pb.crons.run('__pbDBOptimize__');
  print('Database optimization triggered');
}

// Trigger MFA cleanup
Future<void> cleanupMFA() async {
  await pb.crons.run('__pbMFACleanup__');
  print('MFA cleanup triggered');
}

// Trigger OTP cleanup
Future<void> cleanupOTP() async {
  await pb.crons.run('__pbOTPCleanup__');
  print('OTP cleanup triggered');
}
\`\`\`

## Cron Expression Format

Cron expressions use the standard 5-field format:

\`\`\`
* * * * *
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, 0 or 7 is Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
\`\`\`

### Common Patterns

| Expression | Description |
|------------|-------------|
| \`0 * * * *\` | Every hour at minute 0 |
| \`0 */6 * * *\` | Every 6 hours |
| \`0 0 * * *\` | Daily at midnight |
| \`0 0 * * 0\` | Weekly on Sunday at midnight |
| \`0 0 1 * *\` | Monthly on the 1st at midnight |
| \`*/30 * * * *\` | Every 30 minutes |
| \`0 9 * * 1-5\` | Weekdays at 9 AM |

### Supported Macros

| Macro | Equivalent Expression | Description |
|-------|----------------------|-------------|
| \`@yearly\` or \`@annually\` | \`0 0 1 1 *\` | Once a year |
| \`@monthly\` | \`0 0 1 * *\` | Once a month |
| \`@weekly\` | \`0 0 * * 0\` | Once a week |
| \`@daily\` or \`@midnight\` | \`0 0 * * *\` | Once a day |
| \`@hourly\` | \`0 * * * *\` | Once an hour |

### Expression Examples

\`\`\`dart
// Every hour
"0 * * * *"

// Every 6 hours
"0 */6 * * *"

// Daily at midnight
"0 0 * * *"

// Every 30 minutes
"*/30 * * * *"

// Weekdays at 9 AM
"0 9 * * 1-5"

// First day of every month
"0 0 1 * *"

// Using macros
"@daily"   // Same as "0 0 * * *"
"@hourly"  // Same as "0 * * * *"
\`\`\`

## Complete Examples

### Example 1: Cron Job Monitor

\`\`\`dart
class CronMonitor {
  final Bosbase pb;

  CronMonitor(this.pb);

  Future<List<CronJob>> listAllJobs() async {
    final jobs = await pb.crons.getFullList();
    
    print('Found ${jobs.length} cron jobs:');
    for (final job in jobs) {
      print('  - ${job.id}: ${job.expression}');
    }
    
    return jobs;
  }

  Future<bool> runJob(String jobId) async {
    try {
      await pb.crons.run(jobId);
      print('Successfully triggered: $jobId');
      return true;
    } catch (e) {
      print('Failed to run $jobId: $e');
      return false;
    }
  }

  Future<void> runMaintenanceJobs() async {
    const maintenanceJobs = [
      '__pbLogsCleanup__',
      '__pbDBOptimize__',
      '__pbMFACleanup__',
      '__pbOTPCleanup__',
    ];

    for (final jobId in maintenanceJobs) {
      print('Running $jobId...');
      await runJob(jobId);
      // Wait a bit between jobs
      await Future.delayed(Duration(seconds: 1));
    }
  }
}

// Usage
final monitor = CronMonitor(pb);
await monitor.listAllJobs();
await monitor.runMaintenanceJobs();
\`\`\`

### Example 2: Cron Job Health Check

\`\`\`dart
Future<bool> checkCronJobs() async {
  try {
    final jobs = await pb.crons.getFullList();
    
    const expectedJobs = [
      '__pbLogsCleanup__',
      '__pbDBOptimize__',
      '__pbMFACleanup__',
      '__pbOTPCleanup__',
    ];
    
    final missingJobs = expectedJobs.where(
      (expectedId) => !jobs.any((job) => job.id == expectedId)
    ).toList();
    
    if (missingJobs.isNotEmpty) {
      print('Missing expected cron jobs: $missingJobs');
      return false;
    }
    
    print('All expected cron jobs are registered');
    return true;
  } catch (e) {
    print('Failed to check cron jobs: $e');
    return false;
  }
}
\`\`\`

### Example 3: Manual Maintenance Script

\`\`\`dart
Future<void> performMaintenance() async {
  print('Starting maintenance tasks...');
  
  // Cleanup old logs
  print('1. Cleaning up old logs...');
  await pb.crons.run('__pbLogsCleanup__');
  
  // Cleanup expired MFA records
  print('2. Cleaning up expired MFA records...');
  await pb.crons.run('__pbMFACleanup__');
  
  // Cleanup expired OTP codes
  print('3. Cleaning up expired OTP codes...');
  await pb.crons.run('__pbOTPCleanup__');
  
  // Optimize database (run last as it may take longer)
  print('4. Optimizing database...');
  await pb.crons.run('__pbDBOptimize__');
  
  print('Maintenance tasks completed');
}
\`\`\`

### Example 4: Cron Job Status Dashboard

\`\`\`dart
class CronStatus {
  final int total;
  final int system;
  final int custom;
  final List<CronJobInfo> jobs;

  CronStatus({
    required this.total,
    required this.system,
    required this.custom,
    required this.jobs,
  });
}

class CronJobInfo {
  final String id;
  final String expression;
  final String type;

  CronJobInfo({
    required this.id,
    required this.expression,
    required this.type,
  });
}

Future<CronStatus> getCronStatus() async {
  final jobs = await pb.crons.getFullList();
  
  final systemCount = jobs.where((job) => job.id.startsWith('__pb')).length;
  final customCount = jobs.length - systemCount;
  
  final jobInfos = jobs.map((job) => CronJobInfo(
    id: job.id,
    expression: job.expression,
    type: job.id.startsWith('__pb') ? 'system' : 'custom',
  )).toList();
  
  return CronStatus(
    total: jobs.length,
    system: systemCount,
    custom: customCount,
    jobs: jobInfos,
  );
}

// Usage
final status = await getCronStatus();
print('Total: ${status.total}, System: ${status.system}, Custom: ${status.custom}');
\`\`\`

### Example 5: Cron Job Testing

\`\`\`dart
Future<bool> testCronJob(String jobId) async {
  print('Testing cron job: $jobId');
  
  try {
    // Check if job exists
    final jobs = await pb.crons.getFullList();
    final job = jobs.firstWhere(
      (j) => j.id == jobId,
      orElse: () => CronJob(id: '', expression: ''),
    );
    
    if (job.id.isEmpty) {
      print('Cron job $jobId not found');
      return false;
    }
    
    print('Job found with expression: ${job.expression}');
    
    // Run the job
    print('Triggering job...');
    await pb.crons.run(jobId);
    
    print('Job triggered successfully');
    return true;
  } catch (e) {
    print('Failed to test cron job: $e');
    return false;
  }
}

// Test a specific job
await testCronJob('__pbLogsCleanup__');
\`\`\`

## Error Handling

\`\`\`dart
try {
  final jobs = await pb.crons.getFullList();
} on ClientException catch (e) {
  if (e.statusCode == 401) {
    print('Not authenticated');
  } else if (e.statusCode == 403) {
    print('Not a superuser');
  } else {
    print('Unexpected error: $e');
  }
} catch (e) {
  print('Error: $e');
}

try {
  await pb.crons.run('__pbLogsCleanup__');
} on ClientException catch (e) {
  if (e.statusCode == 401) {
    print('Not authenticated');
  } else if (e.statusCode == 403) {
    print('Not a superuser');
  } else if (e.statusCode == 404) {
    print('Cron job not found');
  } else {
    print('Unexpected error: $e');
  }
} catch (e) {
  print('Error: $e');
}
\`\`\`

## Best Practices

1. **Check Job Existence**: Verify a cron job exists before trying to run it
2. **Error Handling**: Always handle errors when running cron jobs
3. **Rate Limiting**: Don't trigger cron jobs too frequently manually
4. **Monitoring**: Regularly check that expected cron jobs are registered
5. **Logging**: Log when cron jobs are manually triggered for auditing
6. **Testing**: Test cron jobs in development before running in production
7. **Documentation**: Document custom cron jobs and their purposes
8. **Scheduling**: Let the cron scheduler handle regular execution; use manual triggers sparingly

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Read-Only API**: The SDK API only allows listing and running jobs; adding/removing jobs must be done via backend hooks
- **Asynchronous Execution**: Running a cron job triggers it asynchronously; the API returns immediately
- **No Status**: The API doesn't provide execution status or history
- **System Jobs**: Built-in system jobs (prefixed with \`__pb\`) cannot be removed via the API

## Custom Cron Jobs

Custom cron jobs are typically registered through backend hooks (JavaScript VM plugins). The Crons API only allows you to:

- **View** all registered jobs (both system and custom)
- **Trigger** any registered job manually

To add or remove cron jobs, you need to use the backend hook system:

\`\`\`javascript
// In a backend hook file (pb_hooks/main.js)
routerOnInit((e) => {
  // Add custom cron job
  cronAdd("myCustomJob", "0 */2 * * *", () => {
    console.log("Custom job runs every 2 hours");
    // Your custom logic here
  });
});
\`\`\`

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Collection management
- [Logs API](./LOGS_API.md) - Log viewing and analysis
- [Backups API](./BACKUPS_API.md) - Backup management (if available)
