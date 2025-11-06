# Authentication - Dart SDK Documentation

## Overview

Authentication in BosBase is stateless and token-based. A client is considered authenticated as long as it sends a valid `Authorization: YOUR_AUTH_TOKEN` header with requests.

**Key Points:**
- **No sessions**: BosBase APIs are fully stateless (tokens are not stored in the database)
- **No logout endpoint**: To "logout", simply clear the token from your local state (`pb.authStore.clear()`)
- **Token generation**: Auth tokens are generated through auth collection Web APIs or programmatically
- **Admin users**: `_superusers` collection works like regular auth collections but with full access (API rules are ignored)
- **OAuth2 limitation**: OAuth2 is not supported for `_superusers` collection

## Authentication Methods

BosBase supports multiple authentication methods that can be configured individually for each auth collection:

1. **Password Authentication** - Email/username + password
2. **OTP Authentication** - One-time password via email
3. **OAuth2 Authentication** - Google, GitHub, Microsoft, etc.
4. **Multi-factor Authentication (MFA)** - Requires 2 different auth methods

## Authentication Store

The SDK maintains an `authStore` that automatically manages the authentication state:

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');

// Check authentication status
print(pb.authStore.isValid);      // true/false
print(pb.authStore.token);        // current auth token
print(pb.authStore.record);       // authenticated user record

// Clear authentication (logout)
pb.authStore.clear();
\`\`\`

## Password Authentication

Authenticate using email/username and password.

**Backend Endpoint:** \`POST /api/collections/{collection}/auth-with-password\`

### Basic Usage

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');

// Authenticate with email and password
final authData = await pb.collection('users').authWithPassword(
  'test@example.com',
  'password123',
);

// Auth data is automatically stored in pb.authStore
print(pb.authStore.isValid);  // true
print(pb.authStore.token);    // JWT token
print(pb.authStore.record?.id); // user record ID
\`\`\`

### Response Format

\`\`\`dart
RecordAuth(
  token: "eyJhbGciOiJIUzI1NiJ9...",
  record: RecordModel(
    id: "record_id",
    data: {
      'email': 'test@example.com',
      // ... other user fields
    },
  ),
)
\`\`\`

### Error Handling with MFA

\`\`\`dart
try {
  await pb.collection('users').authWithPassword('test@example.com', 'pass123');
} on ClientException catch (e) {
  // Check for MFA requirement
  final mfaId = e.response?['mfaId'];
  if (mfaId != null) {
    // Handle MFA flow (see Multi-factor Authentication section)
  } else {
    print('Authentication failed: ${e.message}');
  }
}
\`\`\`

## OTP Authentication

One-time password authentication via email.

**Backend Endpoints:**
- \`POST /api/collections/{collection}/request-otp\` - Request OTP
- \`POST /api/collections/{collection}/auth-with-otp\` - Authenticate with OTP

### Request OTP

\`\`\`dart
// Send OTP to user's email
final result = await pb.collection('users').requestOTP('test@example.com');
print(result.otpId);  // OTP ID to use in authWithOTP
\`\`\`

### Authenticate with OTP

\`\`\`dart
// Step 1: Request OTP
final result = await pb.collection('users').requestOTP('test@example.com');

// Step 2: User enters OTP from email
final authData = await pb.collection('users').authWithOTP(
  result.otpId,
  '123456',  // OTP code from email
);
\`\`\`

## OAuth2 Authentication

**Backend Endpoint:** \`POST /api/collections/{collection}/auth-with-oauth2\`

### All-in-One Method (Recommended)

\`\`\`dart
import 'package:bosbase/bosbase.dart';
import 'package:url_launcher/url_launcher.dart';

final pb = Bosbase('https://bosbase.io');

// Opens browser/app with OAuth2 provider page
final authData = await pb.collection('users').authWithOAuth2('google', (url) async {
  await launchUrl(url);
});

print(pb.authStore.token);
print(pb.authStore.record);
\`\`\`

### Manual Code Exchange

\`\`\`dart
// Get auth methods
final authMethods = await pb.collection('users').listAuthMethods();
final provider = authMethods.oauth2?.providers?.firstWhere(
  (p) => p.name == 'google',
);

// Exchange code for token (after OAuth2 redirect)
final authData = await pb.collection('users').authWithOAuth2Code(
  provider.name,
  code,
  provider.codeVerifier,
  redirectUrl,
);
\`\`\`

## Multi-Factor Authentication (MFA)

Requires 2 different auth methods.

\`\`\`dart
String? mfaId;

try {
  // First auth method (password)
  await pb.collection('users').authWithPassword('test@example.com', 'pass123');
} on ClientException catch (e) {
  mfaId = e.response?['mfaId'];
  
  if (mfaId != null) {
    // Second auth method (OTP)
    final otpResult = await pb.collection('users').requestOTP('test@example.com');
    await pb.collection('users').authWithOTP(
      otpResult.otpId,
      '123456',
      query: {'mfaId': mfaId},
    );
  }
}
\`\`\`

## User Impersonation

Superusers can impersonate other users.

**Backend Endpoint:** \`POST /api/collections/{collection}/impersonate/{id}\`

\`\`\`dart
// Authenticate as superuser
await pb.admins.authWithPassword('admin@example.com', 'adminpass');

// Impersonate a user
final impersonateClient = await pb.collection('users').impersonate(
  'USER_RECORD_ID',
  3600,  // Optional: token duration in seconds
);

// Use impersonate client
final data = await impersonateClient.collection('posts').getFullList();
\`\`\`

## Auth Token Verification

Verify token by calling \`authRefresh()\`.

**Backend Endpoint:** \`POST /api/collections/{collection}/auth-refresh\`

\`\`\`dart
try {
  final authData = await pb.collection('users').authRefresh();
  print('Token is valid');
} catch (e) {
  print('Token verification failed: $e');
  pb.authStore.clear();
}
\`\`\`

## List Available Auth Methods

**Backend Endpoint:** \`GET /api/collections/{collection}/auth-methods\`

\`\`\`dart
final authMethods = await pb.collection('users').listAuthMethods();
print(authMethods.password?.enabled);
print(authMethods.oauth2?.providers);
print(authMethods.mfa?.enabled);
\`\`\`

## Complete Examples

See the full documentation for detailed examples of:
- Full authentication flow
- OAuth2 integration
- Token management
- Admin impersonation
- Error handling

**Note for Android 15+:** When using OAuth2, check the note in https://github.com/bosbase/dart-sdk#oauth2-and-android-15.

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [API Rules](./API_RULES_AND_FILTERS.md)

## Detailed Examples

### Example 1: Complete Authentication Flow with Error Handling

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');

Future<RecordAuth> authenticateUser(String email, String password) async {
  try {
    // Try password authentication
    final authData = await pb.collection('users').authWithPassword(email, password);
    
    print('Successfully authenticated: ${authData.record.data['email']}');
    return authData;
    
  } on ClientException catch (e) {
    // Check if MFA is required
    if (e.statusCode == 401 && e.response?['mfaId'] != null) {
      print('MFA required, proceeding with second factor...');
      return await handleMFA(email, e.response!['mfaId']);
    }
    
    // Handle other errors
    if (e.statusCode == 400) {
      throw Exception('Invalid credentials');
    } else if (e.statusCode == 403) {
      throw Exception('Password authentication is not enabled for this collection');
    } else {
      rethrow;
    }
  }
}

Future<RecordAuth> handleMFA(String email, String mfaId) async {
  // Request OTP for second factor
  final otpResult = await pb.collection('users').requestOTP(email);
  
  // In a real app, show a dialog/form for the user to enter OTP
  // For this example, we'll simulate getting the OTP
  final userEnteredOTP = await getUserOTPInput(); // Your UI function
  
  try {
    // Authenticate with OTP and MFA ID
    final authData = await pb.collection('users').authWithOTP(
      otpResult.otpId,
      userEnteredOTP,
      query: {'mfaId': mfaId},
    );
    
    print('MFA authentication successful');
    return authData;
  } on ClientException catch (e) {
    if (e.statusCode == 429) {
      throw Exception('Too many OTP attempts, please request a new OTP');
    }
    throw Exception('Invalid OTP code');
  }
}

// Usage
authenticateUser('user@example.com', 'password123')
  .then((authData) {
    print('User is authenticated: ${pb.authStore.record?.data['email']}');
  })
  .catchError((err) {
    print('Authentication failed: $err');
  });
\`\`\`

### Example 2: OAuth2 Integration

\`\`\`dart
import 'package:bosbase/bosbase.dart';
import 'package:url_launcher/url_launcher.dart';

final pb = Bosbase('https://your-domain.com');

// OAuth2 login function
Future<void> loginWithGoogle() async {
  try {
    // Check available providers first
    final authMethods = await pb.collection('users').listAuthMethods();
    
    if (authMethods.oauth2?.enabled != true) {
      throw Exception('OAuth2 is not enabled for this collection');
    }
    
    final googleProvider = authMethods.oauth2?.providers?.firstWhere(
      (p) => p.name == 'google',
      orElse: () => throw Exception('Google OAuth2 is not configured'),
    );
    
    // Authenticate with Google
    final authData = await pb.collection('users').authWithOAuth2('google', (url) async {
      // Open the OAuth2 URL
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw Exception('Could not launch $url');
      }
    });
    
    // Check if this is a new user
    if (authData.meta?['isNew'] == true) {
      print('Welcome new user! ${authData.record.data}');
      // Navigate to onboarding
    } else {
      print('Welcome back! ${authData.record.data}');
      // Navigate to dashboard
    }
    
  } on ClientException catch (e) {
    if (e.statusCode == 403) {
      print('OAuth2 authentication is not enabled');
    } else {
      print('OAuth2 authentication failed: ${e.message}');
    }
  }
}

// Usage in Flutter widget
ElevatedButton(
  onPressed: loginWithGoogle,
  child: Text('Login with Google'),
)
\`\`\`

### Example 3: Token Management and Refresh

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');

// Check if user is already authenticated
Future<bool> checkAuth() async {
  if (pb.authStore.isValid) {
    print('User is authenticated: ${pb.authStore.record?.data['email']}');
    
    try {
      // Verify token is still valid and refresh if needed
      await pb.collection('users').authRefresh();
      print('Token refreshed successfully');
      return true;
    } catch (e) {
      print('Token expired or invalid, clearing auth');
      pb.authStore.clear();
      return false;
    }
  }
  return false;
}

// Setup auto-refresh before expiration
void setupAutoRefresh() {
  if (!pb.authStore.isValid) return;
  
  final token = pb.authStore.token;
  if (token == null) return;
  
  // Parse JWT to get expiration
  final parts = token.split('.');
  if (parts.length != 3) return;
  
  try {
    final payload = parts[1];
    final normalized = base64.normalize(payload);
    final decoded = utf8.decode(base64.decode(normalized));
    final Map<String, dynamic> data = json.decode(decoded);
    
    final expiresAt = data['exp'] as int?;
    if (expiresAt == null) return;
    
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final now = DateTime.now();
    final timeUntilExpiry = expiryTime.difference(now);
    
    // Refresh 5 minutes before expiration
    final refreshTime = timeUntilExpiry - const Duration(minutes: 5);
    
    if (refreshTime.isNegative) {
      // Already expired or expiring soon, refresh immediately
      pb.collection('users').authRefresh().catchError((err) {
        print('Auto-refresh failed: $err');
        pb.authStore.clear();
      });
    } else {
      // Schedule refresh
      Future.delayed(refreshTime, () {
        pb.collection('users').authRefresh()
          .then((_) {
            print('Token auto-refreshed');
            setupAutoRefresh(); // Schedule next refresh
          })
          .catchError((err) {
            print('Auto-refresh failed: $err');
            pb.authStore.clear();
          });
      });
    }
  } catch (e) {
    print('Error parsing token: $e');
  }
}

// Usage
checkAuth().then((isAuthenticated) {
  if (!isAuthenticated) {
    // Navigate to login
  } else {
    setupAutoRefresh();
  }
});
\`\`\`

### Example 4: Admin Impersonation

\`\`\`dart
import 'package:bosbase/bosbase.dart';

final pb = Bosbase('http://localhost:8090');

Future<void> impersonateUserForSupport(String userId) async {
  // Authenticate as admin
  await pb.admins.authWithPassword('admin@example.com', 'adminpassword');
  
  // Impersonate the user (1 hour token)
  final userClient = await pb.collection('users').impersonate(userId, 3600);
  
  print('Impersonating user: ${userClient.authStore.record?.data['email']}');
  
  // Use the impersonated client to test user experience
  final userRecords = await userClient.collection('posts').getFullList();
  print('User can see ${userRecords.length} posts');
  
  // Check what the user sees
  final userView = await userClient.collection('posts').getList(
    page: 1,
    perPage: 10,
    filter: pb.filter('published = true'),
  );
  
  print('User access check: ${userView.items.length} visible posts');
}

// Usage
impersonateUserForSupport('user_record_id').catchError((err) {
  print('Impersonation failed: $err');
});
\`\`\`

## Best Practices

1. **Secure Token Storage**: Never expose tokens in logs or client-side storage
2. **Token Refresh**: Implement automatic token refresh before expiration
3. **Error Handling**: Always handle MFA requirements and token expiration
4. **OAuth2 Security**: Always validate the `state` parameter in OAuth2 callbacks
5. **API Keys**: Use impersonation tokens for server-to-server communication only
6. **Superuser Tokens**: Never expose superuser impersonation tokens in client code
7. **OTP Security**: Use OTP with MFA for security-critical applications
8. **Android 15+**: Check OAuth2 requirements for Android 15+ (see SDK documentation)

## Troubleshooting

### Token Expired
If you get 401 errors, check if the token has expired:
\`\`\`dart
try {
  await pb.collection('users').authRefresh();
} catch (e) {
  // Token expired, require re-authentication
  pb.authStore.clear();
  // Navigate to login
}
\`\`\`

### MFA Required
If authentication returns 401 with mfaId:
\`\`\`dart
try {
  await pb.collection('users').authWithPassword(email, password);
} on ClientException catch (e) {
  if (e.statusCode == 401 && e.response?['mfaId'] != null) {
    // Proceed with second authentication factor
    final mfaId = e.response!['mfaId'];
  }
}
\`\`\`
