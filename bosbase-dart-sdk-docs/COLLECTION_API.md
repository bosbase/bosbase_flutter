# Collection API - Dart SDK Documentation

## Overview

The Collection API provides endpoints for managing collections (Base, Auth, and View types). All operations require superuser authentication and allow you to create, read, update, and delete collections along with their schemas and configurations.

**Key Features:**
- List and search collections
- View collection details
- Create collections (base, auth, view)
- Update collection schemas and rules
- Delete collections
- Truncate collections (delete all records)
- Import collections in bulk
- Get collection scaffolds (templates)

**Backend Endpoints:**
- `GET /api/collections` - List collections
- `GET /api/collections/{collection}` - View collection
- `POST /api/collections` - Create collection
- `PATCH /api/collections/{collection}` - Update collection
- `DELETE /api/collections/{collection}` - Delete collection
- `DELETE /api/collections/{collection}/truncate` - Truncate collection
- `PUT /api/collections/import` - Import collections
- `GET /api/collections/meta/scaffolds` - Get scaffolds

**Note**: All Collection API operations require superuser authentication.

## Authentication

All Collection API operations require superuser authentication:

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.admins.authWithPassword('admin@example.com', 'password');
// OR
await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
\`\`\`

## List Collections

Returns a paginated list of collections with support for filtering and sorting.

\`\`\`dart
// Basic list
final result = await pb.collections.getList(page: 1, perPage: 30);

print(result.page);        // 1
print(result.perPage);     // 30
print(result.totalItems);  // Total collections count
print(result.items);       // List of collections
\`\`\`

### Advanced Filtering and Sorting

\`\`\`dart
// Filter by type
final authCollections = await pb.collections.getList(
  page: 1,
  perPage: 100,
  filter: 'type = "auth"',
);

// Filter by name pattern
final matchingCollections = await pb.collections.getList(
  page: 1,
  perPage: 100,
  filter: 'name ~ "user"',
);

// Sort by creation date
final sortedCollections = await pb.collections.getList(
  page: 1,
  perPage: 100,
  sort: '-created',
);

// Complex filter
final filtered = await pb.collections.getList(
  page: 1,
  perPage: 100,
  filter: 'type = "base" && system = false && created >= "2023-01-01"',
  sort: 'name',
);
\`\`\`

### Get Full List

\`\`\`dart
// Get all collections at once
final allCollections = await pb.collections.getFullList(
  sort: 'name',
  filter: 'system = false',
);
\`\`\`

### Get First Matching Collection

\`\`\`dart
// Get first auth collection
final authCollection = await pb.collections.getFirstListItem('type = "auth"');
\`\`\`

## View Collection

Retrieve a single collection by ID or name:

\`\`\`dart
// By name
final collection = await pb.collections.getOne('posts');

// By ID
final collection = await pb.collections.getOne('_pbc_2287844090');

// With field selection
final collection = await pb.collections.getOne(
  'posts',
  fields: 'id,name,type,fields.name,fields.type',
);
\`\`\`

## Create Collection

Create a new collection with schema fields and configuration.

### Create Base Collection

\`\`\`dart
final baseCollection = await pb.collections.create(body: {
  'name': 'posts',
  'type': 'base',
  'fields': [
    {
      'name': 'title',
      'type': 'text',
      'required': true,
      'min': 10,
      'max': 255,
    },
    {
      'name': 'content',
      'type': 'editor',
      'required': false,
    },
    {
      'name': 'published',
      'type': 'bool',
      'required': false,
    },
    {
      'name': 'author',
      'type': 'relation',
      'required': true,
      'collectionId': '_pbc_users_auth_',
      'maxSelect': 1,
    },
  ],
  'listRule': '@request.auth.id != ""',
  'viewRule': '@request.auth.id != "" || published = true',
  'createRule': '@request.auth.id != ""',
  'updateRule': 'author = @request.auth.id',
  'deleteRule': 'author = @request.auth.id',
});
\`\`\`

### Create Auth Collection

\`\`\`dart
final authCollection = await pb.collections.create(body: {
  'name': 'users',
  'type': 'auth',
  'fields': [
    {
      'name': 'name',
      'type': 'text',
      'required': false,
    },
    {
      'name': 'avatar',
      'type': 'file',
      'required': false,
      'maxSelect': 1,
      'maxSize': 2097152, // 2MB
      'mimeTypes': ['image/jpeg', 'image/png'],
    },
  ],
  'listRule': null,
  'viewRule': '@request.auth.id = id',
  'createRule': null,
  'updateRule': '@request.auth.id = id',
  'deleteRule': '@request.auth.id = id',
  'manageRule': null,
  'authRule': 'verified = true', // Only verified users can authenticate
  'passwordAuth': {
    'enabled': true,
    'identityFields': ['email', 'username'],
  },
  'authToken': {
    'duration': 604800, // 7 days
  },
  'oauth2': {
    'enabled': true,
    'providers': [
      {
        'name': 'google',
        'clientId': 'YOUR_CLIENT_ID',
        'clientSecret': 'YOUR_CLIENT_SECRET',
        'authURL': 'https://accounts.google.com/o/oauth2/auth',
        'tokenURL': 'https://oauth2.googleapis.com/token',
        'userInfoURL': 'https://www.googleapis.com/oauth2/v2/userinfo',
        'displayName': 'Google',
      },
    ],
  },
});
\`\`\`

### Create View Collection

\`\`\`dart
final viewCollection = await pb.collections.create(body: {
  'name': 'published_posts',
  'type': 'view',
  'listRule': '@request.auth.id != ""',
  'viewRule': '@request.auth.id != ""',
  'viewQuery': '''
    SELECT 
      p.id,
      p.title,
      p.content,
      p.created,
      u.name as author_name,
      u.email as author_email
    FROM posts p
    LEFT JOIN users u ON p.author = u.id
    WHERE p.published = true
  ''',
});
\`\`\`

### Create from Scaffold

Use predefined scaffolds as a starting point:

\`\`\`dart
// Get available scaffolds
final scaffolds = await pb.collections.getScaffolds();

// Create base collection from scaffold
final baseCollection = await pb.collections.createBase('my_posts', body: {
  'fields': [
    {
      'name': 'title',
      'type': 'text',
      'required': true,
    },
  ],
});

// Create auth collection from scaffold
final authCollection = await pb.collections.createAuth('my_users', body: {
  'passwordAuth': {
    'enabled': true,
    'identityFields': ['email'],
  },
});

// Create view collection from scaffold
final viewCollection = await pb.collections.createView(
  'my_view',
  viewQuery: 'SELECT id, title FROM posts',
  body: {
    'listRule': '@request.auth.id != ""',
  },
);
\`\`\`

## Update Collection

Update an existing collection's schema, fields, or rules:

\`\`\`dart
// Update collection name and rules
final updated = await pb.collections.update('posts', body: {
  'name': 'articles',
  'listRule': '@request.auth.id != "" || status = "public"',
  'viewRule': '@request.auth.id != "" || status = "public"',
});

// Add new field (get, modify, update)
final collection = await pb.collections.getOne('posts');
final fields = List<Map<String, dynamic>>.from(collection.fields);
fields.add({
  'name': 'tags',
  'type': 'select',
  'options': {
    'values': ['tech', 'science', 'art'],
  },
});

await pb.collections.update('posts', body: {
  'fields': fields,
});
\`\`\`

### Updating Auth Collection Options

\`\`\`dart
// Update OAuth2 configuration
final collection = await pb.collections.getOne('users');
final updated = {
  ...collection.toJson(),
  'oauth2': {
    'enabled': true,
    'providers': [
      {
        'name': 'github',
        'clientId': 'NEW_CLIENT_ID',
        'clientSecret': 'NEW_CLIENT_SECRET',
        'displayName': 'GitHub',
      },
    ],
  },
  'authToken': {
    'duration': 2592000, // 30 days
  },
};

await pb.collections.update('users', body: updated);
\`\`\`

## Delete Collection

Delete a collection (including all records and files):

\`\`\`dart
// Delete by name
await pb.collections.delete('old_collection');

// Delete by ID
await pb.collections.delete('_pbc_2287844090');

// Using deleteCollection method (alias)
await pb.collections.deleteCollection('old_collection');
\`\`\`

**Warning**: This operation is destructive and will:
- Delete the collection schema
- Delete all records in the collection
- Delete all associated files
- Remove all indexes

**Note**: Collections referenced by other collections cannot be deleted.

## Truncate Collection

Delete all records in a collection while keeping the collection schema:

\`\`\`dart
// Truncate collection (delete all records)
await pb.collections.truncate('posts');

// This will:
// - Delete all records in the collection
// - Delete all associated files
// - Delete cascade-enabled relations
// - Keep the collection schema intact
\`\`\`

**Warning**: This operation is destructive and cannot be undone. It's useful for:
- Clearing test data
- Resetting collections
- Bulk data removal

**Note**: View collections cannot be truncated.

## Import Collections

Bulk import multiple collections at once:

\`\`\`dart
final collectionsToImport = [
  CollectionModel(
    name: 'posts',
    type: 'base',
    fields: [
      SchemaField(name: 'title', type: 'text', required: true),
      SchemaField(name: 'content', type: 'editor'),
    ],
    listRule: '@request.auth.id != ""',
  ),
  CollectionModel(
    name: 'categories',
    type: 'base',
    fields: [
      SchemaField(name: 'name', type: 'text', required: true),
    ],
  ),
];

// Import without deleting existing collections
await pb.collections.import(collectionsToImport, deleteMissing: false);

// Import and delete collections not in the import list
await pb.collections.import(collectionsToImport, deleteMissing: true);
\`\`\`

### Import Options

- **\`deleteMissing: false\`** (default): Only create/update collections in the import list
- **\`deleteMissing: true\`**: Delete all collections not present in the import list

**Warning**: Using \`deleteMissing: true\` will permanently delete collections and all their data.

## Get Scaffolds

Get collection templates for creating new collections:

\`\`\`dart
final scaffolds = await pb.collections.getScaffolds();

// Available scaffold types
print(scaffolds['base']);   // Base collection template
print(scaffolds['auth']);   // Auth collection template
print(scaffolds['view']);   // View collection template

// Use scaffold as starting point
final baseTemplate = scaffolds['base'] as CollectionModel;
final newCollection = CollectionModel(
  name: 'my_collection',
  type: 'base',
  fields: [
    ...baseTemplate.fields,
    SchemaField(name: 'custom_field', type: 'text'),
  ],
);

await pb.collections.create(body: newCollection.toJson());
\`\`\`

## Filter Syntax

Collections support filtering with the same syntax as records:

### Supported Fields

- \`id\` - Collection ID
- \`created\` - Creation date
- \`updated\` - Last update date
- \`name\` - Collection name
- \`type\` - Collection type (\`base\`, \`auth\`, \`view\`)
- \`system\` - System collection flag (boolean)

### Filter Examples

\`\`\`dart
// Filter by type
filter: 'type = "auth"'

// Filter by name pattern
filter: 'name ~ "user"'

// Filter non-system collections
filter: 'system = false'

// Multiple conditions
filter: 'type = "base" && system = false && created >= "2023-01-01"'

// Complex filter
filter: '(type = "auth" || type = "base") && name !~ "test"'
\`\`\`

## Sort Options

Supported sort fields:

- \`@random\` - Random order
- \`id\` - Collection ID
- \`created\` - Creation date
- \`updated\` - Last update date
- \`name\` - Collection name
- \`type\` - Collection type
- \`system\` - System flag

\`\`\`dart
// Sort examples
sort: 'name'           // ASC by name
sort: '-created'       // DESC by creation date
sort: 'type,-created'  // ASC by type, then DESC by created
\`\`\`

## Complete Examples

### Example 1: Setup Blog Collections

\`\`\`dart
Future<void> setupBlog() async {
  // Create posts collection
  final posts = await pb.collections.create(body: {
    'name': 'posts',
    'type': 'base',
    'fields': [
      {
        'name': 'title',
        'type': 'text',
        'required': true,
        'min': 10,
        'max': 255,
      },
      {
        'name': 'slug',
        'type': 'text',
        'required': true,
        'options': {
          'pattern': '^[a-z0-9-]+\$',
        },
      },
      {
        'name': 'content',
        'type': 'editor',
        'required': true,
      },
      {
        'name': 'featured_image',
        'type': 'file',
        'maxSelect': 1,
        'maxSize': 5242880, // 5MB
        'mimeTypes': ['image/jpeg', 'image/png'],
      },
      {
        'name': 'published',
        'type': 'bool',
        'required': false,
      },
      {
        'name': 'author',
        'type': 'relation',
        'collectionId': '_pbc_users_auth_',
        'maxSelect': 1,
      },
      {
        'name': 'categories',
        'type': 'relation',
        'collectionId': 'categories',
        'maxSelect': 5,
      },
    ],
    'listRule': '@request.auth.id != "" || published = true',
    'viewRule': '@request.auth.id != "" || published = true',
    'createRule': '@request.auth.id != ""',
    'updateRule': 'author = @request.auth.id',
    'deleteRule': 'author = @request.auth.id',
  });

  // Create categories collection
  final categories = await pb.collections.create(body: {
    'name': 'categories',
    'type': 'base',
    'fields': [
      {
        'name': 'name',
        'type': 'text',
        'required': true,
      },
      {
        'name': 'slug',
        'type': 'text',
        'required': true,
      },
      {
        'name': 'description',
        'type': 'text',
        'required': false,
      },
    ],
    'listRule': '@request.auth.id != ""',
    'viewRule': '@request.auth.id != ""',
  });

  print('Blog setup complete!');
}
\`\`\`

### Example 2: Clone Collection

\`\`\`dart
Future<CollectionModel> cloneCollection(String sourceName, String targetName) async {
  // Get source collection
  final source = await pb.collections.getOne(sourceName);
  
  // Create new collection based on source
  final cloneData = {
    ...source.toJson(),
    'id': null, // Let it auto-generate
    'name': targetName,
    'created': null,
    'updated': null,
    'system': false,
  };
  
  // Remove system fields
  final fields = List<Map<String, dynamic>>.from(cloneData['fields'] as List)
      .where((f) => f['system'] != true)
      .toList();
  cloneData['fields'] = fields;
  
  // Create cloned collection
  return await pb.collections.create(body: cloneData);
}
\`\`\`

### Example 3: Validate Collection Configuration

\`\`\`dart
Future<bool> validateCollection(String name) async {
  try {
    final collection = await pb.collections.getOne(name);
    
    // Check required fields
    final hasRequiredFields = collection.fields.any((f) => f.required);
    if (!hasRequiredFields) {
      print('Warning: Collection has no required fields');
    }
    
    // Check API rules
    if (collection.type == 'base' && collection.listRule == null) {
      print('Warning: Base collection has no listRule (superuser only)');
    }
    
    // Check indexes
    if (collection.indexes.isEmpty) {
      print('Warning: Collection has no indexes');
    }
    
    return true;
  } catch (e) {
    print('Validation failed: $e');
    return false;
  }
}
\`\`\`

## Error Handling

\`\`\`dart
try {
  await pb.collections.create(body: {
    'name': 'test',
    'type': 'base',
    'fields': [],
  });
} on ClientException catch (e) {
  if (e.statusCode == 401) {
    print('Not authenticated');
  } else if (e.statusCode == 403) {
    print('Not a superuser');
  } else if (e.statusCode == 400) {
    print('Validation error: ${e.response}');
  } else {
    print('Unexpected error: $e');
  }
} catch (e) {
  print('Error: $e');
}
\`\`\`

## Best Practices

1. **Always Authenticate**: Ensure you're authenticated as a superuser before making requests
2. **Backup Before Import**: Always backup existing collections before using \`import\` with \`deleteMissing: true\`
3. **Validate Schema**: Validate collection schemas before creating/updating
4. **Use Scaffolds**: Use scaffolds as starting points for consistency
5. **Test Rules**: Test API rules thoroughly before deploying to production
6. **Index Important Fields**: Add indexes for frequently queried fields
7. **Document Schemas**: Keep documentation of your collection schemas
8. **Version Control**: Store collection schemas in version control for migration tracking

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **System Collections**: System collections cannot be deleted or renamed
- **View Collections**: Cannot be truncated (they don't store records)
- **Relations**: Collections referenced by others cannot be deleted
- **Field Modifications**: Some field type changes may require data migration

## Related Documentation

- [Collections Guide](./COLLECTIONS.md) - Working with collections and records
- [API Records](./API_RECORDS.md) - Record CRUD operations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules
