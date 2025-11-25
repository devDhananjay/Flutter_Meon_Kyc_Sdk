# flutter_meon_kyc

A comprehensive Flutter package for handling Know Your Customer (KYC) processes in mobile applications. This package provides an advanced WebView-based KYC solution with automatic permission handling, IPV (In-Person Verification) support, payment link integration, and complete lifecycle management.

## Features

- 🚀 **Easy Integration** - Simple API with sensible defaults
- 🎯 **Automatic Permission Management** - Camera, microphone, and location permissions
- 👤 **IPV Support** - In-Person Verification with automatic detection
- 💳 **Payment Link Handling** - UPI and payment app integration
- 🔄 **Lifecycle Management** - Automatic session cleanup with logout
- ✅ **Success Detection** - Intelligent detection of KYC completion
- 🎨 **Customizable UI** - Custom styles and header configuration
- 📱 **Platform Support** - Android and iOS compatible
- 🔒 **Error Handling** - Comprehensive error management
- 📊 **Logging** - Built-in logging for debugging

## Installation

Add `flutter_meon_kyc` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_meon_kyc: ^1.2.1
```

Run:

```bash
flutter pub get
```

## Platform Setup

### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Optional: For payment links -->
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

    <application>
        <!-- Your app configuration -->
    </application>
</manifest>
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
    
    <!-- Optional: Allow arbitrary loads for specific domains -->
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

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_meon_kyc/flutter_meon_kyc.dart';

class KYCScreen extends StatelessWidget {
  const KYCScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeonKYC(
        companyName: 'your-company-name',
        onSuccess: (data) {
          print('KYC Completed: $data');
          // Handle success - navigate to next screen
          Navigator.of(context).pop();
        },
        onError: (error) {
          print('KYC Error: $error');
          // Handle error
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

### Advanced Usage

```dart
MeonKYC(
  // Required
  companyName: 'your-company-name',
  
  // Optional - Workflow type
  workflow: 'individual', // or 'business', 'custom-workflow'
  
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

### Full Example with Navigation

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
          // Show success dialog
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

#### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `workflow` | `String` | `'individual'` | KYC workflow type ('individual', 'business', etc.) |
| `onSuccess` | `Function(Map<String, dynamic>)` | `null` | Called when KYC is completed successfully |
| `onError` | `Function(String)` | `null` | Called when an error occurs |
| `onClose` | `Function()` | `null` | Called when user closes the KYC screen |
| `customStyles` | `Map<String, dynamic>?` | `null` | Custom styles for container, header, and title |
| `enableIPV` | `bool` | `true` | Enable In-Person Verification features |
| `enablePayments` | `bool` | `true` | Enable payment link handling |
| `autoRequestPermissions` | `bool` | `true` | Auto-request permissions when IPV step is detected |
| `showHeader` | `bool` | `true` | Show custom header with navigation controls |
| `headerTitle` | `String` | `'KYC Process'` | Title text in the header |
| `baseURL` | `String` | `'https://live.meon.co.in'` | Base URL for the KYC service |

### Callback Data Structures

#### onSuccess Data

```dart
{
  'status': 'completed',
  'timestamp': '2025-11-25T10:30:00.000Z',
  'url': 'https://live.meon.co.in/company/thank-you',
  'message': 'KYC process completed successfully'
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

Intelligent detection of KYC completion:
- Monitors page content for success patterns
- Checks for: "Thank You" + "journey has been completed" + "Redirecting in"
- Uses MutationObserver for dynamic content
- Prevents duplicate success callbacks
- Automatically performs logout before success callback

### 5. Session Management

Complete lifecycle management:
- **Initial Logout**: Cleans up any existing session before starting
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

### WebView Not Loading

1. Verify `companyName` is correct
2. Check network connectivity
3. Ensure `baseURL` is accessible
4. Check logs for detailed error messages

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

**New Code:**
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
- Look for permission, navigation, and success detection logs

## Requirements

- **Flutter**: >= 1.17.0
- **Dart SDK**: >= 2.19.0 < 4.0.0
- **Android**: minSdkVersion 21+
- **iOS**: 12.0+

## License

MIT License - See LICENSE file for details

## Support

For issues and feature requests, please visit: [GitHub Issues](https://github.com/your-repo/flutter-meon-kyc/issues)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

---

**Note**: This package requires an active Meon KYC account and valid company configuration. Contact Meon support for setup assistance.
