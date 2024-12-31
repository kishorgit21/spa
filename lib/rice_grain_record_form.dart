import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';
import 'package:spa/logToFile.dart';
import 'package:flutter/services.dart';

class RiceGrainRecordForm extends StatefulWidget {
  const RiceGrainRecordForm({super.key});

  @override
  _RiceGrainRecordFormState createState() => _RiceGrainRecordFormState();
}

class _RiceGrainRecordFormState extends State<RiceGrainRecordForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<String> classes = ['१ ते ५', '६ ते ८']; // Class options
  String? _selectedClass; // Selected class
  List<TextEditingController> _controllers = [];
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadRiceGrainRecord();
  }

  Future<void> _loadRiceGrainRecord() async {
    _items = await DatabaseHelper.instance.getElements();

    // Initialize controllers based on the loaded items
    _controllers = List.generate(_items.length, (_) => TextEditingController());

    setState(() {});
  }

  Future<void> _loadExistingData(
      String selectedDate, String? selectedClass) async {
    try {
      List<Map<String, dynamic>> rows = await DatabaseHelper.instance
          .getRiceGrainRecord(selectedDate, selectedClass);

      if (rows.isNotEmpty && rows.isNotEmpty) {
        for (var row in rows) {
          int index =
              _items.indexWhere((item) => item['itemid'] == row['itemid']);
          if (index != -1) {
            _controllers[index].text = row['weight'].toString();
          }
        }
        print(rows);
      } else {
        clearFields();
      }
    } catch (error) {
      logMessage("Failed to load RiceGrainRecordForm: $error");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101), //DateTime.now(),
    );
    // if (picked != null && picked != _selectedDate) {
    //   setState(() {
    //     _selectedDate = picked;
    //     _loadExistingData(DateFormat('yyyy-MM-dd').format(_selectedDate!));
    //   });
    // }
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        if (_selectedClass != null) {
          _loadExistingData(
            DateFormat('yyyy-MM-dd').format(_selectedDate!),
            _selectedClass,
          );
        }
      });
    }
  }

  Future<void> _saveData() async {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        List<Map<String, dynamic>> records = [];
        for (int i = 0; i < _items.length; i++) {
          String weight = _controllers[i].text;
          records.add({
            'class': _selectedClass,
            'itemid': _items[i]['itemid'],
            'name': _items[i]['name'],
            'weight': weight,
            'received_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          });
        }

        await DatabaseHelper.instance.insertRiceGrainRecords(records);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data saved successfully"),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please correct the errors"),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      logMessage("Failed to save RiceGrainRecordForm: $error");
    }
  }

  void clearFields() {
    setState(() {
      for (var controller in _controllers) {
        controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('प्राप्त धान्य नोंद'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Class Selection Dropdown
              DropdownButtonFormField<String>(
                value: _selectedClass,
                onChanged: (newValue) {
                  setState(() {
                    _selectedClass = newValue;
                    if (_selectedDate != null) {
                      _loadExistingData(
                        DateFormat('yyyy-MM-dd').format(_selectedDate!),
                        _selectedClass,
                      );
                    }
                  });
                },
                items: classes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 18)),
                  );
                }).toList(),
                decoration: const InputDecoration(
                  labelText: 'वर्ग',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'वर्ग निवडा' : null,
              ),

              const SizedBox(height: 16),

              // Date Picker Field
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'साहित्य प्राप्त दिनांक',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedDate == null
                      ? ''
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                ),
                validator: (value) {
                  if (_selectedDate == null) {
                    return 'कृपया दिनांक निवडा';
                  }
                  return null;
                },
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${_items[index]['itemid']}. ${_items[index]['name']}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _controllers[index],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'वजन (kg)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'वजन आवश्यक आहे';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'कृपया वैध संख्या प्रविष्ट करा';
                                }
                                return null;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^-?\d*(\.\d{0,})?$')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'सबमिट',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
