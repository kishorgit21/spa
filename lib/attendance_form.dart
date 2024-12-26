import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'database_helper.dart';
import 'package:spa/logToFile.dart';
import 'package:spa/excel_utils.dart';
import 'package:spa/calculateDailyExpenses.dart';

class AttendanceForm extends StatefulWidget {
  const AttendanceForm({super.key});

  @override
  _AttendanceFormState createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<AttendanceForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime selectedDate = DateTime.now();
  String selectedDay = '';
  final TextEditingController patController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final TextEditingController selectedDayController = TextEditingController();
  Map<String, dynamic>? selectedItem;
  String? dropdownValue;
  List<Map<String, dynamic>> _items = [];
  final List<String> classes = ['१ ते ५', '६ ते ८']; // Class options
  String? selectedClass; // Variable to store selected class
  bool isConfigured = false; // Initialize as part of the state

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
    patController.dispose();
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
        if (selectedClass != null) {
          _getAttendance(
            DateFormat('dd-MM-yyyy').format(selectedDate),
            selectedDayController.text,
            selectedClass,
          );
        }
      });
    }
  }

  // void _updateTotal(String value) {
  //   final int boys = int.tryParse(boysController.text) ?? 0;
  //   final int girls = int.tryParse(girlsController.text) ?? 0;
  //   totalController.text = (boys + girls).toString();
  // }

  Future<void> _loadItems() async {
    List<Map<String, dynamic>> items =
        await DatabaseHelper.instance.getElements();
    setState(() {
      _items = items.skip(1).take(8).toList();
    });
  }

  Future<void> _submitForm() async {
    try {
      if (!(_formKey.currentState?.validate() ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please correct the errors')),
        );
        return;
      }

      List<Map<String, dynamic>> attendanceRecords = _prepareFormRecords();

      await DatabaseHelper.instance.insertAttendance(attendanceRecords);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Attendance saved successfully"),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      // Check if the selected date is the last day of the month
      if (_isEndOfMonth(selectedDate)) {
        bool shouldTransfer = await _showTransferConfirmationDialog();
        if (shouldTransfer) {
          await _handleEndOfMonthTransfer();
        }
      }

      await checkInsertedData();
      _clearForm();
    } catch (error, stackTrace) {
      logMessage("Failed to save the Attendance Form: $error\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An error occurred: $error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleEndOfMonthTransfer() async {
    try {
      String nextDay = DateFormat('yyyy-MM-dd').format(
        selectedDate.add(const Duration(days: 1)),
      );
      String? formattedDate =
          formatToMonthYear(DateFormat('dd-MM-yyyy').format(selectedDate));

      CalculateDailyExpenses calculateDailyExpenses =
          const CalculateDailyExpenses();
      List<Map<String, dynamic>> dailyExpenses =
          await calculateDailyExpenses.calculateDailyExpenses(formattedDate);

      // Validate daily expenses list
      if (dailyExpenses.isEmpty) {
        throw Exception("Daily expenses data is empty.");
      }

      List<Map<String, dynamic>> filteredData = dailyExpenses
          .where((data) =>
              data["class"] == selectedClass.toString() &&
              data["itemName"] != '')
          .toList();

      var result = await ExcelUtils.populateSheetData(selectedClass.toString(),
          filteredData, calculateDailyExpenses, formattedDate);

      // Validate result list
      if (result.isEmpty) {
        throw Exception("No data found in the Excel result.");
      }

      List<Map<String, dynamic>> _items =
          await DatabaseHelper.instance.getElements();

      // Validate items list
      if (_items.isEmpty) {
        throw Exception("No items found in the database.");
      }

      List<List<dynamic>> filteredRows =
          result.where((row) => row.isNotEmpty && row[0] == "शिल्लक").toList();

      // Validate filteredRows list
      if (filteredRows.isEmpty || filteredRows[0].length < 4) {
        throw Exception("Invalid or incomplete 'शिल्लक' data.");
      }

      await _insertOpeningStock(filteredRows, _items, nextDay);
      _transferRemainingBalanceToNextMonth();
    } catch (error, stackTrace) {
      logMessage("Failed to handle end-of-month transfer: $error\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error during end-of-month transfer: $error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _insertOpeningStock(List<List<dynamic>> filteredRows,
      List<Map<String, dynamic>> items, String nextDay) async {
    try {
      List<Map<String, dynamic>> nextMonthOpeningStock = [];
      for (int i = 0; i < items.length; i++) {
        // Validate filteredRows before accessing
        if (filteredRows[0].length <= i + 3) {
          throw Exception("Insufficient data in 'शिल्लक' for item index $i.");
        }

        String weight = filteredRows[0][i + 3];
        nextMonthOpeningStock.add({
          'class': selectedClass.toString(),
          'itemid': items[i]['itemid'],
          'name': items[i]['name'],
          'weight': weight,
          'created_date': nextDay,
        });
      }

      // Insert into the database
      await DatabaseHelper.instance.insertOpeningStock(nextMonthOpeningStock);
    } catch (error, stackTrace) {
      logMessage("Failed to insert opening stock: $error\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error inserting opening stock"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isEndOfMonth(DateTime date) {
    try {
      DateTime nextDay = date.add(const Duration(days: 1));
      return nextDay.month != date.month;
    } catch (error, stackTrace) {
      logMessage("Error checking end of month: $error\n$stackTrace");
      return false;
    }
  }

  List<Map<String, dynamic>> _prepareFormRecords() {
    try {
      return [
        {
          'date': DateFormat('dd-MM-yyyy').format(selectedDate),
          'day': selectedDayController.text,
          'class': selectedClass,
          'pat': int.tryParse(patController.text) ?? 0,
          'total': int.tryParse(totalController.text) ?? 0,
          'itemid': selectedItem?['itemid'] ?? 0,
          'name': selectedItem?['name'] ?? '',
          'created_date':
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        }
      ];
    } catch (error, stackTrace) {
      logMessage("Error preparing form records: $error\n$stackTrace");
      return [];
    }
  }

  Future<void> checkInsertedData() async {
    List<Map<String, dynamic>> rows =
        await DatabaseHelper.instance.getAllAttendance();
    print(rows);
  }

  String formatToMonthYear(String date) {
    try {
      // Parse the input date string
      DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(date);
      // Format it to "MMMM yyyy"
      return DateFormat('MMMM yyyy').format(parsedDate);
    } catch (e) {
      print('Error formatting date: $e');
      return '';
    }
  }

  Future<bool> _showTransferConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('स्मरणपत्र'),
              content: const Text(
                  'आजचा दिनांक महिन्याचा शेवटचा दिवस आहे. उर्वरित शिल्लक पुढील महिन्यात हस्तांतरित करायचे आहे का?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // User chooses 'No'
                  },
                  child: const Text('नाही'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // User chooses 'Yes'
                  },
                  child: const Text('हो'),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  Future<void> _transferRemainingBalanceToNextMonth() async {
    try {
      // Implement the logic to transfer the remaining balance to the next financial year
      //await DatabaseHelper.instance.transferBalanceToNextYear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remaining balance transferred to the next month.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to transfer balance.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Clear the form fields after successful submission
  void _clearForm() {
    setState(() {
      patController.clear();
      totalController.clear();
      dropdownValue = null;
      selectedItem = null;
    });
  }

  Future<void> _getAttendance(selectedDate, selectedDay, selectedClass) async {
    try {
      List<Map<String, dynamic>> rows = await DatabaseHelper.instance
          .getAttendance(selectedDate, selectedDay, selectedClass);

      if (rows.isNotEmpty) {
        final attendanceData = rows.first;
        setState(() {
          patController.text = attendanceData['pat'].toString();
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

  Future<bool> _checkConfiguration(String? selectedClass) async {
    try {
      if (selectedClass == null || selectedClass.isEmpty) return false;
      List<Map<String, dynamic>> perStudentRecord = await DatabaseHelper
          .instance
          .getRiceGrainsPerStudentRecord(selectedClass);

      List<Map<String, dynamic>> openingStock =
          await DatabaseHelper.instance.getLastOpeningStock(selectedClass);

      if (perStudentRecord.isNotEmpty && openingStock.isNotEmpty) {
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

                      bool configurationResult =
                          await _checkConfiguration(selectedClass);
                      setState(() {
                        isConfigured = !configurationResult;
                      });

                      if (isConfigured) {
                        _clearForm();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Configuration not found for class $selectedClass'),
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
                _buildTextField(patController, 'पट'),
                const SizedBox(height: 16),
                _buildTextField(totalController, 'उपस्थिती'),
                Wrap(
                  spacing: 10.0,
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
                    onPressed: isConfigured ? null : _submitForm,
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
    );
  }
}
