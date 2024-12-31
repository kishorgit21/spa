import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:spa/logToFile.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  DateTime now = DateTime.now();
  DateTime aprilFirst = DateTime(now.year, 4, 1);
  String formattedDate = DateFormat('yyyy-MM-dd').format(aprilFirst);
  print(formattedDate); // Output: 2024-04-01
}

class BalanceForm extends StatefulWidget {
  const BalanceForm({super.key});

  @override
  _BalanceFormState createState() => _BalanceFormState();
}

class _BalanceFormState extends State<BalanceForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<TextEditingController> _controllers = [];
  List<Map<String, dynamic>> _items = [];
  final List<String> classes = ['१ ते ५', '६ ते ८']; // Class options
  String? _selectedClass; // To store the selected class
  bool isReadOnly = false;
  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    _items = await DatabaseHelper.instance.getElements();
    _controllers = List.generate(_items.length, (_) => TextEditingController());
    setState(() {});
  }

  Future<void> _loadExistingData(String? selectedClass) async {
    try {
      List<Map<String, dynamic>> rows =
          await DatabaseHelper.instance.getLastOpeningStock(selectedClass);
      if (rows.isNotEmpty) {
        List<Map<String, dynamic>> first15Rows =
            rows.length > 15 ? rows.sublist(0, 15) : rows;

        // Update state variables within setState
        setState(() {
          isReadOnly = rows.length > 15;
          for (var row in first15Rows) {
            int index =
                _items.indexWhere((item) => item['itemid'] == row['itemid']);
            if (index != -1) {
              _controllers[index].text = row['weight'].toString();
            }
          }
        });
        print(rows);
      } else {
        clearFields();
      }
    } catch (error) {
      logMessage("Failed to view the Balance Form: $error");
    }
  }

  void clearFields() {
    setState(() {
      for (var controller in _controllers) {
        controller.clear(); // Clear each TextField's text
      }
      isReadOnly = false;
    });
  }

  Future<void> _saveData() async {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        List<Map<String, dynamic>> records = [];
        //String currentDate = DateTime.now().toString();
        DateTime now = DateTime.now();
        DateTime aprilFirst = DateTime(now.year, 4, 1);
        String currentDate = DateFormat('yyyy-MM-dd').format(aprilFirst);
        for (int i = 0; i < _items.length; i++) {
          String weight = _controllers[i].text;
          records.add({
            'class': _selectedClass,
            'itemid': _items[i]['itemid'],
            'name': _items[i]['name'],
            'weight': weight,
            'created_date': currentDate,
          });
        }
        await DatabaseHelper.instance.insertOpeningStock(records);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data saved successfully')),
        );
        await _checkInsertedData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please correct the errors')),
        );
      }
    } catch (error) {
      logMessage("Failed to save the Balance Form: $error");
    }
  }

  Future<void> _checkInsertedData() async {
    List<Map<String, dynamic>> rows =
        await DatabaseHelper.instance.getLastOpeningStock(_selectedClass);
    print(rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('आरंभीची शिल्लक नोंदवा'), // Main title
            SizedBox(height: 4), // Spacing between the texts
            Text(
              '(एप्रिल महिन्याची आरंभी शिल्लक)', // Additional text
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedClass,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedClass = newValue;
                      _loadExistingData(_selectedClass);
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
                              readOnly: isReadOnly,
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
                onPressed: isReadOnly ? null : _saveData,
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
