# Realtime API - Dart SDK Documentation

## Overview

The Realtime API enables real-time updates for collection records using **Server-Sent Events (SSE)**. It allows you to subscribe to changes in collections or specific records and receive instant notifications when records are created, updated, or deleted.

**Key Features:**
- Real-time notifications for record changes
- Collection-level and record-level subscriptions
- Automatic connection management and reconnection
- Authorization support
- Subscription options (expand, custom headers, query params)
- Event-driven architecture

**Backend Endpoints:**
- `GET /api/realtime` - Establish SSE connection
- `POST /api/realtime` - Set subscriptions

## How It Works

1. **Connection**: The SDK establishes an SSE connection to `/api/realtime`
2. **Client ID**: Server sends `PB_CONNECT` event with a unique `clientId`
3. **Subscriptions**: Client submits subscription topics via POST request
4. **Events**: Server sends events when matching records change
5. **Reconnection**: SDK automatically reconnects on connection loss

## Basic Usage

### Subscribe to Collection Changes

Subscribe to all changes in a collection:

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Subscribe to all changes in the 'posts' collection
final unsubscribe = await pb.collection('posts').subscribe('*', (e) {
  print('Action: ${e['action']}');  // 'create', 'update', or 'delete'
  print('Record: ${e['record']}');  // The record data
});

// Later, unsubscribe
await unsubscribe();
\`\`\`

### Subscribe to Specific Record

Subscribe to changes for a single record:

\`\`\`dart
// Subscribe to changes for a specific post
await pb.collection('posts').subscribe('RECORD_ID', (e) {
  print('Record changed: ${e['record']}');
  print('Action: ${e['action']}');
});
\`\`\`

### Multiple Subscriptions

You can subscribe multiple times to the same or different topics:

\`\`\`dart
// Subscribe to multiple records
final unsubscribe1 = await pb.collection('posts').subscribe('RECORD_ID_1', handleChange);
final unsubscribe2 = await pb.collection('posts').subscribe('RECORD_ID_2', handleChange);
final unsubscribe3 = await pb.collection('posts').subscribe('*', handleAllChanges);

void handleChange(Map<String, dynamic> e) {
  print('Change event: $e');
}

void handleAllChanges(Map<String, dynamic> e) {
  print('Collection-wide change: $e');
}

// Unsubscribe individually
await unsubscribe1();
await unsubscribe2();
await unsubscribe3();
\`\`\`

## Event Structure

Each event received contains:

\`\`\`dart
{
  'action': 'create' | 'update' | 'delete',  // Action type
  'record': {                                 // Record data
    'id': 'RECORD_ID',
    'collectionId': 'COLLECTION_ID',
    'collectionName': 'collection_name',
    'created': '2023-01-01 00:00:00.000Z',
    'updated': '2023-01-01 00:00:00.000Z',
    // ... other fields
  }
}
\`\`\`

### PB_CONNECT Event

When the connection is established, you receive a `PB_CONNECT` event:

\`\`\`dart
await pb.realtime.subscribe('PB_CONNECT', (e) {
  print('Connected! Client ID: ${e['clientId']}');
  // e['clientId'] - unique client identifier
});
\`\`\`

## Subscription Topics

### Collection-Level Subscription

Subscribe to all changes in a collection:

\`\`\`dart
// Wildcard subscription - all records in collection
await pb.collection('posts').subscribe('*', handler);
\`\`\`

**Access Control**: Uses the collection's `ListRule` to determine if the subscriber has access to receive events.

### Record-Level Subscription

Subscribe to changes for a specific record:

\`\`\`dart
// Specific record subscription
await pb.collection('posts').subscribe('RECORD_ID', handler);
\`\`\`

**Access Control**: Uses the collection's `ViewRule` to determine if the subscriber has access to receive events.

## Subscription Options

You can pass additional options when subscribing:

\`\`\`dart
await pb.collection('posts').subscribe('*', handler, query: {
  // Query parameters (for API rule filtering)
  'filter': 'status = "published"',
  'expand': 'author',
}, headers: {
  // Custom headers
  'X-Custom-Header': 'value',
});
\`\`\`

### Expand Relations

Expand relations in the event data:

\`\`\`dart
await pb.collection('posts').subscribe('RECORD_ID', (e) {
  final record = e['record'] as Map<String, dynamic>;
  print(record['expand']?['author']);  // Author relation expanded
}, query: {
  'expand': 'author,categories',
});
\`\`\`

### Filter with Query Parameters

Use query parameters for API rule filtering:

\`\`\`dart
await pb.collection('posts').subscribe('*', handler, query: {
  'filter': 'status = "published"',
});
\`\`\`

## Unsubscribing

### Unsubscribe from Specific Topic

\`\`\`dart
// Remove all subscriptions for a specific record
await pb.collection('posts').unsubscribe('RECORD_ID');

// Remove all wildcard subscriptions for the collection
await pb.collection('posts').unsubscribe('*');
\`\`\`

### Unsubscribe from All

\`\`\`dart
// Unsubscribe from all subscriptions in the collection
await pb.collection('posts').unsubscribe();

// Or unsubscribe from everything
await pb.realtime.unsubscribe();
\`\`\`

### Unsubscribe Using Returned Function

\`\`\`dart
final unsubscribe = await pb.collection('posts').subscribe('*', handler);

// Later...
await unsubscribe();  // Removes this specific subscription
\`\`\`

## Connection Management

### Connection Status

Check if the realtime connection is established:

\`\`\`dart
if (pb.realtime.isConnected) {
  print('Realtime connected');
} else {
  print('Realtime disconnected');
}
\`\`\`

### Disconnect Handler

Handle disconnection events:

\`\`\`dart
pb.realtime.onDisconnect = (List<String> activeSubscriptions) {
  if (activeSubscriptions.isNotEmpty) {
    print('Connection lost, but subscriptions remain: $activeSubscriptions');
    // Connection will automatically reconnect
  } else {
    print('Intentionally disconnected (no active subscriptions)');
  }
};
\`\`\`

### Automatic Reconnection

The SDK automatically:
- Reconnects when the connection is lost
- Resubmits all active subscriptions
- Handles network interruptions gracefully
- Closes connection after 5 minutes of inactivity (server-side timeout)

## Authorization

### Authenticated Subscriptions

Subscriptions respect authentication. If you're authenticated, events are filtered based on your permissions:

\`\`\`dart
// Authenticate first
await pb.collection('users').authWithPassword('user@example.com', 'password');

// Now subscribe - events will respect your permissions
await pb.collection('posts').subscribe('*', handler);
\`\`\`

### Authorization Rules

- **Collection-level (`*`)**: Uses `ListRule` to determine access
- **Record-level**: Uses `ViewRule` to determine access
- **Superusers**: Can receive all events (if rules allow)
- **Guests**: Only receive events they have permission to see

### Auth State Changes

When authentication state changes, you may need to resubscribe:

\`\`\`dart
// After login/logout, resubscribe to update permissions
await pb.collection('users').authWithPassword('user@example.com', 'password');

// Re-subscribe to update auth state in realtime connection
await pb.collection('posts').subscribe('*', handler);
\`\`\`

## Advanced Examples

### Example 1: Real-time Chat

\`\`\`dart
// Subscribe to messages in a chat room
Future<UnsubscribeFunc> setupChatRoom(String roomId) async {
  final unsubscribe = await pb.collection('messages').subscribe('*', (e) {
    final record = e['record'] as Map<String, dynamic>;
    // Filter for this room only
    if (record['roomId'] == roomId) {
      if (e['action'] == 'create') {
        displayMessage(record);
      } else if (e['action'] == 'delete') {
        removeMessage(record['id']);
      }
    }
  }, query: {
    'filter': 'roomId = "$roomId"',
  });
  
  return unsubscribe;
}

// Usage
final unsubscribeChat = await setupChatRoom('ROOM_ID');

// Cleanup
await unsubscribeChat();
\`\`\`

### Example 2: Real-time Dashboard

\`\`\`dart
// Subscribe to multiple collections
Future<void> setupDashboard() async {
  // Posts updates
  await pb.collection('posts').subscribe('*', (e) {
    if (e['action'] == 'create') {
      addPostToFeed(e['record']);
    } else if (e['action'] == 'update') {
      updatePostInFeed(e['record']);
    }
  }, query: {
    'filter': 'status = "published"',
    'expand': 'author',
  });

  // Comments updates
  await pb.collection('comments').subscribe('*', (e) {
    final record = e['record'] as Map<String, dynamic>;
    updateCommentsCount(record['postId']);
  }, query: {
    'expand': 'user',
  });
}

setupDashboard();
\`\`\`

### Example 3: User Activity Tracking

\`\`\`dart
// Track changes to a user's own records
Future<void> trackUserActivity(String userId) async {
  await pb.collection('posts').subscribe('*', (e) {
    final record = e['record'] as Map<String, dynamic>;
    // Only track changes to user's own posts
    if (record['author'] == userId) {
      print('Your post ${e['action']}: ${record['title']}');
      
      if (e['action'] == 'update') {
        showNotification('Post updated');
      }
    }
  }, query: {
    'filter': 'author = "$userId"',
  });
}

await trackUserActivity(pb.authStore.record?.id ?? '');
\`\`\`

### Example 4: Real-time Collaboration

\`\`\`dart
// Track when a document is being edited
Future<void> trackDocumentEdits(String documentId) async {
  await pb.collection('documents').subscribe(documentId, (e) {
    if (e['action'] == 'update') {
      final record = e['record'] as Map<String, dynamic>;
      final lastEditor = record['lastEditor'];
      final updatedAt = record['updated'];
      
      // Show who last edited the document
      showEditorIndicator(lastEditor, updatedAt);
    }
  }, query: {
    'expand': 'lastEditor',
  });
}
\`\`\`

### Example 5: Connection Monitoring

\`\`\`dart
// Monitor connection state
pb.realtime.onDisconnect = (List<String> activeSubscriptions) {
  if (activeSubscriptions.isNotEmpty) {
    print('Connection lost, attempting to reconnect...');
    showConnectionStatus('Reconnecting...');
  }
};

// Monitor connection establishment
await pb.realtime.subscribe('PB_CONNECT', (e) {
  print('Connected to realtime: ${e['clientId']}');
  showConnectionStatus('Connected');
});
\`\`\`

### Example 6: Conditional Subscriptions

\`\`\`dart
// Subscribe conditionally based on user state
Future<void> setupConditionalSubscriptions() async {
  if (pb.authStore.isValid) {
    // Authenticated user - subscribe to private posts
    await pb.collection('posts').subscribe('*', handler, query: {
      'filter': '@request.auth.id != ""',
    });
  } else {
    // Guest user - subscribe only to public posts
    await pb.collection('posts').subscribe('*', handler, query: {
      'filter': 'public = true',
    });
  }
}
\`\`\`

### Example 7: Cleanup on Widget Dispose (Flutter)

\`\`\`dart
import 'package:flutter/material.dart';

class PostsListWidget extends StatefulWidget {
  @override
  _PostsListWidgetState createState() => _PostsListWidgetState();
}

class _PostsListWidgetState extends State<PostsListWidget> {
  UnsubscribeFunc? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _setupSubscription();
  }

  Future<void> _setupSubscription() async {
    _unsubscribe = await pb.collection('posts').subscribe('*', (e) {
      if (mounted) {
        setState(() {
          // Update UI with new data
        });
      }
    });
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(/* ... */);
  }
}
\`\`\`

## Error Handling

\`\`\`dart
try {
  await pb.collection('posts').subscribe('*', handler);
} on ClientException catch (e) {
  if (e.statusCode == 403) {
    print('Permission denied');
  } else if (e.statusCode == 404) {
    print('Collection not found');
  } else {
    print('Subscription error: $e');
  }
} catch (e) {
  print('Error: $e');
}
\`\`\`

## Best Practices

1. **Unsubscribe When Done**: Always unsubscribe when widgets dispose or subscriptions are no longer needed
2. **Handle Disconnections**: Implement `onDisconnect` handler for better UX
3. **Filter Server-Side**: Use query parameters to filter events server-side when possible
4. **Limit Subscriptions**: Don't subscribe to more collections than necessary
5. **Use Record-Level When Possible**: Prefer record-level subscriptions over collection-level when you only need specific records
6. **Monitor Connection**: Track connection state for debugging and user feedback
7. **Handle Errors**: Wrap subscriptions in try-catch blocks
8. **Respect Permissions**: Understand that events respect API rules and permissions

## Limitations

- **Maximum Subscriptions**: Up to 1000 subscriptions per client
- **Topic Length**: Maximum 2500 characters per topic
- **Idle Timeout**: Connection closes after 5 minutes of inactivity
- **Network Dependency**: Requires stable network connection
- **Platform Support**: SSE requires platform support (Dart web/mobile)

## Troubleshooting

### Connection Not Establishing

\`\`\`dart
// Check connection status
print('Connected: ${pb.realtime.isConnected}');

// Manually trigger connection
await pb.collection('posts').subscribe('*', handler);
\`\`\`

### Events Not Received

1. Check API rules - you may not have permission
2. Verify subscription is active
3. Check network connectivity
4. Review server logs for errors

### Memory Leaks

Always unsubscribe:

\`\`\`dart
// Good
final unsubscribe = await pb.collection('posts').subscribe('*', handler);
// ... later
await unsubscribe();

// Bad - no cleanup
await pb.collection('posts').subscribe('*', handler);
// Never unsubscribed - memory leak!
\`\`\`

## Related Documentation

- [API Records](./API_RECORDS.md) - CRUD operations
- [Collections](./COLLECTIONS.md) - Collection configuration
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules
