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
      title: 'Meon KYC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
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
        title: const Text('Meon KYC Example'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Meon KYC Integration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete your verification process',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const KYCScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('Start Individual KYC'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const KYCScreen(workflow: 'business'),
                  ),
                );
              },
              icon: const Icon(Icons.business),
              label: const Text('Start Business KYC'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SsoKycFormScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.phonelink_lock),
              label: const Text('Start SSO KYC'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KYCScreen extends StatelessWidget {
  final String workflow;
  final String? mobileNumber;
  final String? secretKey;
  final String? redirectUrl;

  const KYCScreen({
    Key? key,
    this.workflow = 'individual',
    this.mobileNumber,
    this.secretKey,
    this.redirectUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeonKYC(
        // Required parameter - replace with your company name
        companyName: 'demo-company',
        
        // Workflow type - can be 'individual', 'business', etc.
        workflow: workflow,

        // Optional SSO fields — omit these to keep the original KYC URL flow
        mobileNumber: mobileNumber,
        secretKey: secretKey,
        redirectUrl: redirectUrl,
        
        // Enable IPV (In-Person Verification) features
        enableIPV: true,
        
        // Enable payment link handling
        enablePayments: true,
        
        // Auto-request permissions when IPV step is detected
        autoRequestPermissions: true,
        
        // Show custom header with navigation controls
        showHeader: true,
        
        // Custom header title
        headerTitle: 'Complete Your KYC',
        
        // Base URL for KYC service (use your custom domain if needed)
        baseURL: 'https://live.meon.co.in',
        
        // Success callback - called when KYC is completed
        onSuccess: (data) {
          debugPrint('KYC Success: $data');
          
          // Show success dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              title: const Text('KYC Completed!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Status: ${data['status']}'),
                  const SizedBox(height: 8),
                  Text(
                    'Completed at: ${data['timestamp']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close KYC screen
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
        
        // Error callback - called when an error occurs
        onError: (error) {
          debugPrint('KYC Error: $error');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        },
        
        // Close callback - called when user closes the KYC screen
        onClose: () {
          debugPrint('KYC Closed by user');
          Navigator.of(context).pop();
        },
        
        // Optional: Custom styles
        customStyles: {
          'header': const BoxDecoration(
            color: Colors.blue,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          'headerTitle': const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        },
      ),
    );
  }
}

class SsoKycFormScreen extends StatefulWidget {
  const SsoKycFormScreen({Key? key}) : super(key: key);

  @override
  State<SsoKycFormScreen> createState() => _SsoKycFormScreenState();
}

class _SsoKycFormScreenState extends State<SsoKycFormScreen> {
  final _mobileController = TextEditingController();
  final _secretController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _startSsoKyc() {
    final mobile = _mobileController.text.trim();
    final secret = _secretController.text.trim();

    if (mobile.isEmpty || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter mobile number and secret key'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KYCScreen(
          mobileNumber: mobile,
          secretKey: secret,
          redirectUrl: 'https://www.google.com',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSO KYC'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '9411441937',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Secret key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startSsoKyc,
              child: const Text('Start SSO KYC'),
            ),
          ],
        ),
      ),
    );
  }
}

