# Working with Relations - Dart SDK Documentation

## Overview

Relations allow you to link records between collections. BosBase supports both single and multiple relations, and provides powerful features for expanding related records and working with back-relations.

**Key Features:**
- Single and multiple relations
- Expand related records without additional requests
- Nested relation expansion (up to 6 levels)
- Back-relations for reverse lookups
- Field modifiers for append/prepend/remove operations

**Relation Field Types:**
- **Single Relation**: Links to one record (MaxSelect <= 1)
- **Multiple Relation**: Links to multiple records (MaxSelect > 1)

**Backend Behavior:**
- Relations are stored as record IDs or arrays of IDs
- Expand only includes relations the client can view (satisfies View API Rule)
- Back-relations use format: `collectionName_via_fieldName`
- Back-relation expand limited to 1000 records per field

## Setting Up Relations

### Creating a Relation Field

\`\`\`dart
var collection = await pb.collections.getOne('posts');

final fields = List<Map<String, dynamic>>.from(collection.fields);
fields.add({
  'name': 'user',
  'type': 'relation',
  'collectionId': 'users',  // ID of related collection
  'maxSelect': 1,           // Single relation
  'required': true,
});

// Multiple relation field
fields.add({
  'name': 'tags',
  'type': 'relation',
  'collectionId': 'tags',
  'maxSelect': 10,          // Multiple relation (max 10)
  'minSelect': 1,           // Minimum 1 required
  'cascadeDelete': false,   // Don't delete post when tags deleted
});

await pb.collections.update('posts', body: {'fields': fields});
\`\`\`

## Creating Records with Relations

### Single Relation

\`\`\`dart
// Create a post with a single user relation
final post = await pb.collection('posts').create(body: {
  'title': 'My Post',
  'user': 'USER_ID',  // Single relation ID
});
\`\`\`

### Multiple Relations

\`\`\`dart
// Create a post with multiple tags
final post = await pb.collection('posts').create(body: {
  'title': 'My Post',
  'tags': ['TAG_ID1', 'TAG_ID2', 'TAG_ID3'],  // Array of IDs
});
\`\`\`

### Mixed Relations

\`\`\`dart
// Create a comment with both single and multiple relations
final comment = await pb.collection('comments').create(body: {
  'message': 'Great post!',
  'post': 'POST_ID',        // Single relation
  'user': 'USER_ID',        // Single relation
  'tags': ['TAG1', 'TAG2'], // Multiple relation
});
\`\`\`

## Updating Relations

### Replace All Relations

\`\`\`dart
// Replace all tags
await pb.collection('posts').update('POST_ID', body: {
  'tags': ['NEW_TAG1', 'NEW_TAG2'],
});
\`\`\`

### Append Relations (Using + Modifier)

\`\`\`dart
// Append tags to existing ones
await pb.collection('posts').update('POST_ID', body: {
  'tags+': 'NEW_TAG_ID',  // Append single tag
});

// Append multiple tags
await pb.collection('posts').update('POST_ID', body: {
  'tags+': ['TAG_ID1', 'TAG_ID2'],  // Append multiple tags
});
\`\`\`

### Prepend Relations (Using + Prefix)

\`\`\`dart
// Prepend tags (tags will appear first)
await pb.collection('posts').update('POST_ID', body: {
  '+tags': 'PRIORITY_TAG',  // Prepend single tag
});

// Prepend multiple tags
await pb.collection('posts').update('POST_ID', body: {
  '+tags': ['TAG1', 'TAG2'],  // Prepend multiple tags
});
\`\`\`

### Remove Relations (Using - Modifier)

\`\`\`dart
// Remove single tag
await pb.collection('posts').update('POST_ID', body: {
  'tags-': 'TAG_ID_TO_REMOVE',
});

// Remove multiple tags
await pb.collection('posts').update('POST_ID', body: {
  'tags-': ['TAG1', 'TAG2'],
});
\`\`\`

### Complete Example

\`\`\`dart
// Get existing post
final post = await pb.collection('posts').getOne('POST_ID');
final tags = post.getListValue<String>('tags');
print(tags);  // [tag1, tag2]

// Remove one tag, add two new ones
await pb.collection('posts').update('POST_ID', body: {
  'tags-': 'tag1',           // Remove
  'tags+': ['tag3', 'tag4'], // Append
});

final updated = await pb.collection('posts').getOne('POST_ID');
final updatedTags = updated.getListValue<String>('tags');
print(updatedTags);  // [tag2, tag3, tag4]
\`\`\`

## Expanding Relations

The `expand` parameter allows you to fetch related records in a single request, eliminating the need for multiple API calls.

### Basic Expand

\`\`\`dart
// Get comment with expanded user
final comment = await pb.collection('comments').getOne(
  'COMMENT_ID',
  expand: 'user',
);

final user = comment.expand?['user'] as Map<String, dynamic>?;
if (user != null) {
  print(user['name']);  // "John Doe"
}
print(comment.getStringValue('user'));  // Still the ID: "USER_ID"
\`\`\`

### Expand Multiple Relations

\`\`\`dart
// Expand multiple relations (comma-separated)
final comment = await pb.collection('comments').getOne(
  'COMMENT_ID',
  expand: 'user,post',
);

final user = comment.expand?['user'] as Map<String, dynamic>?;
final post = comment.expand?['post'] as Map<String, dynamic>?;
print(user?['name']);   // "John Doe"
print(post?['title']);  // "My Post"
\`\`\`

### Nested Expand (Dot Notation)

You can expand nested relations up to 6 levels deep using dot notation:

\`\`\`dart
// Expand post and its tags, and user
final comment = await pb.collection('comments').getOne(
  'COMMENT_ID',
  expand: 'user,post.tags',
);

// Access nested expands
final post = comment.expand?['post'] as Map<String, dynamic>?;
final tags = post?['expand']?['tags'] as List<dynamic>?;
if (tags != null) {
  for (var tag in tags) {
    print((tag as Map<String, dynamic>)['name']);
  }
}

// Expand even deeper
final postDeep = await pb.collection('posts').getOne(
  'POST_ID',
  expand: 'user,comments_via_post.user',
);

final comments = postDeep.expand?['comments_via_post'] as List<dynamic>?;
if (comments != null) {
  for (var comment in comments) {
    final cmt = comment as Map<String, dynamic>;
    final user = cmt['expand']?['user'] as Map<String, dynamic>?;
    print(user?['name']);
  }
}
\`\`\`

### Expand with List Requests

\`\`\`dart
// List comments with expanded users
final comments = await pb.collection('comments').getList(
  page: 1,
  perPage: 20,
  expand: 'user',
);

for (var comment in comments.items) {
  print(comment.getStringValue('message'));
  final user = comment.expand?['user'] as Map<String, dynamic>?;
  print(user?['name']);
}
\`\`\`

### Expand Single vs Multiple Relations

\`\`\`dart
// Single relation - expand.user is a Map
final post = await pb.collection('posts').getOne(
  'POST_ID',
  expand: 'user',
);
final user = post.expand?['user'] as Map<String, dynamic>?;
print(user is Map);  // true

// Multiple relation - expand.tags is a List
final postWithTags = await pb.collection('posts').getOne(
  'POST_ID',
  expand: 'tags',
);
final tags = postWithTags.expand?['tags'] as List<dynamic>?;
print(tags is List);  // true
\`\`\`

### Expand Permissions

**Important**: Only relations that satisfy the related collection's `viewRule` will be expanded. If you don't have permission to view a related record, it won't appear in the expand.

\`\`\`dart
// If you don't have view permission for user, expand.user will be null
final comment = await pb.collection('comments').getOne(
  'COMMENT_ID',
  expand: 'user',
);

final user = comment.expand?['user'] as Map<String, dynamic>?;
if (user != null) {
  print(user['name']);
} else {
  print('User not accessible or not found');
}
\`\`\`

## Back-Relations

Back-relations allow you to query and expand records that reference the current record through a relation field.

### Back-Relation Syntax

The format is: `collectionName_via_fieldName`

- `collectionName`: The collection that contains the relation field
- `fieldName`: The name of the relation field that points to your record

### Example: Posts with Comments

\`\`\`dart
// Get a post and expand all comments that reference it
final post = await pb.collection('posts').getOne(
  'POST_ID',
  expand: 'comments_via_post',
);

// comments_via_post is always a List (even if original field is single)
final comments = post.expand?['comments_via_post'] as List<dynamic>?;
if (comments != null) {
  for (var comment in comments) {
    print((comment as Map<String, dynamic>)['message']);
  }
}
\`\`\`

### Back-Relation with Nested Expand

\`\`\`dart
// Get post with comments, and expand each comment's user
final post = await pb.collection('posts').getOne(
  'POST_ID',
  expand: 'comments_via_post.user',
);

// Access nested expands
final comments = post.expand?['comments_via_post'] as List<dynamic>?;
if (comments != null) {
  for (var comment in comments) {
    final cmt = comment as Map<String, dynamic>;
    print(cmt['message']);
    final user = cmt['expand']?['user'] as Map<String, dynamic>?;
    print(user?['name']);
  }
}
\`\`\`

### Filtering with Back-Relations

\`\`\`dart
// List posts that have at least one comment containing "hello"
final posts = await pb.collection('posts').getList(
  page: 1,
  perPage: 20,
  filter: "comments_via_post.message ?~ 'hello'",
  expand: 'comments_via_post.user',
);

for (var post in posts.items) {
  print(post.getStringValue('title'));
  final comments = post.expand?['comments_via_post'] as List<dynamic>?;
  if (comments != null) {
    for (var comment in comments) {
      final cmt = comment as Map<String, dynamic>;
      print('  - ${cmt['message']}');
      final user = cmt['expand']?['user'] as Map<String, dynamic>?;
      print('    by ${user?['name']}');
    }
  }
}
\`\`\`

### Sorting with Back-Relations

\`\`\`dart
// Sort posts by creation date
final posts = await pb.collection('posts').getList(
  page: 1,
  perPage: 20,
  expand: 'comments_via_post',
  sort: '-created',
);
\`\`\`

### Back-Relation Caveats

1. **Always Multiple**: Back-relations are always treated as lists, even if the original relation field is single. This is because one record can be referenced by multiple records.

   \`\`\`dart
   // Even if comments.post is single, comments_via_post is always a List
   final post = await pb.collection('posts').getOne(
     'POST_ID',
     expand: 'comments_via_post',
   );
   
   final comments = post.expand?['comments_via_post'] as List<dynamic>?;
   print(comments is List);  // true
   \`\`\`

2. **UNIQUE Index Exception**: If the relation field has a UNIQUE index constraint, the back-relation will be treated as a single object (not a list).

3. **1000 Record Limit**: Back-relation expand is limited to 1000 records per field. For larger datasets, use separate paginated requests:

   \`\`\`dart
   // Instead of expanding all comments (if > 1000)
   final post = await pb.collection('posts').getOne('POST_ID');
   
   // Fetch comments separately with pagination
   final comments = await pb.collection('comments').getList(
     page: 1,
     perPage: 100,
     filter: 'post = "${post.id}"',
     expand: 'user',
     sort: '-created',
   );
   \`\`\`

## Complete Examples

### Example 1: Blog Post with Author and Tags

\`\`\`dart
// Create a blog post with relations
final post = await pb.collection('posts').create(body: {
  'title': 'Getting Started with BosBase',
  'content': 'Lorem ipsum...',
  'author': 'AUTHOR_ID',           // Single relation
  'tags': ['tag1', 'tag2', 'tag3'], // Multiple relation
});

// Retrieve with all relations expanded
final fullPost = await pb.collection('posts').getOne(
  post.id,
  expand: 'author,tags',
);

print(fullPost.getStringValue('title'));
final author = fullPost.expand?['author'] as Map<String, dynamic>?;
print('Author: ${author?['name']}');
print('Tags:');
final tags = fullPost.expand?['tags'] as List<dynamic>?;
if (tags != null) {
  for (var tag in tags) {
    print('  - ${(tag as Map<String, dynamic>)['name']}');
  }
}
\`\`\`

### Example 2: Comment System with Nested Relations

\`\`\`dart
// Create a comment on a post
final comment = await pb.collection('comments').create(body: {
  'message': 'Great article!',
  'post': 'POST_ID',
  'user': 'USER_ID',
});

// Get post with all comments and their authors
final post = await pb.collection('posts').getOne(
  'POST_ID',
  expand: 'author,comments_via_post.user',
);

print('Post: ${post.getStringValue('title')}');
final author = post.expand?['author'] as Map<String, dynamic>?;
print('Author: ${author?['name']}');
final comments = post.expand?['comments_via_post'] as List<dynamic>?;
print('Comments (${comments?.length ?? 0}):');
if (comments != null) {
  for (var comment in comments) {
    final cmt = comment as Map<String, dynamic>;
    final user = cmt['expand']?['user'] as Map<String, dynamic>?;
    print('  ${user?['name']}: ${cmt['message']}');
  }
}
\`\`\`

### Example 3: Dynamic Tag Management

\`\`\`dart
class PostManager {
  final Bosbase pb;

  PostManager(this.pb);

  Future<void> addTag(String postId, String tagId) async {
    await pb.collection('posts').update(postId, body: {
      'tags+': tagId,
    });
  }

  Future<void> removeTag(String postId, String tagId) async {
    await pb.collection('posts').update(postId, body: {
      'tags-': tagId,
    });
  }

  Future<void> setPriorityTags(String postId, List<String> tagIds) async {
    // Clear existing and set priority tags first
    final post = await pb.collection('posts').getOne(postId);
    final existingTags = post.getListValue<String>('tags');
    final remainingTags = existingTags
        .where((id) => !tagIds.contains(id))
        .toList();
    
    await pb.collection('posts').update(postId, body: {
      'tags': tagIds,
      'tags+': remainingTags,
    });
  }

  Future<RecordModel> getPostWithTags(String postId) async {
    return await pb.collection('posts').getOne(
      postId,
      expand: 'tags',
    );
  }
}

// Usage
final manager = PostManager(pb);
await manager.addTag('POST_ID', 'NEW_TAG_ID');
final post = await manager.getPostWithTags('POST_ID');
\`\`\`

### Example 4: Filtering Posts by Tag

\`\`\`dart
// Get all posts with a specific tag
final posts = await pb.collection('posts').getList(
  page: 1,
  perPage: 50,
  filter: 'tags.id ?= "TAG_ID"',
  expand: 'author,tags',
  sort: '-created',
);

for (var post in posts.items) {
  print('${post.getStringValue('title')}');
  final author = post.expand?['author'] as Map<String, dynamic>?;
  print('  by ${author?['name']}');
}
\`\`\`

### Example 5: User Dashboard with Related Content

\`\`\`dart
Future<void> getUserDashboard(String userId) async {
  // Get user with all related content
  final user = await pb.collection('users').getOne(
    userId,
    expand: 'posts_via_author,comments_via_user.post',
  );

  print('Dashboard for ${user.getStringValue('name')}');
  final posts = user.expand?['posts_via_author'] as List<dynamic>?;
  print('\nPosts (${posts?.length ?? 0}):');
  if (posts != null) {
    for (var post in posts) {
      print('  - ${(post as Map<String, dynamic>)['title']}');
    }
  }

  print('\nRecent Comments:');
  final comments = user.expand?['comments_via_user'] as List<dynamic>?;
  if (comments != null) {
    for (var comment in comments.take(5)) {
      final cmt = comment as Map<String, dynamic>;
      final post = cmt['expand']?['post'] as Map<String, dynamic>?;
      print('  On "${post?['title']}": ${cmt['message']}');
    }
  }
}
\`\`\`

### Example 6: Helper Function for Safe Expand Access

\`\`\`dart
// Helper to safely get expanded relation
dynamic getExpanded(RecordModel record, String field) {
  return record.expand?[field];
}

// Helper to get expanded relation as list
List<dynamic>? getExpandedList(RecordModel record, String field) {
  final value = record.expand?[field];
  if (value is List) {
    return value;
  }
  return null;
}

// Helper to get expanded relation as map
Map<String, dynamic>? getExpandedMap(RecordModel record, String field) {
  final value = record.expand?[field];
  if (value is Map<String, dynamic>) {
    return value;
  }
  return null;
}

// Usage
final post = await pb.collection('posts').getOne(
  'POST_ID',
  expand: 'author,tags',
);

final author = getExpandedMap(post, 'author');
print(author?['name']);

final tags = getExpandedList(post, 'tags');
if (tags != null) {
  for (var tag in tags) {
    print((tag as Map<String, dynamic>)['name']);
  }
}
\`\`\`

## Best Practices

1. **Use Expand Wisely**: Only expand relations you actually need to reduce response size and improve performance.

2. **Handle Missing Expands**: Always check if expand data exists before accessing:

   \`\`\`dart
   final user = record.expand?['user'] as Map<String, dynamic>?;
   if (user != null) {
     print(user['name']);
   }
   \`\`\`

3. **Pagination for Large Back-Relations**: If you expect more than 1000 related records, fetch them separately with pagination.

4. **Type Safety**: Use type checking when accessing expand data since it's dynamically typed.

5. **Error Handling**: Handle cases where related records might not be accessible due to API rules.

6. **Nested Limit**: Remember that nested expands are limited to 6 levels deep.

## Performance Considerations

- **Expand Cost**: Expanding relations doesn't require additional round trips, but increases response payload size
- **Back-Relation Limit**: The 1000 record limit for back-relations prevents extremely large responses
- **Permission Checks**: Each expanded relation is checked against the collection's `viewRule`
- **Nested Depth**: Limit nested expands to avoid performance issues (max 6 levels supported)

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection and field configuration
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filtering and querying related records
