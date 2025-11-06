# API Records - Dart SDK Documentation

## Overview

The Records API provides comprehensive CRUD (Create, Read, Update, Delete) operations for collection records, along with powerful search, filtering, and authentication capabilities.

**Key Features:**
- Paginated list and search with filtering and sorting
- Single record retrieval with expand support
- Create, update, and delete operations
- Batch operations for multiple records
- Authentication methods (password, OAuth2, OTP)
- Email verification and password reset
- Relation expansion up to 6 levels deep
- Field selection and excerpt modifiers

**Backend Endpoints:**
- `GET /api/collections/{collection}/records` - List records
- `GET /api/collections/{collection}/records/{id}` - View record
- `POST /api/collections/{collection}/records` - Create record
- `PATCH /api/collections/{collection}/records/{id}` - Update record
- `DELETE /api/collections/{collection}/records/{id}` - Delete record
- `POST /api/batch` - Batch operations

## CRUD Operations

### List/Search Records

Returns a paginated records list with support for sorting, filtering, and expansion.

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Basic list with pagination
final result = await pb.collection('posts').getList(
  page: 1,
  perPage: 50,
);

print(result.page);        // 1
print(result.perPage);     // 50
print(result.totalItems);  // 150
print(result.totalPages);  // 3
print(result.items);       // List of records
\`\`\`

#### Advanced List with Filtering and Sorting

\`\`\`dart
// Filter and sort
final result = await pb.collection('posts').getList(
  page: 1,
  perPage: 50,
  filter: 'created >= "2022-01-01 00:00:00" && status = "published"',
  sort: '-created,title',  // DESC by created, ASC by title
  expand: 'author,categories',
);

// Filter with operators
final result2 = await pb.collection('posts').getList(
  page: 1,
  perPage: 50,
  filter: 'title ~ "dart" && views > 100',
  sort: '-views',
);
\`\`\`

#### Get Full List

Fetch all records at once (useful for small collections):

\`\`\`dart
// Get all records
final allPosts = await pb.collection('posts').getFullList(
  sort: '-created',
  filter: 'status = "published"',
);

// With batch size for large collections
final allPosts = await pb.collection('posts').getFullList(
  batch: 200,
  sort: '-created',
);
\`\`\`

#### Get First Matching Record

Get only the first record that matches a filter:

\`\`\`dart
final post = await pb.collection('posts').getFirstListItem(
  'slug = "my-post-slug"',
  expand: 'author,categories.tags',
);
\`\`\`

### View Record

Retrieve a single record by ID:

\`\`\`dart
// Basic retrieval
final record = await pb.collection('posts').getOne('RECORD_ID');

// With expanded relations
final record = await pb.collection('posts').getOne(
  'RECORD_ID',
  expand: 'author,categories,tags',
);

// Nested expand
final record = await pb.collection('comments').getOne(
  'COMMENT_ID',
  expand: 'post.author,user',
);

// Field selection
final record = await pb.collection('posts').getOne(
  'RECORD_ID',
  fields: 'id,title,content,author.name',
);
\`\`\`

### Create Record

Create a new record:

\`\`\`dart
// Simple create
final record = await pb.collection('posts').create(body: {
  'title': 'My First Post',
  'content': 'Lorem ipsum...',
  'status': 'draft',
});

// Create with relations
final record = await pb.collection('posts').create(body: {
  'title': 'My Post',
  'author': 'AUTHOR_ID',           // Single relation
  'categories': ['cat1', 'cat2'],  // Multiple relation
});

// Create with file upload (multipart/form-data)
import 'package:http/http.dart' as http;

final file = File('/path/to/image.jpg');
final record = await pb.collection('posts').create(
  body: {
    'title': 'My Post',
  },
  files: [
    await http.MultipartFile.fromPath('image', file.path),
  ],
);

// Create with expand to get related data immediately
final record = await pb.collection('posts').create(
  body: {
    'title': 'My Post',
    'author': 'AUTHOR_ID',
  },
  expand: 'author',
);
\`\`\`

### Update Record

Update an existing record:

\`\`\`dart
// Simple update
final record = await pb.collection('posts').update(
  'RECORD_ID',
  body: {
    'title': 'Updated Title',
    'status': 'published',
  },
);

// Update with relations
await pb.collection('posts').update(
  'RECORD_ID',
  body: {
    'categories+': 'NEW_CATEGORY_ID',  // Append
    'tags-': 'OLD_TAG_ID',              // Remove
  },
);

// Update with file upload
import 'package:http/http.dart' as http;

final record = await pb.collection('posts').update(
  'RECORD_ID',
  body: {
    'title': 'Updated Title',
  },
  files: [
    await http.MultipartFile.fromPath('image', '/path/to/newimage.jpg'),
  ],
);

// Update with expand
final record = await pb.collection('posts').update(
  'RECORD_ID',
  body: {
    'title': 'Updated',
  },
  expand: 'author,categories',
);
\`\`\`

### Delete Record

Delete a record:

\`\`\`dart
// Simple delete
await pb.collection('posts').delete('RECORD_ID');

// Note: Returns void on success
// Throws exception if record doesn't exist or permission denied
\`\`\`

## Filter Syntax

The filter parameter supports a powerful query syntax:

### Comparison Operators

\`\`\`dart
// Equal
filter: 'status = "published"'

// Not equal
filter: 'status != "draft"'

// Greater than / Less than
filter: 'views > 100'
filter: 'created < "2023-01-01"'

// Greater/Less than or equal
filter: 'age >= 18'
filter: 'price <= 99.99'
\`\`\`

### String Operators

\`\`\`dart
// Contains (like)
filter: 'title ~ "dart"'
// Equivalent to: title LIKE "%dart%"

// Not contains
filter: 'title !~ "deprecated"'

// Exact match (case-sensitive)
filter: 'email = "user@example.com"'
\`\`\`

### Array Operators (for multiple relations/files)

\`\`\`dart
// Any of / At least one
filter: 'tags.id ?= "TAG_ID"'         // Any tag matches
filter: 'tags.name ?~ "important"'    // Any tag name contains "important"

// All must match
filter: 'tags.id = "TAG_ID" && tags.id = "TAG_ID2"'
\`\`\`

### Logical Operators

\`\`\`dart
// AND
filter: 'status = "published" && views > 100'

// OR
filter: 'status = "published" || status = "featured"'

// Parentheses for grouping
filter: '(status = "published" || featured = true) && views > 50'
\`\`\`

### Special Identifiers

\`\`\`dart
// Request context (only in API rules, not client filters)
// @request.auth.id, @request.query.*, etc.

// Collection joins
filter: '@collection.users.email = "test@example.com"'

// Record fields
filter: 'author.id = @request.auth.id'
\`\`\`

### Comments

\`\`\`dart
// Single-line comments are supported
filter: 'status = "published" // Only published posts'
\`\`\`

## Sorting

Sort records using the `sort` parameter:

\`\`\`dart
// Single field (ASC)
sort: 'created'

// Single field (DESC)
sort: '-created'

// Multiple fields
sort: '-created,title'  // DESC by created, then ASC by title

// Supported fields
sort: '@random'         // Random order
sort: '@rowid'          // Internal row ID
sort: 'id'              // Record ID
sort: 'fieldName'       // Any collection field

// Relation field sorting
sort: 'author.name'     // Sort by related author's name
\`\`\`

## Field Selection

Control which fields are returned:

\`\`\`dart
// Specific fields
fields: 'id,title,content'

// All fields at level
fields: '*'

// Nested field selection
fields: '*,author.name,author.email'

// Excerpt modifier for text fields
fields: '*,content:excerpt(200,true)'
// Returns first 200 characters with ellipsis if truncated

// Combined
fields: '*,content:excerpt(200),author.name,author.email'
\`\`\`

## Expanding Relations

Expand related records without additional API calls:

\`\`\`dart
// Single relation
expand: 'author'

// Multiple relations
expand: 'author,categories,tags'

// Nested relations (up to 6 levels)
expand: 'author.profile,categories.tags'

// Back-relations
expand: 'comments_via_post.user'
\`\`\`

See [Relations Documentation](./RELATIONS.md) for detailed information.

## Pagination Options

\`\`\`dart
// Skip total count (faster queries)
final result = await pb.collection('posts').getList(
  page: 1,
  perPage: 50,
  filter: 'status = "published"',
  skipTotal: true,  // totalItems and totalPages will be -1
);

// Get Full List with batch processing
final allPosts = await pb.collection('posts').getFullList(
  batch: 200,
  sort: '-created',
);
// Processes in batches of 200 to avoid memory issues
\`\`\`

## Batch Operations

Execute multiple operations in a single transaction:

\`\`\`dart
// Create a batch
final batch = pb.createBatch();

// Add operations
batch.collection('posts').create(body: {
  'title': 'Post 1',
  'author': 'AUTHOR_ID',
});

batch.collection('posts').create(body: {
  'title': 'Post 2',
  'author': 'AUTHOR_ID',
});

batch.collection('tags').update('TAG_ID', body: {
  'name': 'Updated Tag',
});

batch.collection('categories').delete('CAT_ID');

// Upsert (create or update based on id)
batch.collection('posts').upsert(body: {
  'id': 'EXISTING_ID',
  'title': 'Updated Post',
});

// Send batch request
final results = await batch.send();

// Results is a list matching the order of operations
for (var i = 0; i < results.length; i++) {
  final result = results[i];
  if (result.statusCode >= 400) {
    print('Operation $i failed: ${result.body}');
  } else {
    print('Operation $i succeeded: ${result.body}');
  }
}
\`\`\`

**Note**: Batch operations must be enabled in Dashboard > Settings > Application.

## Authentication Actions

### List Auth Methods

Get available authentication methods for a collection:

\`\`\`dart
final methods = await pb.collection('users').listAuthMethods();

print(methods.password?.enabled);      // true/false
print(methods.oauth2?.enabled);       // true/false
print(methods.oauth2?.providers);     // List of OAuth2 providers
print(methods.otp?.enabled);          // true/false
print(methods.mfa?.enabled);          // true/false
\`\`\`

### Auth with Password

\`\`\`dart
final authData = await pb.collection('users').authWithPassword(
  'user@example.com',  // username or email
  'password123',
);

// Auth data is automatically stored in pb.authStore
print(pb.authStore.isValid);    // true
print(pb.authStore.token);      // JWT token
print(pb.authStore.record?.id); // User ID

// Access the returned data
print(authData.token);
print(authData.record);

// With expand
final authData = await pb.collection('users').authWithPassword(
  'user@example.com',
  'password123',
  expand: 'profile',
);
\`\`\`

### Auth with OAuth2

\`\`\`dart
// Step 1: Get OAuth2 URL (usually done in UI)
final methods = await pb.collection('users').listAuthMethods();
final provider = methods.oauth2?.providers?.firstWhere(
  (p) => p.name == 'google',
);

// Redirect user to provider.authURL
// In Flutter: launchUrl(Uri.parse(provider.authURL));

// Step 2: After redirect, exchange code for token
final authData = await pb.collection('users').authWithOAuth2Code(
  'google',                    // Provider name
  'AUTHORIZATION_CODE',        // From redirect URL
  provider.codeVerifier,       // From step 1
  'https://yourapp.com/callback', // Redirect URL
  createData: {                // Optional data for new accounts
    'name': 'John Doe',
  },
);
\`\`\`

### Auth with OTP (One-Time Password)

\`\`\`dart
// Step 1: Request OTP
final otpRequest = await pb.collection('users').requestOTP('user@example.com');
// Returns: RecordAuthOTPResponse with otpId

// Step 2: User enters OTP from email
// Step 3: Authenticate with OTP
final authData = await pb.collection('users').authWithOTP(
  otpRequest.otpId,
  '123456',  // OTP from email
);
\`\`\`

### Auth Refresh

Refresh the current auth token and get updated user data:

\`\`\`dart
// Refresh auth (useful on app restart)
final authData = await pb.collection('users').authRefresh();

// Check if still valid
if (pb.authStore.isValid) {
  print('User is authenticated');
} else {
  print('Token expired or invalid');
}
\`\`\`

### Email Verification

\`\`\`dart
// Request verification email
await pb.collection('users').requestVerification('user@example.com');

// Confirm verification (on verification page)
await pb.collection('users').confirmVerification('VERIFICATION_TOKEN');
\`\`\`

### Password Reset

\`\`\`dart
// Request password reset email
await pb.collection('users').requestPasswordReset('user@example.com');

// Confirm password reset (on reset page)
// Note: This invalidates all previous auth tokens
await pb.collection('users').confirmPasswordReset(
  'RESET_TOKEN',
  'newpassword123',
  'newpassword123',  // Confirm
);
\`\`\`

### Email Change

\`\`\`dart
// Must be authenticated first
await pb.collection('users').authWithPassword('user@example.com', 'password');

// Request email change
await pb.collection('users').requestEmailChange('newemail@example.com');

// Confirm email change (on confirmation page)
// Note: This invalidates all previous auth tokens
await pb.collection('users').confirmEmailChange(
  'EMAIL_CHANGE_TOKEN',
  'currentpassword',
);
\`\`\`

### Impersonate (Superuser Only)

Generate a token to authenticate as another user:

\`\`\`dart
// Must be authenticated as superuser
await pb.admins.authWithPassword('admin@example.com', 'password');

// Impersonate a user
final impersonateClient = pb.collection('users').impersonate('USER_ID', 3600);
// Returns a new client instance with impersonated user's token

// Use the impersonated client
final posts = await impersonateClient.collection('posts').getFullList();

// Access the token
print(impersonateClient.authStore.token);
print(impersonateClient.authStore.record);
\`\`\`

## Complete Examples

### Example 1: Blog Post Search with Filters

\`\`\`dart
Future<List<RecordModel>> searchPosts(String query, String? categoryId, int? minViews) async {
  var filter = 'title ~ "$query" || content ~ "$query"';
  
  if (categoryId != null) {
    filter += ' && categories.id ?= "$categoryId"';
  }
  
  if (minViews != null) {
    filter += ' && views >= $minViews';
  }
  
  final result = await pb.collection('posts').getList(
    page: 1,
    perPage: 20,
    filter: filter,
    sort: '-created',
    expand: 'author,categories',
  );
  
  return result.items;
}
\`\`\`

### Example 2: User Dashboard with Related Content

\`\`\`dart
Future<Map<String, dynamic>> getUserDashboard(String userId) async {
  // Get user's posts
  final posts = await pb.collection('posts').getList(
    page: 1,
    perPage: 10,
    filter: 'author = "$userId"',
    sort: '-created',
    expand: 'categories',
  );
  
  // Get user's comments
  final comments = await pb.collection('comments').getList(
    page: 1,
    perPage: 10,
    filter: 'user = "$userId"',
    sort: '-created',
    expand: 'post',
  );
  
  return {
    'posts': posts.items,
    'comments': comments.items,
  };
}
\`\`\`

### Example 3: Advanced Filtering

\`\`\`dart
// Complex filter example
final result = await pb.collection('posts').getList(
  page: 1,
  perPage: 50,
  filter: '''
    (status = "published" || featured = true) &&
    created >= "2023-01-01" &&
    (tags.id ?= "important" || categories.id = "news") &&
    views > 100 &&
    author.email != ""
  ''',
  sort: '-views,created',
  expand: 'author.profile,tags,categories',
  fields: '*,content:excerpt(300),author.name,author.email',
);
\`\`\`

### Example 4: Batch Create Posts

\`\`\`dart
Future<List<dynamic>> createMultiplePosts(List<Map<String, dynamic>> postsData) async {
  final batch = pb.createBatch();
  
  for (var postData in postsData) {
    batch.collection('posts').create(body: postData);
  }
  
  final results = await batch.send();
  
  // Check for failures
  final failures = <int>[];
  for (var i = 0; i < results.length; i++) {
    if (results[i].statusCode >= 400) {
      failures.add(i);
      print('Post $i failed: ${results[i].body}');
    }
  }
  
  if (failures.isNotEmpty) {
    print('Some posts failed to create: $failures');
  }
  
  return results.map((r) => r.body).toList();
}
\`\`\`

### Example 5: Pagination Helper

\`\`\`dart
Future<List<RecordModel>> getAllRecordsPaginated(
  String collectionName, {
  Map<String, dynamic>? options,
}) async {
  final allRecords = <RecordModel>[];
  int page = 1;
  bool hasMore = true;
  
  while (hasMore) {
    final result = await pb.collection(collectionName).getList(
      page: page,
      perPage: 500,
      skipTotal: true,  // Skip count for performance
      ...?options,
    );
    
    allRecords.addAll(result.items);
    
    hasMore = result.items.length == 500;
    page++;
  }
  
  return allRecords;
}
\`\`\`

### Example 6: OAuth2 Authentication Flow

\`\`\`dart
import 'package:url_launcher/url_launcher.dart';

Future<void> handleOAuth2Login(String providerName) async {
  // Get OAuth2 methods
  final methods = await pb.collection('users').listAuthMethods();
  final provider = methods.oauth2?.providers?.firstWhere(
    (p) => p.name == providerName,
  );
  
  if (provider == null) {
    throw Exception('Provider $providerName not available');
  }
  
  // Store code verifier for later
  // In a real app, use secure storage
  // await secureStorage.write(key: 'oauth2_code_verifier', value: provider.codeVerifier);
  
  // Launch OAuth2 URL
  final uri = Uri.parse(provider.authURL);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

// After redirect callback
Future<void> handleOAuth2Callback(String code, String providerName, String codeVerifier) async {
  final redirectUrl = 'yourapp://auth/callback';
  
  try {
    final authData = await pb.collection('users').authWithOAuth2Code(
      providerName,
      code,
      codeVerifier,
      redirectUrl,
      createData: {
        // Optional: data for new account creation
        'name': 'User',
      },
    );
    
    // Success! User is now authenticated
    // Navigate to dashboard
  } catch (e) {
    print('OAuth2 authentication failed: $e');
  }
}
\`\`\`

## Error Handling

\`\`\`dart
try {
  final record = await pb.collection('posts').create(body: {
    'title': 'My Post',
  });
} on ClientException catch (e) {
  if (e.statusCode == 400) {
    // Validation error
    print('Validation errors: ${e.response}');
  } else if (e.statusCode == 403) {
    // Permission denied
    print('Access denied');
  } else if (e.statusCode == 404) {
    // Not found
    print('Collection or record not found');
  } else {
    print('Unexpected error: $e');
  }
} catch (e) {
  print('Error: $e');
}
\`\`\`

## Best Practices

1. **Use Pagination**: Always use pagination for large datasets
2. **Skip Total When Possible**: Use `skipTotal: true` for better performance when you don't need counts
3. **Batch Operations**: Use batch for multiple operations to reduce round trips
4. **Field Selection**: Only request fields you need to reduce payload size
5. **Expand Wisely**: Only expand relations you actually use
6. **Filter Before Sort**: Apply filters before sorting for better performance
7. **Cache Auth Tokens**: Auth tokens are automatically stored in `authStore`, no need to manually cache
8. **Handle Errors**: Always handle authentication and permission errors gracefully

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection configuration
- [Relations](./RELATIONS.md) - Working with relations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filter syntax details
- [Authentication](./AUTHENTICATION.md) - Detailed authentication guide
- [Files](./FILES.md) - File uploads and handling
