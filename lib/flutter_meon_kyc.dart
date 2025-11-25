import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  late WebViewController _webViewController;
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

  /// Initialize WebView controller
  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onWebResourceError: _handleWebResourceError,
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..loadRequest(Uri.parse('${widget.baseURL}/${widget.companyName}/${widget.workflow}'));
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
        _webViewController.reload();
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
                _webViewController.goBack();
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

  /// Handle external URL opening
  Future<bool> _handleExternalUrl(String url) async {
    try {
      _logger.i('[MeonKYC] Opening external URL: $url');

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
  void _handlePageFinished(String url) async {
    _logger.i('[MeonKYC] Page finished: $url');
    setState(() {
      _webViewLoading = false;
      _webViewRendered = true;
    });

    // Check if can go back
    final canGoBack = await _webViewController.canGoBack();
    setState(() {
      _canGoBack = canGoBack;
    });

    // Inject JavaScript
    final permissionScript = _getPermissionInjectionScript();
    final paymentScript = _getPaymentHandlingScript();
    final successScript = _getSuccessDetectionScript();

    await _webViewController.runJavaScript(permissionScript);
    if (widget.enablePayments) {
      await _webViewController.runJavaScript(paymentScript);
    }
    await _webViewController.runJavaScript(successScript);
  }

  /// Handle web resource error
  void _handleWebResourceError(WebResourceError error) {
    _logger.e('[MeonKYC] WebView error: ${error.description}');

    // Ignore unknown URL scheme errors (for payment links)
    if (error.errorCode == -10 && error.description.contains('net::ERR_UNKNOWN_URL_SCHEME')) {
      setState(() {
        _webViewLoading = false;
      });
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
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    _logger.i('[MeonKYC] Navigation request: ${request.url}');

    if (_shouldHandleExternally(request.url)) {
      _handleExternalUrl(request.url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  /// Handle JavaScript messages
  void _handleJavaScriptMessage(JavaScriptMessage message) async {
    try {
      final data = message.message;
      _logger.i('[MeonKYC] Message received: $data');

      dynamic parsedMessage;
      try {
        parsedMessage = json.decode(data);
      } catch (e) {
        parsedMessage = {'type': 'TEXT', 'data': data};
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
    _webViewController.reload();
  }

  /// Render header
  Widget? _renderHeader() {
    if (!widget.showHeader) return null;

    final headerStyle = widget.customStyles?['header'] as BoxDecoration?;
    final titleStyle = widget.customStyles?['headerTitle'] as TextStyle?;

    return Container(
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
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Left button (Back or Close)
            _buildHeaderButton(
              icon: _canGoBack && _webViewRendered ? '←' : '✕',
              onPressed: _canGoBack && _webViewRendered
                  ? () => _webViewController.goBack()
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
          _webViewController.goBack();
        } else {
          // Don't pop, just return
          return;
        }
      },
      child: Container(
        decoration: containerDecoration ?? const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            if (_renderHeader() != null) _renderHeader()!,
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _webViewController),
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
