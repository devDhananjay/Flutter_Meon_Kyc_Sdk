## [2.0.0] - 2025-11-25
### Added
- **Complete Rewrite**: New `MeonKYC` widget with comprehensive features matching React Native implementation
- **Automatic Permission Management**: Auto-request camera, microphone, and location permissions
- **IPV Detection**: Intelligent detection of In-Person Verification steps with automatic permission handling
- **Payment Link Support**: Native handling of UPI and payment app links (PhonePe, Google Pay, Paytm, BHIM)
- **Success Detection**: JavaScript-based detection of KYC completion with MutationObserver
- **Session Management**: Automatic logout on initialization and completion
- **Custom Header**: Interactive header with back, refresh, and close buttons
- **JavaScript Injection**: Permission state injection, success detection, and payment handling scripts
- **External URL Handling**: Automatic opening of external apps and payment links
- **Loading States**: Comprehensive loading indicators and error screens
- **Custom Styling**: Support for custom styles (container, header, headerTitle)
- **Callback System**: `onSuccess`, `onError`, and `onClose` callbacks with detailed data
- **Configuration Options**: `enableIPV`, `enablePayments`, `autoRequestPermissions`, `showHeader`
- **Dynamic Parameters**: Customizable `workflow`, `headerTitle`, and `baseURL`
- **Hardware Back Button**: Proper Android back button handling with WebView navigation
- **HTTP Package**: Added for API calls (logout functionality)
- **Backward Compatibility**: Deprecated `SDKCall` widget maintained for legacy support

### Changed
- Migrated from basic WebView to feature-rich implementation
- Updated WebView to use modern `WebViewController` API
- Enhanced error handling with proper user feedback
- Improved logging with detailed debug information
- Better state management with comprehensive flags

### Breaking Changes
- Main widget renamed from `SDKCall` to `MeonKYC` (old widget deprecated but still available)
- New parameter structure with callbacks instead of simple navigation
- Requires `http` package dependency

### Migration Guide
Replace `SDKCall` with `MeonKYC` and add callbacks:
```dart
// Old
SDKCall(
  companyName: 'company',
  workflowName: 'individual',
)

// New
MeonKYC(
  companyName: 'company',
  workflow: 'individual',
  onSuccess: (data) => handleSuccess(data),
  onError: (error) => handleError(error),
  onClose: () => Navigator.pop(context),
)
```

## [1.0.4] - 2025-01-13
### Added
- Added WebView integration.
- Added logging framework to replace print statements.

### Fixed
- Fixed compatibility issues with SurfaceAndroidWebView.
