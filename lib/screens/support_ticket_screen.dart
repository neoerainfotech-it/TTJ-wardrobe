import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Needed for Web check
import 'package:image_picker/image_picker.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final Color brandPurple = const Color(0xFF5D1F88);
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  XFile? _selectedImage; // Changed to XFile for Web compatibility
  bool _isLoading = false;
  List<dynamic> _myTickets = [];

  @override
  void initState() {
    super.initState();
    _fetchMyTickets();
  }

  // Pick Image from Gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  // Fetch past tickets
  Future<void> _fetchMyTickets() async {
    final prefs = await SharedPreferences.getInstance();
    
    // FIX: Safely get user_id whether it was saved as an int or String
    String? userId = prefs.get('user_id')?.toString();

    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_tickets.php?user_id=$userId"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _myTickets = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching tickets: $e");
    }
  }

  // Submit Ticket with Image and User Details
  Future<void> _submitTicket() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and Description are required.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    
    // FIX: Safely get user_id
    String userId = prefs.get('user_id')?.toString() ?? '';
    String userName = prefs.getString('user_name') ?? prefs.getString('first_name') ?? 'Unknown User';
    String userEmail = prefs.getString('user_email') ?? prefs.getString('email') ?? 'No Email';
    String userMobile = prefs.getString('mobile') ?? 'No Mobile';

    try {
      var uri = Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/create_ticket.php");
      var request = http.MultipartRequest('POST', uri);

      request.fields['user_id'] = userId;
      request.fields['user_name'] = userName;
      request.fields['user_email'] = userEmail;
      request.fields['user_mobile'] = userMobile;
      request.fields['subject'] = _subjectController.text;
      request.fields['message'] = _messageController.text;

      // FIX: Handle Web vs Mobile File Upload
      if (_selectedImage != null) {
        if (kIsWeb) {
          // On Web, we must upload bytes
          request.files.add(
            http.MultipartFile.fromBytes(
              'attachment',
              await _selectedImage!.readAsBytes(),
              filename: _selectedImage!.name,
            ),
          );
        } else {
          // On Mobile, we can upload directly from the file path
          request.files.add(
            await http.MultipartFile.fromPath('attachment', _selectedImage!.path),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _subjectController.clear();
        _messageController.clear();
        setState(() {
          _selectedImage = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket raised successfully!'), backgroundColor: Colors.green),
          );
        }
        _fetchMyTickets();
      } else {
        throw Exception(data['message'] ?? "Failed to raise ticket");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Help & Support", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: TabBar(
            labelColor: brandPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: brandPurple,
            tabs: const [
              Tab(text: "Raise Ticket"),
              Tab(text: "My Tickets"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Raise a new ticket
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Describe your issue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text("Provide as much detail as possible so our team can help you quickly.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: "Subject / Category",
                      hintText: "e.g., Payment Failure, App Crash",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.label_outline, color: brandPurple),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: "Detailed Explanation",
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text("Attachments (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _selectedImage == null
                      ? InkWell(
                          onTap: _pickImage,
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload_outlined, color: brandPurple, size: 30),
                                const SizedBox(height: 5),
                                const Text("Tap to upload a screenshot"),
                              ],
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              // FIX: Use Image.network for Web, Image.file for Mobile
                              child: kIsWeb
                                  ? Image.network(_selectedImage!.path, height: 150, width: double.infinity, fit: BoxFit.cover)
                                  : Image.file(File(_selectedImage!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: InkWell(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            )
                          ],
                        ),

                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _submitTicket,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Submit Ticket", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),

            // TAB 2: View past tickets
            _myTickets.isEmpty
                ? const Center(child: Text("You have no active tickets."))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myTickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _myTickets[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      ticket['subject'] ?? 'No Subject',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      ticket['status'] ?? 'Open',
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                    backgroundColor: ticket['status'] == 'Resolved' || ticket['status'] == 'Closed'
                                        ? Colors.green
                                        : Colors.orange,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(ticket['message'] ?? '', style: const TextStyle(color: Colors.black87)),
                              
                              if (ticket['attachment'] != null && ticket['attachment'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.attachment, size: 16, color: Colors.blue),
                                      const SizedBox(width: 5),
                                      Text("Screenshot Attached", style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                                    ],
                                  ),
                                ),

                              const Divider(height: 20),
                              if (ticket['admin_reply'] != null && ticket['admin_reply'].toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.admin_panel_settings, color: brandPurple, size: 16),
                                          const SizedBox(width: 5),
                                          const Text("Admin Reply", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(ticket['admin_reply'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    ],
                                  ),
                                )
                              else
                                const Text("Awaiting admin reply...", style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}