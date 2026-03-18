import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

/// Callback type for KYC success
typedef OnSuccessCallback = void Function(Map<String, dynamic> data);

/// Callback type for KYC error
typedef OnErrorCallback = void Function(String error);

/// Callback type for KYC close
typedef OnCloseCallback = void Function();

/// Simple model for UPI app option (used for chooser)
class _UpiAppOption {
  final String name;
  final Uri uri;
  final IconData icon;
  final Color color;

  const _UpiAppOption(
    this.name,
    this.uri, {
    required this.icon,
    required this.color,
  });
}

/// MeonKYC Widget - A comprehensive KYC solution for Flutter
class MeonKYC extends StatefulWidget {
  /// Company name (required)
  final String companyName;

  /// Workflow type (default: 'individual')
  final String workflow;

  /// Success callback
  final OnSuccessCallback? onSuccess;

  /// Error callback
  final OnErrorCallback? onError;

  /// Close callback
  final OnCloseCallback? onClose;

  /// Custom styles for the widget
  final Map<String, dynamic>? customStyles;

  /// Enable IPV (In-Person Verification) features
  final bool enableIPV;

  /// Enable payment link handling
  final bool enablePayments;

  /// Auto-request permissions when needed
  final bool autoRequestPermissions;

  /// Show header bar
  final bool showHeader;

  /// Header title text
  final String headerTitle;

  /// Base URL for the KYC service
  final String baseURL;

  const MeonKYC({
    Key? key,
    required this.companyName,
    this.workflow = 'individual',
    this.onSuccess,
    this.onError,
    this.onClose,
    this.customStyles,
    this.enableIPV = true,
    this.enablePayments = true,
    this.autoRequestPermissions = true,
    this.showHeader = true,
    this.headerTitle = 'KYC Process',
    this.baseURL = 'https://live.meon.co.in',
  }) : super(key: key);

  @override
  State<MeonKYC> createState() => _MeonKYCState();
}

class _MeonKYCState extends State<MeonKYC> {
  InAppWebViewController? _webViewController;
  final Logger _logger = Logger();

  bool _isLoading = true;
  bool _webViewLoading = false;
  bool _canGoBack = false;
  String _currentUrl = '';
  String? _error;
  bool _webViewRendered = false;
  bool _permissionsGranted = false;
  bool _isIpvStep = false;
  bool _successCalled = false;
  bool _initialLogoutDone = false;
  bool _hasReloadedAfterPermissions = false;
  bool _hideHeaderForCurrentPage = false;

  @override
  void initState() {
    super.initState();
    _performInitialLogout();
  }

  /// Perform initial logout before starting KYC
  Future<void> _performInitialLogout() async {
    if (widget.companyName.isEmpty) {
      const errorMsg = 'companyName is required';
      setState(() {
        _error = errorMsg;
        _isLoading = false;
      });
      widget.onError?.call(errorMsg);
      return;
    }

    if (!_initialLogoutDone) {
      try {
        _logger.i('[MeonKYC] Performing initial logout...');
        final logoutUrl = '${widget.baseURL}/${widget.companyName}/logout';

        final response = await http.get(Uri.parse(logoutUrl));

        if (response.statusCode == 200) {
          _logger.i('[MeonKYC] Initial logout successful: ${response.body}');
        } else {
          _logger.w('[MeonKYC] Initial logout failed with status: ${response.statusCode}');
        }
      } catch (e) {
        _logger.e('[MeonKYC] Error in initial logout: $e');
        // Continue even if logout fails
      }

      _initialLogoutDone = true;
    }

    setState(() {
      _isLoading = false;
    });

    _initializeWebView();
  }

  /// Initialize WebView controller (InAppWebView now creates the controller)
  void _initializeWebView() {
    // No-op for InAppWebView. Kept for backward compatibility with the
    // initialization flow; the actual controller is created in build().
    _currentUrl = '${widget.baseURL}/${widget.companyName}/${widget.workflow}';
  }

  /// Check if URL is an IPV step
  bool _checkIfIpvStep(String url) {
    return url.contains('face-finder.meon.co.in') ||
        url.contains('/ipv') ||
        url.toLowerCase().contains('face') ||
        url.toLowerCase().contains('video');
  }

  /// Request permissions for camera, microphone, and location
  Future<bool> _requestPermissions() async {
    if (!widget.enableIPV) return true;

    try {
      _logger.i('[MeonKYC] Requesting permissions...');

      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.location,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);

      if (allGranted) {
        _logger.i('[MeonKYC] All permissions granted');
        setState(() {
          _permissionsGranted = true;
        });
        return true;
      } else {
        _handlePermissionDenied(statuses);
        return false;
      }
    } catch (e) {
      _logger.e('[MeonKYC] Error requesting permissions: $e');
      _showPermissionErrorDialog();
      return false;
    }
  }

  /// Handle denied permissions
  void _handlePermissionDenied(Map<Permission, PermissionStatus> statuses) {
    List<String> deniedPermissions = [];

    if (statuses[Permission.camera] != PermissionStatus.granted) {
      deniedPermissions.add('Camera');
    }
    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      deniedPermissions.add('Microphone');
    }
    if (statuses[Permission.location] != PermissionStatus.granted) {
      deniedPermissions.add('Location');
    }

    if (deniedPermissions.isNotEmpty) {
      _showPermissionDeniedDialog(deniedPermissions);
    }
  }

  /// Show permission error dialog
  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Error'),
        content: const Text('Failed to request permissions. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show permission denied dialog
  void _showPermissionDeniedDialog(List<String> deniedPermissions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text(
          'IPV process requires ${deniedPermissions.join(', ')} permission(s) to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_canGoBack) {
                _webViewController?.goBack();
              } else {
                widget.onClose?.call();
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestPermissions();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Get permission injection JavaScript
  String _getPermissionInjectionScript() {
    return '''
    (function() {
      const storePermissionInSession = (name, state) => {
        try {
          sessionStorage.setItem('permission_' + name, state);
          localStorage.setItem('permission_' + name, state);
        } catch(e) {}
      };

      const permissionsGranted = ${_permissionsGranted.toString()};
      const permissions = ['camera', 'microphone', 'geolocation'];
      
      permissions.forEach(perm => {
        storePermissionInSession(perm, permissionsGranted ? 'granted' : 'denied');
      });

      if (navigator.permissions && navigator.permissions.query) {
        const originalQuery = navigator.permissions.query;
        navigator.permissions.query = function(permissionDesc) {
          if (permissions.includes(permissionDesc.name)) {
            return Promise.resolve({
              state: permissionsGranted ? 'granted' : 'denied',
              onchange: null
            });
          }
          return originalQuery.call(this, permissionDesc);
        };
      }

      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
        navigator.mediaDevices.getUserMedia = function(constraints) {
          if (!permissionsGranted) {
            return Promise.reject(new Error('Permissions not granted'));
          }
          return originalGetUserMedia.call(this, constraints);
        };
      }

      window.addEventListener('load', function() {
        if (permissionsGranted) {
          permissions.forEach(perm => storePermissionInSession(perm, 'granted'));
        }
      });
    })();
    ''';
  }

  /// Get success detection JavaScript
  String _getSuccessDetectionScript() {
    return '''
    (function() {
      if (window.__kycSuccessDetected) {
        return;
      }
      
      const checkForSuccessPage = () => {
        const pageText = document.body.innerText || document.body.textContent || '';
        
        const hasThankYou = pageText.includes('Thank You');
        const hasJourneyCompleted = pageText.includes('journey has been completed');
        const hasRedirecting = pageText.includes('Redirecting in') || pageText.includes('redirecting in');
        
        if (hasThankYou && hasJourneyCompleted && hasRedirecting) {
          if (window.__kycSuccessDetected) {
            return;
          }
          window.__kycSuccessDetected = true;
          
          console.log('[MeonKYC] Success page detected - Thank You page with redirect');
          
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage(JSON.stringify({
              type: 'KYC_SUCCESS',
              status: 'completed',
              timestamp: new Date().toISOString(),
              url: window.location.href
            }));
          }
        }
      };
      
      checkForSuccessPage();
      
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', checkForSuccessPage);
      }
      
      setTimeout(checkForSuccessPage, 500);
      setTimeout(checkForSuccessPage, 1000);
      
      const observer = new MutationObserver(() => {
        checkForSuccessPage();
      });
      
      observer.observe(document.body, {
        childList: true,
        subtree: true,
        characterData: true
      });
      
      setTimeout(() => {
        observer.disconnect();
      }, 3000);
    })();
    ''';
  }

  /// Get payment handling JavaScript
  String _getPaymentHandlingScript() {
    if (!widget.enablePayments) return '';

    return '''
    (function() {
      const handlePaymentClick = (event) => {
        const target = event.target;
        const href = target.href || target.getAttribute('href');
        
        const isPaymentLink = href && (
          href.includes('upi://') ||
          href.includes('paytmmp://') ||
          href.includes('phonepe://') ||
          href.includes('gpay://') ||
          href.includes('tez://') ||
          href.includes('google.payments://') ||
          href.includes('googlepay://') ||
          href.includes('bhim://')
        );
        
        if (isPaymentLink) {
          console.log('[MeonKYC] Payment button clicked:', href);
        }
      };
      
      document.addEventListener('click', handlePaymentClick, true);
      
      const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          mutation.addedNodes.forEach(function(node) {
            if (node.nodeType === 1) {
              const links = node.querySelectorAll('a, button, [onclick]');
              links.forEach(link => link.addEventListener('click', handlePaymentClick, true));
            }
          });
        });
      });
      
      observer.observe(document.body, { childList: true, subtree: true });
    })();
    ''';
  }

  /// Get layout hint JavaScript used to dynamically adjust SDK UI (e.g. hide
  /// header on specific landing screens where the page uses floating buttons).
  ///
  /// We don't rely on the URL here, because the same route is reused for
  /// multiple modules. Instead we look at page content.
  String _getLayoutHintScript() {
    return '''
    (function() {
      try {
        if (!window.FlutterChannel || !window.FlutterChannel.postMessage) {
          return;
        }

        var raw = document.body.innerText || document.body.textContent || '';
        var text = raw.toLowerCase();
        // Normalize quotes so "you're" / "you’re" / "you\'re" all match
        text = text.replace(/['"’]/g, '');

        var isFirstdematLanding =
          text.includes("youre almost ready to start trading") &&
          text.includes("complete these 4 simple steps") &&
          text.includes("start kyc");

        window.FlutterChannel.postMessage(JSON.stringify({
          type: 'LAYOUT_HINT',
          hideHeader: !!isFirstdematLanding
        }));
      } catch (e) {
        try { console.log('[MeonKYC] layout hint error', e); } catch (_) {}
      }
    })();
    ''';
  }

  /// Show bottom sheet to let user choose UPI app
  Future<bool> _showUpiAppChooser(String upiUrl) async {
    try {
      final uri = Uri.parse(upiUrl);
      // Rebuild query to ensure proper encoding on Android deep links.
      // Some UPI apps are strict about encoding / path formats.
      final query = Uri(queryParameters: uri.queryParameters).query;

      // Build explicit UPI URLs for each app using the same payment params.
      final options = <_UpiAppOption>[
        _UpiAppOption(
          'BHIM',
          Uri.parse('bhim://upi/pay?$query'),
          icon: Icons.account_balance_wallet,
          color: const Color(0xFF008069),
        ),
        _UpiAppOption(
          'GPay',
          Uri.parse('gpay://upi/pay?$query'),
          icon: Icons.payments,
          color: const Color(0xFF4285F4),
        ),
        _UpiAppOption(
          'Paytm',
          // Paytm commonly expects paytmmp://pay?... (not paytmmp://upi/pay?...).
          Uri.parse('paytmmp://pay?$query'),
          icon: Icons.account_balance,
          color: const Color(0xFF00B9F1),
        ),
        _UpiAppOption(
          'PhonePe',
          // PhonePe commonly expects phonepe://pay?... (not phonepe://upi/pay?...).
          Uri.parse('phonepe://pay?$query'),
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF5F259F),
        ),
        _UpiAppOption(
          'WhatsApp',
          Uri.parse('whatsapp://send?text=$upiUrl'),
          icon: Icons.chat,
          color: const Color(0xFF25D366),
        ),
      ];

      final selected = await showModalBottomSheet<_UpiAppOption>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select your UPI app',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final option in options)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: option.color.withOpacity(0.1),
                      child: Icon(
                        option.icon,
                        color: option.color,
                      ),
                    ),
                    title: Text(option.name),
                    onTap: () => Navigator.of(ctx).pop(option),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

      if (selected == null) {
        return false;
      }

      // Android: open specific app directly (avoid chooser).
      // If it fails, we fall back to url_launcher behavior below.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        String? packageName;
        if (selected.name == 'BHIM') {
          packageName = 'in.org.npci.upiapp';
        } else if (selected.name == 'GPay') {
          packageName = 'com.google.android.apps.nbu.paisa.user';
        } else if (selected.name == 'WhatsApp') {
          packageName = 'com.whatsapp';
        }

        if (packageName != null) {
          try {
            await AndroidIntent(
              action: 'action_view',
              data: selected.uri.toString(),
              package: packageName,
            ).launch();
            return true;
          } catch (e) {
            _logger.w(
              '[MeonKYC] Android intent launch failed for ${selected.name} ($packageName): $e',
            );

            // WhatsApp Business fallback (if installed instead of personal).
            if (selected.name == 'WhatsApp') {
              try {
                await AndroidIntent(
                  action: 'action_view',
                  data: selected.uri.toString(),
                  package: 'com.whatsapp.w4b',
                ).launch();
                return true;
              } catch (e) {
                _logger.w('[MeonKYC] Android intent launch failed for WhatsApp Business: $e');
              }
            }
          }
        }
      }

      // Try to open the selected app; if it fails, fall back to the generic UPI URL.
      try {
        if (await canLaunchUrl(selected.uri)) {
          await launchUrl(selected.uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (e) {
        _logger.w('[MeonKYC] Failed to open selected UPI app (${selected.name}): $e');
      }

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (e) {
        _logger.w('[MeonKYC] Failed to open generic UPI URL: $e');
      }

      // If nothing could be opened, show a soft message but don't crash.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No supported UPI app found on this device. Please install a UPI app to complete payment.',
            ),
          ),
        );
      }

      return false;
    } catch (e) {
      _logger.e('[MeonKYC] Error in UPI app chooser: $e');
      return false;
    }
  }

  /// Handle external URL opening
  Future<bool> _handleExternalUrl(String url) async {
    try {
      _logger.i('[MeonKYC] Opening external URL: $url');

       // For generic UPI links, show an app chooser instead of auto navigation.
      if (url.startsWith('upi://')) {
        _logger.i('[MeonKYC] Detected UPI URL, showing app chooser');
        return _showUpiAppChooser(url);
      }

      // Google Pay special handling
      if (url.contains('gpay') || url.contains('tez') || url.contains('google.payments')) {
        final gpaySchemes = [
          url,
          url.replaceAll('gpay://', 'tez://'),
          url.replaceAll('tez://', 'gpay://'),
          url.replaceAll('google.payments://', 'gpay://'),
        ];

        for (final scheme in gpaySchemes) {
          try {
            final uri = Uri.parse(scheme);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return true;
            }
          } catch (e) {
            continue;
          }
        }
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('[MeonKYC] Error opening external URL: $e');
      return false;
    }
  }

  /// Check if URL should be handled externally
  bool _shouldHandleExternally(String url) {
    const externalSchemes = [
      'upi://',
      'paytmmp://',
      'phonepe://',
      'gpay://',
      'tez://',
      'google.payments://',
      'googlepay://',
      'bhim://',
      'tel:',
      'mailto:',
      'whatsapp://',
      'intent://',
    ];

    return externalSchemes.any((scheme) => url.startsWith(scheme));
  }

  /// Handle page started loading
  void _handlePageStarted(String url) {
    _logger.i('[MeonKYC] Page started: $url');
    setState(() {
      _webViewLoading = true;
      _currentUrl = url;
    });

    final isCurrentlyIpvStep = _checkIfIpvStep(url);

    if (isCurrentlyIpvStep && !_isIpvStep && widget.autoRequestPermissions) {
      _logger.i('[MeonKYC] IPV step detected');
      setState(() {
        _isIpvStep = true;
      });
      _requestPermissions();
    } else if (!isCurrentlyIpvStep && _isIpvStep) {
      setState(() {
        _isIpvStep = false;
      });
    }
  }

  /// Handle page finished loading
  Future<void> _handlePageFinished(String url) async {
    _logger.i('[MeonKYC] Page finished: $url');

    // On Android, custom schemes like upi://, gpay://, paytmmp:// etc. can trigger
    // a page finished event even though the WebView cannot actually render them.
    // In those cases we *only* want to handle them via the external URL logic and
    // must *not* inject any JavaScript, otherwise some devices can throw
    // MissingPluginException for evaluateJavascript after the internal WebView has
    // torn down its platform channel.
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _logger.i(
        '[MeonKYC] Skipping JS injection for non-HTTP(S) URL in onPageFinished: $url',
      );
      return;
    }
    setState(() {
      _webViewLoading = false;
      _webViewRendered = true;
    });

    // Check if can go back
    final canGoBack = await (_webViewController?.canGoBack() ?? Future.value(false));
    setState(() {
      _canGoBack = canGoBack;
    });

    if (_webViewController == null) return;

    // Everything below (auto-reload + JS injection) should be best-effort only.
    // On some Android devices the underlying platform view can be torn down
    // earlier, which would make evaluateJavascript throw a MissingPluginException.
    // We never want that to crash the host app, so we guard with try/catch.
    try {
      // For IPV / Face Finder, always reload the page once on the first
      // successful load so that getUserMedia picks up the latest permission
      // state (even if permissions were already granted earlier).
      final isIpvStep = _checkIfIpvStep(url);
      if (isIpvStep && !_hasReloadedAfterPermissions) {
        _hasReloadedAfterPermissions = true;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _logger.i('[MeonKYC] Auto-reloading IPV page after permissions granted');
            _webViewController?.reload();
          }
        });
      }

      // Inject JavaScript (channel shim, permissions, payment logging, success detection)
      const channelShim = '''
    (function() {
      try {
        if (!window.FlutterChannel && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.FlutterChannel = {
            postMessage: function(message) {
              window.flutter_inappwebview.callHandler('FlutterChannel', message);
            }
          };
        }
      } catch (e) {}
    })();
    ''';

      final permissionScript = _getPermissionInjectionScript();
      final paymentScript = _getPaymentHandlingScript();
      final successScript = _getSuccessDetectionScript();
      final layoutHintScript = _getLayoutHintScript();

      await _webViewController!.evaluateJavascript(source: channelShim);
      await _webViewController!.evaluateJavascript(source: permissionScript);
      if (widget.enablePayments) {
        await _webViewController!.evaluateJavascript(source: paymentScript);
      }
      await _webViewController!.evaluateJavascript(source: successScript);
      await _webViewController!.evaluateJavascript(source: layoutHintScript);

      // iOS/Android tweak for live.meon.co.in floating buttons
      if (uri.host.contains('live.meon.co.in')) {
        const fixFloatingButtonsJs = '''
      (function() {
        try {
          // Add extra bottom padding so content doesn't sit under the home indicator
          var existingPadding = parseInt(window.getComputedStyle(document.body).paddingBottom || '0', 10);
          if (existingPadding < 40) {
            document.body.style.paddingBottom = '40px';
          }

          // Nudge any fixed-bottom bars/buttons slightly above the very bottom
          var all = document.querySelectorAll('*');
          for (var i = 0; i < all.length; i++) {
            var el = all[i];
            var style = window.getComputedStyle(el);
            if (style.position === 'fixed') {
              // If it's pinned to bottom (or very close), lift it a bit
              if (style.bottom === '0px' || style.bottom === '1px' || style.bottom === '2px') {
                el.style.bottom = '20px';
              }
            }
          }
        } catch (e) {
          console.log('[MeonKYC] Error adjusting floating buttons:', e);
        }
      })();
      ''';

        await _webViewController!.evaluateJavascript(source: fixFloatingButtonsJs);
      }
    } catch (e, st) {
      _logger.w('[MeonKYC] Ignoring JS injection error in onPageFinished: $e\n$st');
    }
  }

  /// Handle web resource error
  void _handleWebResourceError(WebResourceError error) {
    _logger.e('[MeonKYC] WebView error: ${error.description}');

    // iOS: NSURLErrorDomain -999 = request cancelled (e.g., due to a reload or
    // navigation change). This is NOT a real failure and should be ignored,
    // otherwise we incorrectly show "Failed to load KYC page" while the flow
    // is still progressing (especially around Face Finder / IPV redirects).
    if (error.description.contains('NSURLErrorDomain error -999')) {
      setState(() {
        _webViewLoading = false;
      });
      return;
    }

    // Android: net::ERR_UNKNOWN_URL_SCHEME is expected for custom schemes like
    // upi://, gpay://, phonepe:// etc. We handle these via _handleExternalUrl
    // and the UPI app chooser, so they should NOT surface as a hard KYC error
    // in the UI.
    if (error.description.contains('net::ERR_UNKNOWN_URL_SCHEME')) {
      setState(() {
        _webViewLoading = false;
      });

      // Best-effort UX:
      // - Show a soft message (only snackbar)
      // - Try to go back to the previous HTTP(S) KYC page so that the user
      //   doesn't get stuck on a blank / error screen that WebView might show.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No supported UPI app found on this device. Please install a UPI app to complete payment.',
            ),
          ),
        );
      }

      _webViewController?.goBack();
      return;
    }

    // Android: net::ERR_NAME_NOT_RESOLVED can happen when the
    // network / DNS is flaky right as Face Finder or KYC pages are loading.
    // Instead of turning this into a hard "Failed to load KYC page" error or
    // trying to auto-reload (which can be fragile when the underlying WebView
    // is being recreated), we:
    //  - just show a soft snackbar
    //  - leave the current page as-is so the user can manually retry/back
    if (error.description.contains('net::ERR_NAME_NOT_RESOLVED')) {
      setState(() {
        _webViewLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Network issue detected. Retrying KYC page...',
            ),
          ),
        );
      }
      return;
    }

    const errorMsg = 'Failed to load KYC page';
    setState(() {
      _error = errorMsg;
      _webViewLoading = false;
    });
    widget.onError?.call(errorMsg);
  }

  /// Handle navigation requests
  // (Handled directly inside InAppWebView.shouldOverrideUrlLoading)

  /// Handle JavaScript messages
  void _handleJavaScriptMessage(String data) async {
    try {
      _logger.i('[MeonKYC] Message received: $data');

      dynamic parsedMessage;
      try {
        parsedMessage = json.decode(data);
      } catch (e) {
        parsedMessage = {'type': 'TEXT', 'data': data};
      }

      // Handle layout hints (e.g. whether to hide SDK header on firstdemat
      // landing screen with floating buttons)
      if (parsedMessage['type'] == 'LAYOUT_HINT') {
        final bool hide =
            parsedMessage['hideHeader'] == true ||
            parsedMessage['hideHeader'] == 'true';
        if (hide != _hideHeaderForCurrentPage) {
          setState(() {
            _hideHeaderForCurrentPage = hide;
          });
        }
        return;
      }

      // Handle KYC success message
      if (parsedMessage['type'] == 'KYC_SUCCESS' ||
          data.contains('SUCCESS')) {
        if (_successCalled) {
          _logger.i('[MeonKYC] Success already called, ignoring duplicate');
          return;
        }

        _successCalled = true;
        _logger.i('[MeonKYC] KYC completed successfully');

        // Perform logout before calling onSuccess
        try {
          _logger.i('[MeonKYC] Performing logout...');
          final logoutUrl = '${widget.baseURL}/${widget.companyName}/logout';

          final response = await http.get(Uri.parse(logoutUrl));

          if (response.statusCode == 200) {
            _logger.i('[MeonKYC] Logout successful: ${response.body}');
          } else {
            _logger.w('[MeonKYC] Logout failed with status: ${response.statusCode}');
          }
        } catch (e) {
          _logger.e('[MeonKYC] Error in logout: $e');
          // Continue even if logout fails
        }

        // Call onSuccess after logout
        widget.onSuccess?.call({
          'status': 'completed',
          'timestamp': parsedMessage['timestamp'] ?? DateTime.now().toIso8601String(),
          'url': parsedMessage['url'] ?? _currentUrl,
          'message': 'KYC process completed successfully',
        });
      }
      // Handle error messages
      else if (parsedMessage['type'] == 'KYC_ERROR' ||
          data.contains('ERROR')) {
        _logger.i('[MeonKYC] KYC error');
        widget.onError?.call(parsedMessage['message'] ?? data);
      }
    } catch (e) {
      _logger.e('[MeonKYC] Error handling message: $e');
    }
  }

  /// Handle close button
  void _handleClose() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close KYC'),
        content: const Text('Are you sure you want to close?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onClose?.call();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Handle refresh button
  void _handleRefresh() {
    _webViewController?.reload();
  }

  /// Render header
  Widget? _renderHeader() {
    if (!widget.showHeader) return null;

    final headerStyle = widget.customStyles?['header'] as BoxDecoration?;
    final titleStyle = widget.customStyles?['headerTitle'] as TextStyle?;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: headerStyle ??
            BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Left button (Back or Close)
            _buildHeaderButton(
              icon: _canGoBack && _webViewRendered ? '←' : '✕',
              onPressed: _canGoBack && _webViewRendered
                  ? () => _webViewController?.goBack()
                  : _handleClose,
            ),
            // Title
            Expanded(
              child: Text(
                _isIpvStep ? 'IPV Verification' : widget.headerTitle,
                style: titleStyle ??
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // Right buttons (Refresh and Close)
            Row(
              children: [
                _buildHeaderButton(
                  icon: '⟳',
                  onPressed: _handleRefresh,
                ),
                const SizedBox(width: 8),
                _buildHeaderButton(
                  icon: '✕',
                  onPressed: _handleClose,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build header button
  Widget _buildHeaderButton({required String icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: const BoxConstraints(minWidth: 36),
        child: Text(
          icon,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build loading screen
  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF0047AB),
            ),
            SizedBox(height: 16),
            Text(
              'Initializing KYC...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error screen
  Widget _buildErrorScreen() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _performInitialLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0047AB),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    final containerDecoration = widget.customStyles?['container'] as BoxDecoration?;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (_canGoBack && _webViewRendered) {
          _webViewController?.goBack();
        } else {
          // Don't pop, just return
          return;
        }
      },
      child: SafeArea(
        top: false, // header already handles top inset
        bottom: true,
        child: Container(
          decoration: containerDecoration ?? const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              if (widget.showHeader && !_hideHeaderForCurrentPage && _renderHeader() != null)
                _renderHeader()!,
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri('${widget.baseURL}/${widget.companyName}/${widget.workflow}'),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        useHybridComposition: true,
                        supportZoom: false,
                        allowFileAccess: true,
                        allowFileAccessFromFileURLs: true,
                        allowUniversalAccessFromFileURLs: true,
                        thirdPartyCookiesEnabled: true,
                        geolocationEnabled: true,
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        controller.addJavaScriptHandler(
                          handlerName: 'FlutterChannel',
                          callback: (args) {
                            if (args.isEmpty) return;
                            final data = args[0]?.toString() ?? '';
                            if (data.isEmpty) return;
                            _handleJavaScriptMessage(data);
                          },
                        );
                      },
                      onLoadStart: (controller, url) {
                        if (url != null) {
                          _handlePageStarted(url.toString());
                        }
                      },
                      onLoadStop: (controller, url) async {
                        if (url != null) {
                          await _handlePageFinished(url.toString());
                        }
                      },
                      onReceivedError: (controller, request, error) {
                        _handleWebResourceError(error);
                      },
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        final uri = navigationAction.request.url;
                        if (uri == null) return NavigationActionPolicy.ALLOW;
                        final url = uri.toString();
                        _logger.i('[MeonKYC] Navigation request: $url');

                        if (_shouldHandleExternally(url)) {
                          final handled = await _handleExternalUrl(url);
                          if (handled) {
                            return NavigationActionPolicy.CANCEL;
                          }
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                      onPermissionRequest: (controller, request) async {
                        _logger.i('[MeonKYC] Permission requested: ${request.resources}');
                        return PermissionResponse(
                          resources: request.resources,
                          action: PermissionResponseAction.GRANT,
                        );
                      },
                      onGeolocationPermissionsShowPrompt: (controller, origin) async {
                        _logger.i('[MeonKYC] Geolocation permission requested for: $origin');
                        final status = await Permission.location.status;
                        if (status.isGranted || status.isLimited) {
                          return GeolocationPermissionShowPromptResponse(
                            origin: origin,
                            allow: true,
                            retain: true,
                          );
                        }
                        final result = await Permission.location.request();
                        final allowed = result.isGranted || result.isLimited;
                        return GeolocationPermissionShowPromptResponse(
                          origin: origin,
                          allow: allowed,
                          retain: allowed,
                        );
                      },
                    ),
                    if (_webViewLoading)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.9),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0047AB),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legacy SDKCall widget for backward compatibility
@Deprecated('Use MeonKYC instead')
class SDKCall extends StatelessWidget {
  final String companyName;
  final String workflowName;

  const SDKCall({
    super.key,
    required this.companyName,
    required this.workflowName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeonKYC(
        companyName: companyName,
        workflow: workflowName,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
