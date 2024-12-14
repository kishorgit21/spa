import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'database_helper.dart';
import 'package:spa/logToFile.dart';

class AttendanceForm extends StatefulWidget {
  const AttendanceForm({super.key});

  @override
  _AttendanceFormState createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<AttendanceForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime selectedDate = DateTime.now();
  String selectedDay = '';
  final TextEditingController boysController = TextEditingController();
  final TextEditingController girlsController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final TextEditingController selectedDayController = TextEditingController();
  Map<String, dynamic>? selectedItem;
  String? dropdownValue;
  List<Map<String, dynamic>> _items = [];
  final List<String> classes = ['१ ते ५', '६ ते ८']; // Class options
  String? selectedClass; // Variable to store selected class

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('mr_IN');
    _setInitialDateAndDay();
    _loadItems();
  }

  void _setInitialDateAndDay() {
    selectedDayController.text =
        DateFormat('EEEE', 'mr_IN').format(selectedDate);
  }

  @override
  void dispose() {
    selectedDayController.dispose();
    boysController.dispose();
    girlsController.dispose();
    totalController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedDayController.text = DateFormat('EEEE', 'mr_IN').format(picked);
        _clearForm();
      });
    }
  }

  void _updateTotal(String value) {
    final int boys = int.tryParse(boysController.text) ?? 0;
    final int girls = int.tryParse(girlsController.text) ?? 0;
    totalController.text = (boys + girls).toString();
  }

  Future<void> _loadItems() async {
    List<Map<String, dynamic>> items =
        await DatabaseHelper.instance.getElements();
    setState(() {
      _items = items.skip(1).take(8).toList();
    });
  }

  Future<void> _submitForm() async {
    try {
      List<Map<String, dynamic>> records = [];
      if (_formKey.currentState?.validate() ?? false) {
        // Prepare data to insert
        records.add({
          'date': DateFormat('dd-MM-yyyy').format(selectedDate),
          'day': selectedDayController.text,
          'class': selectedClass,
          'boys': int.tryParse(boysController.text) ?? 0,
          'girls': int.tryParse(girlsController.text) ?? 0,
          'total': int.tryParse(totalController.text) ?? 0,
          'itemid': selectedItem?['itemid'] ?? 0,
          'name': selectedItem?['name'] ?? '',
          'created_date':
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
        });

        // Insert data into the database
        await DatabaseHelper.instance.insertAttendance(records);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("'Data saved successfully'"),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        await checkInsertedData();
        _clearForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please correct the errors')),
        );
      }
    } catch (error) {
      logMessage("Failed to save the Attendance Form: $error");
    }
  }

  Future<void> checkInsertedData() async {
    List<Map<String, dynamic>> rows =
        await DatabaseHelper.instance.getAllAttendance();
    print(rows);
  }

// Clear the form fields after successful submission
  void _clearForm() {
    setState(() {
      boysController.clear();
      girlsController.clear();
      totalController.clear();
      dropdownValue = null;
      selectedItem = null;
    });
  }

  Future<void> _getAttendance(selectedDate, selectedDay, selectedClass) async {
    try {
      List<Map<String, dynamic>> rows = await DatabaseHelper.instance
          .getAttendance(selectedDate, selectedDay, selectedClass);

      if (rows.isNotEmpty && rows.isNotEmpty) {
        final attendanceData = rows.first;
        setState(() {
          boysController.text = attendanceData['boys'].toString();
          girlsController.text = attendanceData['girls'].toString();
          totalController.text = attendanceData['total'].toString();
          selectedItem = {
            'itemid': attendanceData['itemid'],
            'name': attendanceData['name']
          };
          dropdownValue =
              attendanceData['name']; // Set the dropdown value directly
        });
      } else {
        _clearForm();
      }
    } catch (error) {
      logMessage("Failed to view the Attendance Form: $error");
    }
  }

  Future<bool> _checkPerStudentConfiguration(String? selectedClass) async {
    try {
      if (selectedClass == null || selectedClass.isEmpty) return false;
      List<Map<String, dynamic>> rows = await DatabaseHelper.instance
          .getRiceGrainsPerStudentRecord(selectedClass);
      if (rows.isNotEmpty) {
        return true;
      }
    } catch (error) {
      logMessage("Failed to get RiceGrainsPerStudentForm: $error");
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('दैनिक उपस्थिती नोंदवा')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align left
              children: [
                Row(
                  children: [
                    const Text(
                      'आजचा दिनांक:',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText:
                                  DateFormat('dd-MM-yyyy').format(selectedDate),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'आजचा वार:',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        controller: selectedDayController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                // Dropdown for Class Selection
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: selectedClass,
                    onChanged: (newValue) async {
                      setState(() {
                        selectedClass = newValue;
                      });

                      // Simulate a check for per-student configuration
                      bool isConfigured =
                          await _checkPerStudentConfiguration(selectedClass);

                      if (!isConfigured) {
                        _clearForm();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Per-student configuration not found for class $selectedClass'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Continue if configuration is present
                      _getAttendance(
                        DateFormat('dd-MM-yyyy').format(selectedDate),
                        selectedDayController.text,
                        selectedClass,
                      );
                    },
                    items:
                        classes.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child:
                            Text(value, style: const TextStyle(fontSize: 18)),
                      );
                    }).toList(),
                    decoration: const InputDecoration(
                      labelText: 'वर्ग',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null
                        ? 'कृपया वर्ग निवडा'
                        : null, // Add validator here
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(boysController, 'उपस्थिती (मुले)'),
                const SizedBox(height: 16),
                _buildTextField(girlsController, 'उपस्थिती (मुली)'),
                const SizedBox(height: 16),
                _buildTextField(totalController, 'एकूण', readOnly: true),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  children: [
                    const Text(
                      'शिजवून दिलेली डाळ / कडधान्य निवडा: ',
                      style: TextStyle(fontSize: 18),
                    ),
                    DropdownButtonFormField<String>(
                      hint: const Text('डाळ निवडा'),
                      icon: const Icon(Icons.arrow_drop_down),
                      value: dropdownValue,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      items: _items.map<DropdownMenuItem<String>>(
                          (Map<String, dynamic> item) {
                        return DropdownMenuItem<String>(
                          value: item['name'],
                          child: Text(item['name']),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          dropdownValue = value;
                          selectedItem = _items.firstWhere(
                              (item) => item['name'] == value,
                              orElse: () => {});
                        });
                      },
                      validator: (value) => value == null ? 'डाळ निवडा' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitForm,
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
      {bool readOnly = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$labelText आवश्यक आहे';
        } else if (!readOnly && int.tryParse(value) == null) {
          return 'कृपया एक वैध संख्या प्रविष्ट करा';
        }
        return null;
      },
      onChanged: _updateTotal,
    );
  }
}
