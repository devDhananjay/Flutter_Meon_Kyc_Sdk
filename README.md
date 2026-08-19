# flutter_meon_kyc

**Current version: `2.1.2`**

A comprehensive Flutter package for handling Know Your Customer (KYC) processes in mobile applications. This package provides an advanced WebView-based KYC solution with automatic permission handling, IPV (In-Person Verification) support, payment link integration, SSO session start, and complete lifecycle management.

## Features

- 🚀 **Easy Integration** - Simple API with sensible defaults
- 🔑 **Two start modes** - Normal KYC URL flow, or SSO via `/get_sso_route`
- 🎯 **Automatic Permission Management** - Camera, microphone, and location permissions
- 👤 **IPV Support** - In-Person Verification with automatic detection
- 💳 **Payment Link Handling** - UPI and payment app integration
- 🔄 **Lifecycle Management** - Automatic session cleanup with logout
- ✅ **Success Detection** - Intelligent detection of KYC completion
- 🎨 **Customizable UI** - Custom styles and header configuration
- 📱 **Platform Support** - Android and iOS compatible
- 🔒 **Error Handling** - Comprehensive error management
- 📊 **Logging** - Built-in logging for debugging

## Which flow should I use?

| | Normal KYC | SSO KYC |
|---|---|---|
| **When** | Existing clients / open the company KYC page directly | User is identified by mobile number; start a unique SSO session |
| **Extra fields** | None | `mobileNumber` + `secretKey` (required together) |
| **Optional SSO fields** | — | `redirectUrl`, `notification` |
| **What opens in WebView** | `{baseURL}/{companyName}/{workflow}` | `short_url` returned by `/get_sso_route` |
| **After WebView opens** | Same (IPV, UPI, permissions, success, logout) | Same |

Existing apps that already use `MeonKYC(companyName: ...)` do **not** need to change anything. SSO is opt-in.

## Installation

Add `flutter_meon_kyc` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_meon_kyc: ^2.1.2
```

Run:

```bash
flutter pub get
```

## Platform Setup

### Android

#### 1. Required permissions

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <!-- Optional, but recommended for some OEMs when capturing video/audio -->
    <uses-permission android:name="android.permission.VIDEO_CAPTURE" />
    <uses-permission android:name="android.permission.AUDIO_CAPTURE" />

    <!-- Recommended hardware features -->
    <uses-feature android:name="android.hardware.camera" android:required="true" />
    <uses-feature android:name="android.hardware.microphone" android:required="false" />
    <uses-feature android:name="android.hardware.location.gps" />
    <uses-feature android:name="android.hardware.location.network" />
    
    <!-- Optional: For payment links (UPI apps visibility) -->
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="upi" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="phonepe" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="gpay" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="paytmmp" />
        </intent>
    </queries>

    <application
        android:name="${applicationName}"
        android:label="Your App Name"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true">

        <!-- FileProvider needed by flutter_inappwebview for camera/photo capture -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.flutter_inappwebview_android.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/flutter_inappwebview_file_paths" />
        </provider>

        <!-- Your MainActivity and other configuration -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

Also create the `flutter_inappwebview_file_paths.xml` resource file referenced above:

```xml
<!-- android/app/src/main/res/xml/flutter_inappwebview_file_paths.xml -->
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-files-path
        name="images"
        path="Pictures" />
    <external-files-path
        name="camera"
        path="." />
</paths>
```

Update `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34  // or higher
    
    defaultConfig {
        minSdkVersion 21  // or higher
        targetSdkVersion 34
    }
}
```

### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- Camera permission -->
    <key>NSCameraUsageDescription</key>
    <string>Camera access is required for KYC verification</string>

    <!-- Microphone permission -->
    <key>NSMicrophoneUsageDescription</key>
    <string>Microphone access is required for video verification</string>

    <!-- Location permission -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Location access is required for KYC verification</string>

    <!-- Optional: Allow arbitrary loads for KYC domains.
         For stricter ATS, you can instead whitelist only Meon KYC hosts. -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
```

Update `ios/Podfile` (minimum iOS version):

```ruby
platform :ios, '12.0'
```

## Usage

Import once, then choose **Normal** or **SSO**. Both use the same `MeonKYC` widget, callbacks, IPV, payments, and success detection.

```dart
import 'package:flutter_meon_kyc/flutter_meon_kyc.dart';
```

---

### 1. Normal KYC flow

Use this when you only have `companyName` (and optionally `workflow`). No SSO API is called.

#### How it works

1. Widget starts and clears any previous WebView session (`/{companyName}/logout`).
2. WebView opens the KYC entry URL:
   `{baseURL}/{companyName}/{workflow}`  
   Example: `https://live.meon.co.in/your-company-name/individual`
3. User completes KYC in the WebView (documents, IPV, payments, etc.).
4. On success, session is cleared and `onSuccess` is called.

#### Code

```dart
class KYCScreen extends StatelessWidget {
  const KYCScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeonKYC(
        companyName: 'your-company-name',
        workflow: 'individual',
        onSuccess: (data) {
          print('KYC Completed: $data');
          Navigator.of(context).pop();
        },
        onError: (error) {
          print('KYC Error: $error');
        },
        onClose: () {
          print('KYC Closed');
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
```

Do **not** pass `mobileNumber` or `secretKey` for this flow.

---

### 2. SSO KYC flow

Use this when the host app already knows the user's **mobile number** and you want a unique SSO session from `/get_sso_route`.

`mobileNumber` and `secretKey` must be passed **together**. If only one is set, the widget reports an error and does not start KYC.

#### How it works

1. Widget calls `POST {baseURL}/get_sso_route` with company, workflow, secret key, and `unique_keys.mobile_number`.
2. API returns `short_url` (and a longer `url`; the SDK uses **`short_url` only**).
3. Widget clears any previous WebView session (`/{companyName}/logout`).
4. WebView opens `short_url`.
5. From here the journey is the same as Normal KYC: IPV, UPI, permissions, etc.
6. When Meon redirects to your `redirect_url`, `onSuccess` fires **immediately** (WebView does not need to load that page).

#### Code

Pass `mobileNumber` from your frontend. It is sent as `unique_keys.mobile_number`.

```dart
class SsoKYCScreen extends StatelessWidget {
  final String mobileNumber;
  final String secretKey;

  const SsoKYCScreen({
    Key? key,
    required this.mobileNumber,
    required this.secretKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeonKYC(
        companyName: 'your-company-name',
        workflow: 'individual',
        secretKey: secretKey,
        mobileNumber: mobileNumber,
        redirectUrl: 'https://www.google.com', // optional
        notification: false, // optional, default false
        onSuccess: (data) {
          print('KYC Completed: $data');
          Navigator.of(context).pop();
        },
        onError: (error) {
          print('KYC Error: $error');
        },
        onClose: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
```

#### SSO API request (sent by the package)

`POST https://live.meon.co.in/get_sso_route`

```json
{
  "company": "your-company-name",
  "workflowName": "individual",
  "secret_key": "your-secret-key",
  "notification": false,
  "unique_keys": {
    "mobile_number": "9411441937"
  },
  "additional_info": {"skip": "yes"},
  "is_redirect": true,
  "redirect_url": "https://www.google.com"
}
```

- `unique_keys.mobile_number` comes from the `mobileNumber` argument.
- `additional_info` defaults to `{ "skip": "yes" }` (override with `additionalInfo`).
- `is_redirect` defaults to `true`. If `redirectUrl` is omitted, `redirect_url` is `https://www.google.com`.

#### SSO API response (used by the package)

```json
{
  "short_url": "https://live.meon.co.in/shorten/?6tqFBpn3730O",
  "url": "http://live.meon.co.in/your-company-name/individual/..."
}
```

The WebView loads `short_url`. The long `url` field is ignored.

---

### Advanced Usage (common options)

These options work for **both** Normal and SSO flows.

```dart
MeonKYC(
  // Required
  companyName: 'your-company-name',

  // Optional - Workflow type
  workflow: 'individual', // or 'business', 'custom-workflow'

  // SSO only — omit both to use Normal flow
  // mobileNumber: '9411441937',
  // secretKey: 'your-secret-key',
  // redirectUrl: 'https://www.google.com',
  // notification: false,

  // Optional - Callbacks
  onSuccess: (data) {
    // data contains:
    // - status: 'completed'
    // - timestamp: ISO8601 timestamp
    // - url: current URL
    // - message: success message
    print('Success: ${data['message']}');
    Navigator.of(context).pushReplacementNamed('/dashboard');
  },

  onError: (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error')),
    );
  },

  onClose: () {
    Navigator.of(context).pop();
  },

  // Optional - Feature flags
  enableIPV: true, // Enable In-Person Verification
  enablePayments: true, // Enable payment link handling
  autoRequestPermissions: true, // Auto-request permissions for IPV
  showHeader: true, // Show custom header bar

  // Optional - Customization
  headerTitle: 'Complete Your KYC',
  baseURL: 'https://live.meon.co.in', // Or your custom domain

  // Optional - Custom styles
  customStyles: {
    'container': BoxDecoration(
      color: Colors.white,
    ),
    'header': BoxDecoration(
      color: Colors.blue,
      boxShadow: [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    'headerTitle': TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  },
)
```

### Full Example with Navigation (Normal flow)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_meon_kyc/flutter_meon_kyc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KYC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Demo'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const KYCScreen(),
              ),
            );
          },
          child: const Text('Start KYC Process'),
        ),
      ),
    );
  }
}

class KYCScreen extends StatelessWidget {
  const KYCScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeonKYC(
        companyName: 'demo-company',
        workflow: 'individual',
        enableIPV: true,
        enablePayments: true,
        autoRequestPermissions: true,
        showHeader: true,
        headerTitle: 'Complete KYC',
        onSuccess: (data) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Success'),
              content: Text('KYC completed at ${data['timestamp']}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close KYC screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
        onClose: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
```

## API Reference

### MeonKYC Widget

#### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `companyName` | `String` | Your company identifier (required) |

#### Common Optional Parameters (both flows)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `workflow` | `String` | `'individual'` | KYC workflow type (`'individual'`, `'business'`, etc.) |
| `onSuccess` | `Function(Map<String, dynamic>)` | `null` | Called when KYC is completed successfully |
| `onError` | `Function(String)` | `null` | Called when an error occurs |
| `onClose` | `Function()` | `null` | Called when user closes the KYC screen |
| `customStyles` | `Map<String, dynamic>?` | `null` | Custom styles for container, header, and title |
| `enableIPV` | `bool` | `true` | Enable In-Person Verification features |
| `enablePayments` | `bool` | `true` | Enable payment link handling |
| `autoRequestPermissions` | `bool` | `true` | Auto-request permissions when IPV step is detected |
| `showHeader` | `bool` | `true` | Show custom header with navigation controls |
| `headerTitle` | `String` | `'KYC Process'` | Title text in the header |
| `baseURL` | `String` | `'https://live.meon.co.in'` | Base URL for KYC and SSO APIs |

#### SSO Parameters (omit all of these for Normal flow)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mobileNumber` | `String?` | `null` | Sent as `unique_keys.mobile_number`. Must be set together with `secretKey`. |
| `secretKey` | `String?` | `null` | Company secret for `/get_sso_route`. Must be set together with `mobileNumber`. |
| `redirectUrl` | `String?` | `null` | SSO `redirect_url`. Defaults to `https://www.google.com` in the API body when omitted |
| `notification` | `bool` | `false` | SSO `notification` flag |
| `additionalInfo` | `Map<String, dynamic>?` | `{ "skip": "yes" }` | SSO `additional_info` |
| `isRedirect` | `bool` | `true` | SSO `is_redirect` flag |

If `mobileNumber` is set without `secretKey` (or the reverse), KYC does not start and `onError` is called with:  
`mobileNumber and secretKey are both required for SSO KYC`.

### Callback Data Structures

#### onSuccess Data

```dart
{
  'status': 'completed',
  'timestamp': '2025-11-25T10:30:00.000Z',
  'url': 'https://live.meon.co.in/company/thank-you',
  'message': 'KYC process completed successfully',
  'trigger': 'thank_you_page' // or 'redirect_url'
}
```

## Features in Detail

### 1. Automatic Permission Management

The package automatically requests and manages the following permissions:
- **Camera**: For document scanning and face verification
- **Microphone**: For video verification
- **Location**: For verification purposes

Permissions are requested:
- Automatically when IPV step is detected (if `autoRequestPermissions` is true)
- Manually by calling the request dialog
- With proper error handling and settings navigation

### 2. IPV Detection

The package intelligently detects IPV (In-Person Verification) steps by monitoring URLs for:
- `face-finder.meon.co.in`
- `/ipv` paths
- Keywords: `face`, `video`

When detected:
- Permissions are automatically requested (if enabled)
- Header title changes to "IPV Verification"
- Permission state is injected into the WebView

### 3. Payment Link Handling

Supports opening payment apps directly:
- UPI apps: PhonePe, Google Pay, Paytm, BHIM
- Google Pay with multiple scheme fallbacks
- Automatic detection and external app launching
- Prevents WebView from loading payment URLs

### 4. Success Detection

**Dono triggers active hain** — jo pehle match ho, `onSuccess` ek baar call hota hai:

| Trigger | Kab | `trigger` value |
|---------|-----|-----------------|
| **Thank You page** | Page par "Thank You" + "journey has been completed" + "Redirecting in" dikhe | `thank_you_page` |
| **Redirect URL** | WebView aapke `redirect_url` par navigate kare (SSO / `isRedirect: true`) | `redirect_url` |

- Pehle jo bhi fire ho, frontend ko turant response milta hai
- Doosra trigger ignore hota hai (duplicate nahi)
- Dono cases mein session clear + same response format

```dart
onSuccess: (data) {
  print(data['trigger']); // 'thank_you_page' ya 'redirect_url'
}
```

### 5. Session Management

Complete lifecycle management:
- **Initial Logout**: Cleans up any existing session before starting (Normal and SSO)
- **SSO start**: If SSO params are present, `/get_sso_route` runs first, then logout, then `short_url`
- **Final Logout**: Automatically logs out after successful completion
- Graceful handling of logout failures

### 6. Custom Styling

Customize the appearance:

```dart
customStyles: {
  'container': BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.blue, Colors.purple],
    ),
  ),
  'header': BoxDecoration(
    color: Color(0xFF1E88E5),
  ),
  'headerTitle': TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
}
```

### 7. Header Controls

The custom header provides:
- **Back Button**: Navigate back in WebView history (when available)
- **Refresh Button**: Reload current page
- **Close Button**: Close KYC with confirmation dialog
- **Dynamic Title**: Changes based on current step (IPV, etc.)

## Troubleshooting

### Permissions Not Working

1. Ensure permissions are added to `AndroidManifest.xml` (Android) and `Info.plist` (iOS)
2. Set `autoRequestPermissions: true`
3. Check device settings to ensure permissions are granted

### WebView Not Loading (Normal flow)

1. Verify `companyName` is correct
2. Check network connectivity
3. Ensure `baseURL` is accessible
4. Check logs for detailed error messages

### SSO KYC Not Starting

1. Pass **both** `mobileNumber` and `secretKey`
2. Confirm `secretKey` matches the company on the Meon dashboard
3. Confirm `baseURL` (default `https://live.meon.co.in`) can reach `/get_sso_route`
4. Look for `[MeonKYC] SSO route error` in logs
5. Retry uses the same flow: SSO API is called again, then WebView opens `short_url`

### Payment Links Not Opening

1. Add `<queries>` section to `AndroidManifest.xml`
2. Ensure payment apps are installed on the device
3. Set `enablePayments: true`

### Back Button Not Working

The package uses `PopScope` to handle Android back button. If you're wrapping the widget in another `PopScope` or `WillPopScope`, it may conflict.

## Migration from SDKCall

If you're using the old `SDKCall` widget, migrate to `MeonKYC`:

**Old Code:**
```dart
SDKCall(
  companyName: 'company',
  workflowName: 'individual',
)
```

**New Code (Normal flow):**
```dart
MeonKYC(
  companyName: 'company',
  workflow: 'individual',
  onSuccess: (data) => print('Success'),
  onError: (error) => print('Error'),
  onClose: () => Navigator.pop(context),
)
```

The `SDKCall` widget is deprecated but still available for backward compatibility.

## Debugging

Enable detailed logging by checking console output. The package uses the `logger` package with tags:
- `[MeonKYC]` - General messages
- Look for permission, navigation, SSO route, and success detection logs

## Requirements

- **Package version**: 2.1.2
- **Flutter**: >= 1.17.0
- **Dart SDK**: >= 2.19.0 < 4.0.0
- **Android**: minSdkVersion 21+
- **iOS**: 12.0+

## License

MIT License - See LICENSE file for details

## Support

For issues and feature requests, please visit: [GitHub Issues](https://github.com/devDhananjay/Flutter_Meon_Kyc_Sdk/issues)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

---

**Note**: This package requires an active Meon KYC account and valid company configuration. SSO flow additionally requires a valid `secretKey`. Contact Meon support for setup assistance.
