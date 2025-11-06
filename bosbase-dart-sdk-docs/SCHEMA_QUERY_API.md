# Schema Query API - Dart SDK Documentation

## Overview

The Schema Query API provides lightweight interfaces to retrieve collection field information without fetching full collection definitions. This is particularly useful for AI systems that need to understand the structure of collections and the overall system architecture.

**Key Features:**
- Get schema for a single collection by name or ID
- Get schemas for all collections in the system
- Lightweight response with only essential field information
- Support for all collection types (base, auth, view)
- Fast and efficient queries

**Backend Endpoints:**
- `GET /api/collections/{collection}/schema` - Get single collection schema
- `GET /api/collections/schemas` - Get all collection schemas

**Note**: All Schema Query API operations require superuser authentication.

## Authentication

All Schema Query API operations require superuser authentication:

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');

// Authenticate as superuser
await pb.admins.authWithPassword('admin@example.com', 'password');
// OR
await pb.collection('_superusers').authWithPassword('admin@example.com', 'password');
```

## Type Definitions

### CollectionFieldSchemaInfo

Simplified field information returned by schema queries:

```dart
class CollectionFieldSchemaInfo {
  String name;        // Field name
  String type;        // Field type (e.g., "text", "number", "email", "relation")
  bool? required;     // Whether the field is required
  bool? system;       // Whether the field is a system field
  bool? hidden;       // Whether the field is hidden
}
```

### CollectionSchemaInfo

Schema information for a single collection:

```dart
class CollectionSchemaInfo {
  String name;                        // Collection name
  String type;                        // Collection type ("base", "auth", "view")
  List<CollectionFieldSchemaInfo> fields;  // List of field information
}
```

## Get Single Collection Schema

Retrieves the schema (fields and types) for a single collection by name or ID.

### Method Signature

```dart
Future<CollectionSchemaInfo> getSchema(
  String collectionIdOrName, {
  Map<String, dynamic> query = const {},
  Map<String, String> headers = const {},
})
```

### Basic Usage

```dart
// Get schema for a collection by name
final schema = await pb.collections.getSchema('demo1');

print(schema.name);    // "demo1"
print(schema.type);    // "base"
print(schema.fields);  // List of field information

// Iterate through fields
for (final field in schema.fields) {
  print('${field.name}: ${field.type}${field.required == true ? ' (required)' : ''}');
}
```

### Using Collection ID

```dart
// Get schema for a collection by ID
final schema = await pb.collections.getSchema('_pbc_base_123');

print(schema.name);  // "demo1"
```

### Handling Different Collection Types

```dart
// Base collection
final baseSchema = await pb.collections.getSchema('demo1');
print(baseSchema.type);  // "base"

// Auth collection
final authSchema = await pb.collections.getSchema('users');
print(authSchema.type);  // "auth"

// View collection
final viewSchema = await pb.collections.getSchema('view1');
print(viewSchema.type);  // "view"
```

### Error Handling

```dart
try {
  final schema = await pb.collections.getSchema('nonexistent');
} on ClientResponseError catch (error) {
  if (error.statusCode == 404) {
    print('Collection not found');
  } else {
    print('Error: $error');
  }
}
```

## Get All Collection Schemas

Retrieves the schema (fields and types) for all collections in the system.

### Method Signature

```dart
Future<List<CollectionSchemaInfo>> getAllSchemas({
  Map<String, dynamic> query = const {},
  Map<String, String> headers = const {},
})
```

### Basic Usage

```dart
// Get schemas for all collections
final schemas = await pb.collections.getAllSchemas();

print('Total collections: ${schemas.length}');

// Iterate through all collections
for (final collection in schemas) {
  print('Collection: ${collection.name} (${collection.type})');
  print('Fields: ${collection.fields.length}');
  
  // List all fields
  for (final field in collection.fields) {
    print('  - ${field.name}: ${field.type}');
  }
}
```

### Filtering Collections by Type

```dart
final allSchemas = await pb.collections.getAllSchemas();

// Filter to only base collections
final baseCollections = allSchemas.where((c) => c.type == 'base').toList();

// Filter to only auth collections
final authCollections = allSchemas.where((c) => c.type == 'auth').toList();

// Filter to only view collections
final viewCollections = allSchemas.where((c) => c.type == 'view').toList();
```

### Building a Field Index

```dart
// Build a map of all field names and types across all collections
final allSchemas = await pb.collections.getAllSchemas();

final fieldIndex = <String, Map<String, dynamic>>{};

for (final collection in allSchemas) {
  for (final field in collection.fields) {
    final key = '${collection.name}.${field.name}';
    fieldIndex[key] = {
      'collection': collection.name,
      'collectionType': collection.type,
      'fieldName': field.name,
      'fieldType': field.type,
      'required': field.required ?? false,
      'system': field.system ?? false,
      'hidden': field.hidden ?? false,
    };
  }
}

// Use the index
print(fieldIndex['demo1.title']);  // Field information
```

## Complete Examples

### Example 1: AI System Understanding Collection Structure

```dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://127.0.0.1:8090');
await pb.admins.authWithPassword('admin@example.com', 'password');

// Get all collection schemas for system understanding
final allSchemas = await pb.collections.getAllSchemas();

// Create a comprehensive system overview
final systemOverview = allSchemas.map((collection) => {
  'name': collection.name,
  'type': collection.type,
  'fields': collection.fields.map((field) => {
    'name': field.name,
    'type': field.type,
    'required': field.required ?? false,
  }).toList(),
}).toList();

print('System Collections Overview:');
for (final collection in systemOverview) {
  print('\n${collection['name']} (${collection['type']}):');
  for (final field in collection['fields'] as List) {
    final required = field['required'] == true ? ' [required]' : '';
    print('  ${field['name']}: ${field['type']}$required');
  }
}
```

### Example 2: Validating Field Existence Before Query

```dart
// Check if a field exists before querying
Future<bool> checkFieldExists(String collectionName, String fieldName) async {
  try {
    final schema = await pb.collections.getSchema(collectionName);
    return schema.fields.any((field) => field.name == fieldName);
  } catch (e) {
    return false;
  }
}

// Usage
final hasTitleField = await checkFieldExists('demo1', 'title');
if (hasTitleField) {
  // Safe to query the field
  final records = await pb.collection('demo1').getList(
    page: 1,
    perPage: 20,
    fields: 'id,title',
  );
}
```

### Example 3: Dynamic Form Generation

```dart
// Generate form fields based on collection schema
Future<List<Map<String, dynamic>>> generateFormFields(String collectionName) async {
  final schema = await pb.collections.getSchema(collectionName);
  
  return schema.fields
      .where((field) => field.system != true && field.hidden != true)
      .map((field) => {
        'name': field.name,
        'type': field.type,
        'required': field.required ?? false,
        'label': field.name[0].toUpperCase() + field.name.substring(1),
      })
      .toList();
}

// Usage
final formFields = await generateFormFields('demo1');
print('Form Fields: $formFields');
// Output: [
//   {name: title, type: text, required: true, label: Title},
//   {name: description, type: text, required: false, label: Description},
//   ...
// ]
```

### Example 4: Schema Comparison

```dart
// Compare schemas between two collections
Future<Map<String, List<String>>> compareSchemas(
  String collection1,
  String collection2,
) async {
  final schemas = await Future.wait([
    pb.collections.getSchema(collection1),
    pb.collections.getSchema(collection2),
  ]);
  
  final schema1 = schemas[0];
  final schema2 = schemas[1];
  
  final fields1 = schema1.fields.map((f) => f.name).toSet();
  final fields2 = schema2.fields.map((f) => f.name).toSet();
  
  return {
    'common': fields1.intersection(fields2).toList(),
    'onlyIn1': fields1.difference(fields2).toList(),
    'onlyIn2': fields2.difference(fields1).toList(),
  };
}

// Usage
final comparison = await compareSchemas('demo1', 'demo2');
print('Common fields: ${comparison['common']}');
print('Only in demo1: ${comparison['onlyIn1']}');
print('Only in demo2: ${comparison['onlyIn2']}');
```

### Example 5: Building Dart Class Definitions

```dart
// Generate Dart class from collection schema
Future<String> generateDartClass(String collectionName) async {
  final schema = await pb.collections.getSchema(collectionName);
  
  final className = schema.name[0].toUpperCase() + schema.name.substring(1);
  
  final fieldDefinitions = schema.fields.map((field) {
    String dartType = 'String';
    
    switch (field.type) {
      case 'number':
        dartType = 'num';
        break;
      case 'bool':
        dartType = 'bool';
        break;
      case 'date':
      case 'autodate':
        dartType = 'DateTime?';
        break;
      case 'json':
        dartType = 'Map<String, dynamic>?';
        break;
      case 'file':
        dartType = 'String?';
        break;
      case 'select':
        dartType = 'String?';
        break;
      case 'relation':
        dartType = 'String?';
        break;
      default:
        dartType = 'String';
    }
    
    final nullable = field.required == true ? '' : '?';
    return '  ${dartType}$nullable ${field.name};';
  }).join('\n');
  
  return 'class $className {\n$fieldDefinitions\n}';
}

// Usage
final dartClass = await generateDartClass('demo1');
print(dartClass);
```

### Example 6: Flutter Form Widget Generation

```dart
import 'package:flutter/material.dart';

// Generate form widgets based on collection schema
Future<List<Widget>> generateFormWidgets(String collectionName) async {
  final schema = await pb.collections.getSchema(collectionName);
  final widgets = <Widget>[];
  
  for (final field in schema.fields) {
    if (field.system == true || field.hidden == true) continue;
    
    switch (field.type) {
      case 'text':
      case 'email':
      case 'url':
        widgets.add(
          TextFormField(
            decoration: InputDecoration(
              labelText: field.name,
            ),
            validator: field.required == true
                ? (value) => value?.isEmpty ?? true ? 'Required' : null
                : null,
          ),
        );
        break;
      case 'number':
        widgets.add(
          TextFormField(
            decoration: InputDecoration(
              labelText: field.name,
            ),
            keyboardType: TextInputType.number,
            validator: field.required == true
                ? (value) => value?.isEmpty ?? true ? 'Required' : null
                : null,
          ),
        );
        break;
      case 'bool':
        widgets.add(
          CheckboxListTile(
            title: Text(field.name),
            value: false,
            onChanged: (value) {},
          ),
        );
        break;
      // Add more field types as needed
    }
  }
  
  return widgets;
}

// Usage in Flutter widget
class DynamicForm extends StatefulWidget {
  final String collectionName;
  
  const DynamicForm({required this.collectionName, Key? key}) : super(key: key);
  
  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  List<Widget> _formFields = [];
  
  @override
  void initState() {
    super.initState();
    _loadFormFields();
  }
  
  Future<void> _loadFormFields() async {
    final fields = await generateFormWidgets(widget.collectionName);
    setState(() {
      _formFields = fields;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        children: _formFields,
      ),
    );
  }
}
```

## Response Structure

### Single Collection Schema Response

```json
{
  "name": "demo1",
  "type": "base",
  "fields": [
    {
      "name": "id",
      "type": "text",
      "required": true,
      "system": true,
      "hidden": false
    },
    {
      "name": "title",
      "type": "text",
      "required": true,
      "system": false,
      "hidden": false
    },
    {
      "name": "description",
      "type": "text",
      "required": false,
      "system": false,
      "hidden": false
    }
  ]
}
```

### All Collections Schemas Response

```json
{
  "collections": [
    {
      "name": "demo1",
      "type": "base",
      "fields": [...]
    },
    {
      "name": "users",
      "type": "auth",
      "fields": [...]
    },
    {
      "name": "view1",
      "type": "view",
      "fields": [...]
    }
  ]
}
```

## Use Cases

### 1. AI System Design
AI systems can query all collection schemas to understand the overall database structure and design queries or operations accordingly.

### 2. Code Generation
Generate client-side code, Dart classes, or form components based on collection schemas.

### 3. Documentation Generation
Automatically generate API documentation or data dictionaries from collection schemas.

### 4. Schema Validation
Validate queries or operations before execution by checking field existence and types.

### 5. Migration Planning
Compare schemas between environments or versions to plan migrations.

### 6. Dynamic UI Generation
Create dynamic forms, tables, or interfaces based on collection field definitions (especially useful in Flutter applications).

## Performance Considerations

- **Lightweight**: Schema queries return only essential field information, not full collection definitions
- **Efficient**: Much faster than fetching full collection objects
- **Cached**: Results can be cached for better performance
- **Batch**: Use `getAllSchemas()` to get all schemas in a single request

## Error Handling

```dart
try {
  final schema = await pb.collections.getSchema('demo1');
} on ClientResponseError catch (error) {
  switch (error.statusCode) {
    case 401:
      print('Authentication required');
      break;
    case 403:
      print('Superuser access required');
      break;
    case 404:
      print('Collection not found');
      break;
    default:
      print('Unexpected error: $error');
  }
}
```

## Best Practices

1. **Cache Results**: Schema information rarely changes, so cache results when appropriate
2. **Error Handling**: Always handle 404 errors for non-existent collections
3. **Filter System Fields**: When building UI, filter out system and hidden fields
4. **Batch Queries**: Use `getAllSchemas()` when you need multiple collection schemas
5. **Type Safety**: Leverage Dart's strong typing for better compile-time safety

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Full collection management API
- [Records API](./API_RECORDS.md) - Record CRUD operations
