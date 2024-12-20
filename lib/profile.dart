import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'package:spa/SPAUserModel.dart';
import 'package:spa/logToFile.dart';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io'; // Required to check platform
import 'package:spa/main.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:math';
import 'package:spa/order_api.dart';
import 'package:spa/api_services.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key});

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late Razorpay _razorpay;
  bool _isSaving = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _udiseController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _talukaController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _principalNameController =
      TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _deviceId;
  int? _Id;
  // Date formatter
  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay(); // Initialize Razorpay
    _loadProfile();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear(); // Dispose Razorpay when not needed
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      List<Map<String, dynamic>> rows =
          await DatabaseHelper.instance.getProfiles();
      if (rows.isNotEmpty && rows.isNotEmpty) {
        // Assuming there's only one profile to load (as the profile form is for a single profile)
        var row = rows.first;
        _Id = row['id'] ?? '';
        // Set values from the database to the controllers
        _schoolNameController.text = row['schoolName'] ?? '';
        _udiseController.text = row['udiseCode'] ?? '';
        _cityController.text = row['city'] ?? '';
        _talukaController.text = row['taluka'] ?? '';
        _districtController.text = row['district'] ?? '';
        _principalNameController.text = row['principalName'] ?? '';
        _mobileController.text = row['mobileNumber'] ?? '';
        _emailController.text = row['email'] ?? '';
        _startDateController.text = row['startDate'] ?? '';
        _endDateController.text = row['endDate'] ?? '';

        // Optionally, you could convert the date strings back to DateTime objects
        if (row['startDate'] != null) {
          _startDate = DateFormat('yyyy-MM-dd').parse(row['startDate']);
        }
        if (row['endDate'] != null) {
          _endDate = DateFormat('yyyy-MM-dd').parse(row['endDate']);
        }
        print(rows);
      } else {
        // If no data, clear fields
        clearFields();
      }
    } catch (error) {
      logMessage("Failed to load Profile: $error");
    }
  }

  void clearFields() {
    // List of controllers
    final List<TextEditingController> controllers = [
      _schoolNameController,
      _udiseController,
      _cityController,
      _talukaController,
      _districtController,
      _principalNameController,
      _mobileController,
      _emailController,
      _startDateController,
      _endDateController,
    ];

    // Loop through each controller and clear the text
    for (var controller in controllers) {
      controller.clear();
    }

    // Optionally, clear the date fields
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = _formatDate(picked);
        } else {
          _endDate = picked;
          _endDateController.text = _formatDate(picked);
        }
      });
    }
  }

  Future<bool> _saveSPAUser() async {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        // logMessage("start deviceid lookup");
        _deviceId = await _getDeviceId();

        SPAUserModel user = SPAUserModel(
          deviceid: _deviceId,
          email: _emailController.text,
          mobile: _mobileController.text,
          active: false,
          finyearstartdate: _startDateController.text,
          finyearenddate: _endDateController.text,
        );

        // Call the ApiServices saveSPAUserModel function with the user object
        ApiServices apiServices = ApiServices();
        SPAUserModel? result = await apiServices.saveSPAUserModel(user);

        // Check if the user was saved successfully
        if (result != null) {
          logMessage("SPA user created successfully!");
          return true;
        } else {
          logMessage("Failed to save SPA user");
          return false;
        }
      }
      return false;
    } catch (error) {
      logMessage("Failed to save SPA Profile: $error");
    }
    return false;
  }

  Future<bool> _updateSPAUser(
      String? paymentId, String? orderId, String? signature) async {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        SPAUserModel user = SPAUserModel(
            deviceid: _deviceId,
            email: _emailController.text,
            mobile: _mobileController.text,
            active: true,
            finyearstartdate: _startDateController.text,
            finyearenddate: _endDateController.text,
            paymentId: paymentId,
            orderId: orderId,
            signature: signature);

        // Call the ApiServices saveSPAUserModel function with the user object
        ApiServices apiServices = ApiServices();
        SPAUserModel? result = await apiServices.saveSPAUserModel(user);

        // Check if the user was saved successfully
        if (result != null) {
          logMessage("SPA user updated successfully!");
          return true;
        } else {
          logMessage("Failed to update SPA user");
          return false;
        }
      }
      return false;
    } catch (error) {
      logMessage("Failed to update SPA Profile: $error");
    }
    return false;
  }

  Future<void> _submitProfile(bool isOnline) async {
    List<Map<String, dynamic>> records = [];

    if (_formKey.currentState?.validate() ?? false) {
      try {
        setState(() {
          _isSaving = true; // Show loading indicator
        }); //Prepare data to insert
        records.add({
          'schoolName': sanitizeHtml(sanitizeInput(_schoolNameController.text)),
          'udiseCode': _udiseController.text,
          'city': sanitizeHtml(sanitizeInput(_cityController.text)),
          'taluka': _talukaController.text,
          'district': _districtController.text,
          'principalName': _principalNameController.text,
          'mobileNumber': _mobileController.text,
          'email': _emailController.text,
          'startDate': _startDateController.text,
          'endDate': _endDateController.text,
          'isOnline': isOnline
        });

        // Insert data into the database
        var profile = await DatabaseHelper.instance.insertProfile(records);
        bool isPaymentPending =
            profile.any((record) => record['paymentId'] == null);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile created successfully'),
            action: isPaymentPending
                ? SnackBarAction(
                    label: 'Payment',
                    onPressed: _showRazorpayPayment, // Trigger Razorpay payment
                  )
                : null, // Disable the action if paymentId is not null
          ),
        );
      } catch (error) {
        logMessage('Failed to save profile: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $error')),
        );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors')),
      );
    }
  }

// Razorpay payment handlers
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _updateProfilePayment(
        response.paymentId, response.orderId, response.signature);
    _updateSPAUser(response.paymentId, response.orderId, response.signature);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment successful!')),
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => HomeScreen(),
    ));
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    String errorMessage = response.code == Razorpay.PAYMENT_CANCELLED
        ? 'Payment canceled by user'
        : 'Payment failed: ${response.message}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

//signature = hmac_sha256(order_id + "|" + payment_id, secret_key)

  Future<String> createOrder(int amount) async {
    String orderID = await OrderAPI.generateOrderID(amount);
    return orderID;
  }

  Future<void> _showRazorpayPayment() async {
    int amount = OrderAPI.amount;
    String orderId = await createOrder(amount);
    if (orderId.isNotEmpty) {
      var options = await OrderAPI.getRazorpayOptions(orderId);
      try {
        _razorpay.open(options);
      } catch (e) {
        logMessage('Error opening Razorpay: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening payment gateway: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ID not generated: $e')),
      );
    }
  }

  Future<void> _updateProfilePayment(
      String? paymentId, String? orderId, String? signature) async {
    List<Map<String, dynamic>> records = [];

    if (_formKey.currentState?.validate() ?? false) {
      try {
        setState(() {
          _isSaving = true; // Show loading indicator
        }); //Prepare data to insert
        records.add({
          'schoolName': sanitizeHtml(sanitizeInput(_schoolNameController.text)),
          'udiseCode': _udiseController.text,
          'city': sanitizeHtml(sanitizeInput(_cityController.text)),
          'taluka': _talukaController.text,
          'district': _districtController.text,
          'principalName': _principalNameController.text,
          'mobileNumber': _mobileController.text,
          'email': _emailController.text,
          'startDate': _startDateController.text,
          'endDate': _endDateController.text,
          'paymentId': paymentId,
          'orderId': orderId,
          'signature': signature
        });

        // Insert data into the database
        await DatabaseHelper.instance.insertProfile(records);
      } catch (e) {
        logMessage("Failed to update payment details:: $e");
      }
    }
  }

  String sanitizeHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim(); // Removes all HTML tags
  }

  String sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'[^\u0900-\u097F\u0000-\u007F ]'), '')
        .trim();
  }

  Future<String?> _getDeviceId() async {
    try {
      var deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        // iOS-specific code
        var iosDeviceInfo = await deviceInfo.iosInfo;
        return iosDeviceInfo.identifierForVendor; // Unique ID on iOS
      } else if (Platform.isAndroid) {
        // Android-specific code
        var androidDeviceInfo = await deviceInfo.androidInfo;
        return const AndroidId().getId(); // Unique ID on Android
      }
      return null; // Return null if neither Android nor iOS
    } catch (e) {
      logMessage("Failed to get device ID:: $e");
    }

    return null; // Return an empty string if unable to fetch the ID
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  _schoolNameController,
                  'शाळेचे नाव',
                  allowEnglishAndMarathi: true,
                ),
                _buildTextField(_udiseController, 'शाळेचा UDISE क्रमांक'),
                _buildTextField(
                  _cityController,
                  'गाव / शहर',
                  allowEnglishAndMarathi: true,
                ),
                _buildTextField(_talukaController, 'तालुका'),
                _buildTextField(_districtController, 'जिल्हा'),
                _buildTextField(
                    _principalNameController, 'मुख्याध्यापकांचे नाव'),
                _buildTextField(_mobileController, 'मोबाईल क्रमांक',
                    keyboardType: TextInputType.phone, isMobile: true),
                _buildTextField(_emailController, 'ई-मेल आय डी',
                    keyboardType: TextInputType.emailAddress, isEmail: true),

                // Date Pickers for Start and End Dates
                _buildDatePicker(
                    'आर्थिक वर्ष सुरु दिनांक', _startDateController,
                    isStartDate: true),
                _buildDatePicker('आर्थिक वर्ष अखेर दिनांक', _endDateController,
                    isStartDate: false),

                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      bool isSaved = await _saveSPAUser();
                      if (isSaved) {
                        _submitProfile(isSaved);
                      } else {
                        logMessage(
                            "User data was not saved. Please try again.");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'सबमिट',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      {TextInputType keyboardType = TextInputType.text,
      bool isMobile = false,
      bool isEmail = false,
      bool allowEnglishAndMarathi = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$labelText आवश्यक आहे';
          }
          if (isMobile && !RegExp(r'^\d{10}$').hasMatch(value)) {
            return 'कृपया वैध 10-अंकी मोबाईल क्रमांक प्रविष्ट करा';
          }
          if (isEmail &&
              !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                  .hasMatch(value)) {
            return 'कृपया वैध ई-मेल आय डी प्रविष्ट करा';
          }
          if (allowEnglishAndMarathi &&
              !RegExp(r'^[\u0900-\u097F\u0000-\u007F ]+$').hasMatch(value)) {
            return 'फक्त इंग्रजी आणि मराठी अक्षरे स्वीकारली जातात';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePicker(String labelText, TextEditingController controller,
      {required bool isStartDate}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () => _selectDate(context, isStartDate),
        child: AbsorbPointer(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '$labelText आवश्यक आहे';
              }
              if (!isStartDate &&
                  _startDate != null &&
                  _endDate != null &&
                  _endDate!.isBefore(_startDate!)) {
                return 'अखेर दिनांक सुरु दिनांकानंतर असावा';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
