import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'aadhar_upload.dart';

class PermissionAccessScreen extends StatefulWidget {
  final Map<String, dynamic> schemeData;

  const PermissionAccessScreen({super.key, required this.schemeData});

  @override
  State<PermissionAccessScreen> createState() => _PermissionAccessScreenState();
}

class _PermissionAccessScreenState extends State<PermissionAccessScreen> with WidgetsBindingObserver {
  final Color brandPurple = const Color(0xFF5D1F88);

  // Only Camera & Location need explicit OS permission checks
  Map<Permission, PermissionStatus> _statuses = {
    Permission.camera: PermissionStatus.denied,
    Permission.location: PermissionStatus.denied,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialStatuses();
    }
  }

  Future<void> _checkInitialStatuses() async {
    // Desktop or Web bypass
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      setState(() {
        _statuses = {
          Permission.camera: PermissionStatus.granted,
          Permission.location: PermissionStatus.granted,
        };
      });
      return;
    }

    Map<Permission, PermissionStatus> updatedStatuses = {
      Permission.camera: await Permission.camera.status,
      Permission.location: await Permission.location.status,
    };

    if (mounted) {
      setState(() => _statuses = updatedStatuses);
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    PermissionStatus status;

    if (permission == Permission.location) {
      status = await Permission.locationWhenInUse.request();
    } else {
      status = await permission.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog();
      }
    }

    _checkInitialStatuses();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text("This permission is required to proceed. Please enable it in your device settings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("OPEN SETTINGS"),
          ),
        ],
      ),
    );
  }

  bool _allPermissionsGranted() {
    return _statuses.values.every((status) => status.isGranted || status.isLimited);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "App Permissions",
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Allow Access",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: brandPurple),
              ),
              const SizedBox(height: 10),
              const Text(
                "To provide the best experience, we need the following permissions:",
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),

              const SizedBox(height: 30),

              // 1. Camera Tile
              _permissionTile(
                icon: Icons.camera_alt_outlined,
                title: "Camera",
                subtitle: "Required for profile photos and scanning documents.",
                permission: Permission.camera,
              ),

              // 2. Location Tile
              _permissionTile(
                icon: Icons.location_on_outlined,
                title: "Location",
                subtitle: "To find nearby showrooms automatically.",
                permission: Permission.location,
              ),

              const SizedBox(height: 40),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _allPermissionsGranted()
                      ? () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AadharUploadPage(schemeData: widget.schemeData),
                            ),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text(
                    "CONTINUE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Permission permission,
  }) {
    PermissionStatus status = _statuses[permission] ?? PermissionStatus.denied;
    bool isGranted = status.isGranted || status.isLimited;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isGranted ? Colors.green.withOpacity(0.3) : Colors.transparent),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isGranted ? Colors.green.withOpacity(0.1) : brandPurple.withOpacity(0.1),
            child: Icon(icon, color: isGranted ? Colors.green : brandPurple),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: isGranted,
            activeThumbColor: brandPurple,
            activeTrackColor: brandPurple.withOpacity(0.4),
            onChanged: isGranted ? null : (val) => _requestPermission(permission),
          ),
        ],
      ),
    );
  }
}