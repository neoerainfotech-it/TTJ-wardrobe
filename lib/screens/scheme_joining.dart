import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'permission_access.dart';

const Color brandPurple = Color(0xFF5D189D);

class SchemeJoiningPage extends StatefulWidget {
  const SchemeJoiningPage({super.key});

  @override
  State<SchemeJoiningPage> createState() => _SchemeJoiningPageState();
}

class _SchemeJoiningPageState extends State<SchemeJoiningPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isAgeConfirmed = false;
  bool _isSessionLoading = true; 
  
  String _displayName = "Loading...";
  String _displayEmail = "Loading...";
  String _displayMobile = "Loading...";
  int? _activeUserId;

  final TextEditingController _doorController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _nomineeController = TextEditingController();

  String _selectedCity = "Select City";
  final String _defaultState = "Tamil Nadu";
  
  // Dropdown variables
  List<String> _showroomList = [];
  String? _selectedShowroom;
  bool _isLocationsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserSession();
    await _fetchShowrooms();
    setState(() => _isSessionLoading = false);
  }

  // Fetch Locations from your CMS API
  Future<void> _fetchShowrooms() async {
    try {
      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_showrooms.php"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          setState(() {
            _showroomList = List<String>.from(data['data']);
            _isLocationsLoading = false;
          });
        } else {
          setState(() {
             _showroomList = ["No locations found"];
             _isLocationsLoading = false;
          });
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      print("Error fetching showrooms: $e");
      setState(() {
        _showroomList = ["Error connecting to server"];
        _isLocationsLoading = false;
      });
    }
  }

  Future<void> _loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedUserId = prefs.getInt('user_id');
    String? savedEmail = prefs.getString('user_email');

    if (savedUserId != null && savedEmail != null) {
      setState(() {
        _activeUserId = savedUserId;
        _displayName = prefs.getString('user_name') ?? "Customer Name";
        _displayEmail = savedEmail;
        _displayMobile = prefs.getString('user_mobile') ?? "Not available";
      });
      return;
    }
    if (savedEmail != null) {
      await _fetchUserFromServer(savedEmail);
    }
  }

  Future<void> _fetchUserFromServer(String email) async {
    try {
      var response = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_user_by_email.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body.trim());
        if (data['status'] == 'success') {
          setState(() {
            _activeUserId = data['user_id'];
            _displayName = data['name'] ?? "Customer";
            _displayEmail = data['email'];
            _displayMobile = data['mobile'] ?? "Not available";
          });
        }
      }
    } catch (_) {}
  }

  // 🚀 UPDATED SUBMIT FUNCTION: Saves to database FIRST
  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate() && _isAgeConfirmed) {
      if (_selectedShowroom == null) {
        _showMessage("Please select a showroom", Colors.red);
        return;
      }

      setState(() => _isLoading = true); // Turn on loading spinner

      Map<String, dynamic> initialSchemeData = {
        "user_id": _activeUserId,
        "name": _displayName,
        "email": _displayEmail,
        "mobile": _displayMobile,
        "door_no": _doorController.text.trim(),
        "street": _streetController.text.trim(),
        "area": _areaController.text.trim(),
        "pin_code": _pinController.text.trim(),
        "city": _selectedCity,
        "state": _defaultState,
        "nominee_name": _nomineeController.text.trim(),
        "nearest_showroom": _selectedShowroom, 
      };

      try {
        // 1. Send data to your server
        final response = await http.post(
          Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/save_enrollment.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(initialSchemeData),
        );

        final result = jsonDecode(response.body);

        // 2. Check if database saved it successfully
        if (response.statusCode == 200 && result['status'] == 'success') {
          if (!mounted) return;
          // 3. Move to next screen ONLY if saved
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => PermissionAccessScreen(schemeData: initialSchemeData)
            )
          );
        } else {
          _showMessage("Database Error: ${result['message']}", Colors.red);
        }
      } catch (e) {
        _showMessage("Error: $e", Colors.red);
      } finally {
        if (mounted) setState(() => _isLoading = false); // Turn off loading spinner
      }

    } else if (!_isAgeConfirmed) {
      _showMessage("Please confirm your age", brandPurple);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _onPinChanged(String value) {
    if (value.length == 6) {
      setState(() {
        if (value.startsWith('641')) {
          _selectedCity = "Coimbatore";
        } else if (value.startsWith('600')) {
          _selectedCity = "Chennai";
        } else {
          _selectedCity = "Other";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSessionLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: brandPurple)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Scheme Joining", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    _buildStaticRow("Name", _displayName),
                    const Divider(),
                    _buildStaticRow("Mobile", _displayMobile),
                    const Divider(),
                    _buildStaticRow("Email", _displayEmail),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const Text("Personal Address", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandPurple)),
              const SizedBox(height: 20),
              
              // Address Fields Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    _buildInputField(_doorController, "Door No.", "Enter door number", true),
                    const Divider(),
                    _buildInputField(_streetController, "Street", "Enter street name", true),
                    const Divider(),
                    _buildInputField(_areaController, "Area / Locality", "Enter area", false),
                    const Divider(),
                    _buildInputField(_pinController, "PIN Code", "6-digit code", true, isNumeric: true, isPin: true, onChanged: _onPinChanged),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // City/Showroom Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStaticRow("City", _selectedCity, isRequired: true),
                    const Divider(),
                    _buildStaticRow("State", _defaultState, isRequired: true),
                    const Divider(),
                    _buildInputField(_nomineeController, "Nominee Name", "Enter nominee name", true),
                    const Divider(),
                    
                    // DROPDOWN SECTION
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text("Nearest Showroom *", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    _isLocationsLoading 
                      ? const LinearProgressIndicator(color: brandPurple)
                      : DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: const Text("Select Showroom", style: TextStyle(fontSize: 14)),
                          value: _selectedShowroom,
                          decoration: const InputDecoration(border: InputBorder.none),
                          items: _showroomList.map((String loc) {
                            return DropdownMenuItem(value: loc, child: Text(loc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedShowroom = val),
                          validator: (v) => v == null ? "Required" : null,
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Age Confirmation
              Row(
                children: [
                  Checkbox(
                    value: _isAgeConfirmed,
                    activeColor: brandPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() => _isAgeConfirmed = v!),
                  ),
                  const Expanded(child: Text("I confirm that I am over 18 years of age", style: TextStyle(fontSize: 13, color: Colors.black54))),
                ],
              ),
              const SizedBox(height: 25),
              
              // 🚀 UPDATED CONTINUE BUTTON with Loading State
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(backgroundColor: brandPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("CONTINUE", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, String hint, bool isRequired, {bool isNumeric = false, bool isPin = false, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            children: isRequired ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLength: isPin ? 6 : null,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, counterText: ""),
          validator: (v) => (isRequired && (v == null || v.isEmpty)) ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildStaticRow(String label, String value, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
              children: isRequired ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}