# Collections - Dart SDK Documentation

## Overview

**Collections** represent your application data. Under the hood they are backed by plain SQLite tables that are generated automatically with the collection **name** and **fields** (columns).

A single entry of a collection is called a **record** (a single row in the SQL table).

## Collection Types

### Base Collection

Default collection type for storing any application data.

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');
await pb.admins.authWithPassword('admin@example.com', 'password');

final collection = await pb.collections.createBase('articles', overrides: {
  'fields': [
    {'name': 'title', 'type': 'text', 'required': true},
    {'name': 'description', 'type': 'text'}
  ]
});
```

### View Collection

Read-only collection populated from a SQL SELECT statement.

```dart
final view = await pb.collections.createView(
  'post_stats',
  viewQuery: '''
    SELECT posts.id, posts.name, count(comments.id) as totalComments 
    FROM posts LEFT JOIN comments on comments.postId = posts.id 
    GROUP BY posts.id
  ''',
);
```

### Auth Collection

Base collection with authentication fields (email, password, etc.).

```dart
final users = await pb.collections.createAuth('users', overrides: {
  'fields': [
    {'name': 'name', 'type': 'text', 'required': true}
  ]
});
```

## Collections API

### List Collections

```dart
final result = await pb.collections.getList(page: 1, perPage: 50);
final all = await pb.collections.getFullList();
```

### Get Collection

```dart
final collection = await pb.collections.getOne('articles');
```

### Create Collection

```dart
// Using scaffolds
final base = await pb.collections.createBase('articles');
final auth = await pb.collections.createAuth('users');
final view = await pb.collections.createView('stats', viewQuery: 'SELECT * FROM posts');

// Manual
final collection = await pb.collections.create(CollectionModel(
  type: 'base',
  name: 'articles',
  fields: [
    CollectionField(name: 'title', type: 'text', required: true),
    // Note: created and updated fields must be explicitly added if you want to use them
    CollectionField(
      name: 'created',
      type: 'autodate',
      required: false,
      options: {
        'onCreate': true,
        'onUpdate': false,
      },
    ),
    CollectionField(
      name: 'updated',
      type: 'autodate',
      required: false,
      options: {
        'onCreate': true,
        'onUpdate': true,
      },
    ),
  ],
));
```

### Update Collection

```dart
// Update collection rules
final updated = await pb.collections.update('articles', body: {
  'listRule': 'published = true'
});

// Update collection name
final updated = await pb.collections.update('articles', body: {
  'name': 'posts'
});
```

### Add Fields to Collection

To add a new field to an existing collection, fetch the collection, add the field to the fields array, and update:

```dart
// Get existing collection
var collection = await pb.collections.getOne('articles');

// Add new field to existing fields
final newFields = List<Map<String, dynamic>>.from(collection.fields);
newFields.add({
  'name': 'views',
  'type': 'number',
  'min': 0,
  'onlyInt': true,
});

// Update collection with new field
await pb.collections.update('articles', body: {
  'fields': newFields,
});

// Or add multiple fields at once
newFields.addAll([
  {
    'name': 'excerpt',
    'type': 'text',
    'max': 500,
  },
  {
    'name': 'cover',
    'type': 'file',
    'maxSelect': 1,
    'mimeTypes': ['image/jpeg', 'image/png'],
  },
]);

await pb.collections.update('articles', body: {
  'fields': newFields,
});
```

### Delete Fields from Collection

To delete a field, fetch the collection, remove the field from the fields array, and update:

```dart
// Get existing collection
var collection = await pb.collections.getOne('articles');

// Remove field by filtering it out
final updatedFields = (collection.fields as List)
    .where((field) => field['name'] != 'oldFieldName')
    .toList();

// Update collection without the deleted field
await pb.collections.update('articles', body: {
  'fields': updatedFields,
});

// Or remove multiple fields
final fieldsToKeep = ['title', 'content', 'author', 'status'];
final filteredFields = (collection.fields as List)
    .where((field) => 
        fieldsToKeep.contains(field['name']) || field['system'] == true)
    .toList();

await pb.collections.update('articles', body: {
  'fields': filteredFields,
});
```

### Modify Fields in Collection

To modify an existing field (e.g., change its type, add options, etc.), fetch the collection, update the field object, and save:

```dart
// Get existing collection
var collection = await pb.collections.getOne('articles');

// Convert fields to mutable list
final fields = List<Map<String, dynamic>>.from(collection.fields);

// Find and modify a field
final titleIndex = fields.indexWhere((f) => f['name'] == 'title');
if (titleIndex != -1) {
  fields[titleIndex] = {
    ...fields[titleIndex],
    'max': 200,  // Change max length
    'required': true,  // Make required
  };
}

// Update the field type
final statusIndex = fields.indexWhere((f) => f['name'] == 'status');
if (statusIndex != -1) {
  // Note: Changing field types may require data migration
  fields[statusIndex] = {
    ...fields[statusIndex],
    'type': 'select',
    'options': {
      'values': ['draft', 'published', 'archived'],
    },
    'maxSelect': 1,
  };
}

// Save changes
await pb.collections.update('articles', body: {
  'fields': fields,
});
```

### Complete Example: Managing Collection Fields

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');
await pb.admins.authWithPassword('admin@example.com', 'password');

// Get existing collection
var collection = await pb.collections.getOne('articles');

// Convert to mutable list
final fields = List<Map<String, dynamic>>.from(collection.fields);

// Add new fields
fields.addAll([
  {
    'name': 'tags',
    'type': 'select',
    'options': {
      'values': ['tech', 'design', 'business'],
    },
    'maxSelect': 5,
  },
  {
    'name': 'published_at',
    'type': 'date',
  },
]);

// Remove an old field
fields.removeWhere((f) => f['name'] == 'oldField');

// Modify existing field
final viewsIndex = fields.indexWhere((f) => f['name'] == 'views');
if (viewsIndex != -1) {
  fields[viewsIndex] = {
    ...fields[viewsIndex],
    'max': 1000000,  // Increase max value
  };
}

// Save all changes at once
await pb.collections.update('articles', body: {
  'fields': fields,
});
```

### Delete Collection

```dart
await pb.collections.delete('articles');
```

## Records API

### List Records

```dart
final result = await pb.collection('articles').getList(
  page: 1,
  perPage: 20,
  filter: 'published = true',
  sort: '-created',
  expand: 'author',
);

print(result.items);      // List of records
print(result.page);       // Current page
print(result.perPage);    // Items per page
print(result.totalItems); // Total count
print(result.totalPages); // Total pages
```

### Get Record

```dart
final record = await pb.collection('articles').getOne(
  'RECORD_ID',
  expand: 'author,category',
);
```

### Create Record

```dart
final record = await pb.collection('articles').create(body: {
  'title': 'My Article',
  'views+': 1,  // Field modifier
});
```

### Update Record

```dart
await pb.collection('articles').update('RECORD_ID', body: {
  'title': 'Updated',
  'views+': 1,
  'tags+': 'new-tag',
});
```

### Delete Record

```dart
await pb.collection('articles').delete('RECORD_ID');
```

## Field Types

### BoolField

```dart
CollectionField(name: 'published', type: 'bool', required: true)
await pb.collection('articles').create(body: {'published': true});
```

### NumberField

```dart
CollectionField(name: 'views', type: 'number', min: 0)
await pb.collection('articles').update('ID', body: {'views+': 1});
```

### TextField

```dart
CollectionField(name: 'title', type: 'text', required: true, min: 6, max: 100)
await pb.collection('articles').create(body: {'slug:autogenerate': 'article-'});
```

### EmailField

```dart
CollectionField(name: 'email', type: 'email', required: true)
```

### URLField

```dart
CollectionField(name: 'website', type: 'url')
```

### EditorField

```dart
CollectionField(name: 'content', type: 'editor', required: true)
await pb.collection('articles').create(body: {'content': '<p>HTML content</p>'});
```

### DateField

```dart
CollectionField(name: 'published_at', type: 'date')
await pb.collection('articles').create(body: {
  'published_at': '2024-11-10 18:45:27.123Z'
});
```

### AutodateField

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection with the proper options:

```dart
// Create field with proper options
CollectionField(
  name: 'created',
  type: 'autodate',
  required: false,
  options: {
    'onCreate': true,  // Set on record creation
    'onUpdate': false  // Don't update on record update
  },
)

// For updated field
CollectionField(
  name: 'updated',
  type: 'autodate',
  required: false,
  options: {
    'onCreate': true,  // Set on record creation
    'onUpdate': true   // Update on record update
  },
)

// The value is automatically set by the backend based on the options
```

### SelectField

```dart
// Single select
CollectionField(
  name: 'status',
  type: 'select',
  options: {
    'values': ['draft', 'published']
  },
  maxSelect: 1,
)
await pb.collection('articles').create(body: {'status': 'published'});

// Multiple select
CollectionField(
  name: 'tags',
  type: 'select',
  options: {
    'values': ['tech', 'design']
  },
  maxSelect: 5,
)
await pb.collection('articles').update('ID', body: {'tags+': 'marketing'});
```

### FileField

```dart
// Single file
CollectionField(
  name: 'cover',
  type: 'file',
  maxSelect: 1,
  mimeTypes: ['image/jpeg'],
)

final file = http.MultipartFile.fromPath('cover', '/path/to/image.jpg');
await pb.collection('articles').create(
  body: {'title': 'My Article'},
  files: [file],
);
```

### RelationField

```dart
CollectionField(
  name: 'author',
  type: 'relation',
  options: {'collectionId': 'users'},
  maxSelect: 1,
)
await pb.collection('articles').create(body: {'author': 'USER_ID'});
final record = await pb.collection('articles').getOne('ID', expand: 'author');
```

### JSONField

```dart
CollectionField(name: 'metadata', type: 'json')
await pb.collection('articles').create(body: {
  'metadata': {
    'seo': {'title': 'SEO Title'}
  }
});
```

### GeoPointField

```dart
CollectionField(name: 'location', type: 'geoPoint')
await pb.collection('places').create(body: {
  'location': {'lon': 139.6917, 'lat': 35.6586}
});
```

## Complete Example

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');
await pb.admins.authWithPassword('admin@example.com', 'password');

// Create collections
final users = await pb.collections.createAuth('users');
final articles = await pb.collections.createBase('articles', overrides: {
  'fields': [
    {'name': 'title', 'type': 'text', 'required': true},
    {
      'name': 'author',
      'type': 'relation',
      'options': {'collectionId': users.id},
      'maxSelect': 1,
    }
  ]
});

// Create and authenticate user
final user = await pb.collection('users').create(body: {
  'email': 'user@example.com',
  'password': 'password123',
  'passwordConfirm': 'password123',
});
await pb.collection('users').authWithPassword('user@example.com', 'password123');

// Create article
final article = await pb.collection('articles').create(body: {
  'title': 'My Article',
  'author': user.id,
});

// Subscribe to changes
await pb.collection('articles').subscribe('*', (e) {
  print('${e.action}: ${e.record}');
});
```

## Authentication Example

```dart
// Create auth collection
final customers = await pb.collections.createAuth('customers', overrides: {
  'fields': [
    {'name': 'name', 'type': 'text', 'required': true},
    {'name': 'phone', 'type': 'text'},
  ]
});

// Register customer
final customer = await pb.collection('customers').create(body: {
  'email': 'customer@example.com',
  'emailVisibility': true,
  'password': 'password123',
  'passwordConfirm': 'password123',
  'name': 'Jane Doe',
  'phone': '+1234567890',
});

// Authenticate
final auth = await pb.collection('customers').authWithPassword(
  'customer@example.com',
  'password123',
);

print(auth.token);
print(auth.record);

// Check authentication
if (pb.authStore.isValid) {
  print('Current user: ${pb.authStore.record}');
}

// Logout
pb.authStore.clear();
```

## Realtime Subscriptions

```dart
// Subscribe to all changes
final unsubscribeAll = await pb.collection('articles').subscribe('*', (e) {
  print('Action: ${e.action}');
  print('Record: ${e.record}');
});

// Subscribe to specific record
final unsubscribeRecord = await pb.collection('articles').subscribe(
  'RECORD_ID',
  (e) {
    print('Record updated: ${e.record}');
  },
);

// Unsubscribe
await pb.collection('articles').unsubscribe('RECORD_ID');
await pb.collection('articles').unsubscribe('*');
await pb.collection('articles').unsubscribe(); // All
```
