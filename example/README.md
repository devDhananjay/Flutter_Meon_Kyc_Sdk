# Meon KYC Example App

This is a complete example demonstrating how to use the `flutter_meon_kyc` package in your Flutter application.

## Features Demonstrated

- Basic KYC integration with Individual workflow
- Business KYC workflow
- Success, error, and close callbacks
- Custom styling
- Permission handling
- IPV support
- Payment link handling

## Getting Started

### Prerequisites

1. Flutter SDK installed
2. Android Studio or Xcode for mobile development
3. A valid Meon KYC company account

### Setup

1. Navigate to the example directory:
```bash
cd example
```

2. Get dependencies:
```bash
flutter pub get
```

3. Update the company name in `lib/main.dart`:
```dart
MeonKYC(
  companyName: 'your-company-name', // Replace with your actual company name
  // ... other parameters
)
```

### Running the Example

#### Android

```bash
flutter run -d android
```

Make sure you have added the required permissions to `android/app/src/main/AndroidManifest.xml` (see main README).

#### iOS

```bash
flutter run -d ios
```

Make sure you have added the required permissions to `ios/Runner/Info.plist` (see main README).

## Code Structure

- `lib/main.dart` - Main application with:
  - `HomePage` - Landing page with buttons to start KYC
  - `KYCScreen` - Screen that displays the MeonKYC widget
  - Demonstration of all major features and callbacks

## Customization

You can customize the example by modifying:

- **Company Name**: Change `companyName` parameter
- **Workflow**: Change `workflow` parameter ('individual', 'business', etc.)
- **Header Title**: Change `headerTitle` parameter
- **Styling**: Modify `customStyles` parameter
- **Base URL**: Change `baseURL` if using custom domain
- **Feature Flags**: Toggle `enableIPV`, `enablePayments`, `autoRequestPermissions`, `showHeader`

## Testing Different Workflows

The example includes two workflow types:

1. **Individual KYC** - For individual user verification
2. **Business KYC** - For business entity verification

Add more buttons in `HomePage` to test other custom workflows.

## Troubleshooting

### Permissions Not Working

Ensure you've added all required permissions to platform-specific files:
- Android: `AndroidManifest.xml`
- iOS: `Info.plist`

### WebView Not Loading

1. Check your internet connection
2. Verify the `companyName` is correct
3. Ensure the Meon KYC service is accessible
4. Check console logs for detailed error messages

### Payment Links Not Opening

1. Ensure payment apps are installed on the device
2. Add `<queries>` section to `AndroidManifest.xml` (Android 11+)
3. Set `enablePayments: true`

## Learn More

For more details about the package, see the main [README](../README.md).

## Support

For issues and questions:
- Package Issues: [GitHub Issues](https://github.com/your-repo/flutter-meon-kyc/issues)
- Meon KYC Support: Contact your Meon representative

