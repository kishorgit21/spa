import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spa/calculateDailyExpenses.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:spa/logToFile.dart';
import 'package:open_file/open_file.dart';
import 'database_helper.dart';
import 'package:spa/excel_utils.dart';

//import 'package:flutter/src/painting/box_border.dart';

class YearlyReportSelection extends StatefulWidget {
  const YearlyReportSelection({super.key});

  @override
  YearlyReportSelectionState createState() => YearlyReportSelectionState();
}

class YearlyReportSelectionState extends State<YearlyReportSelection> {
  String _selectedFinancialYear = '';
  List<String> _financialYears = [];
  String _selectedMonth = '';
  String _selectedMonthMarathi = '';
  List<String> _months = [];
  final List<String> _monthsListMarathi = [];
  List<String> _previousReports = []; // List to hold previous reports
  String filePath = '';
  String _schoolName = '';
  String _financialYearInMarathi = '';

  @override
  void initState() {
    super.initState();
    _populateFinancialYears();

    _populateMonths();
    _loadAllExcelFiles();
  }

// Populate financial years
  void _populateFinancialYears() {
    DateTime now = DateTime.now();
    int startYear = now.year - 1; // Start from 5 years ago
    int endYear = now.year + 3; // End 5 years into the future

    List<String> financialYears = [];
    for (int year = startYear; year <= endYear; year++) {
      String financialYear = "April $year - March ${year + 1}";
      financialYears.add(financialYear);
    }

    setState(() {
      _financialYears = financialYears;
      _selectedFinancialYear = financialYears[0]; // Default to the first year
    });
  }

  // Dynamically populate months
  void _populateMonths() {
    if (_selectedFinancialYear.isEmpty) return;
    DateTime now = DateTime.now();
    List<String> monthsList = [];
    _monthsListMarathi.clear();

    var englishFormatter = DateFormat('MMMM yyyy', 'en');
    var marathiFormatter = DateFormat('MMMM yyyy', 'mr');

    // Extract start year from the selected financial year
    int startYear = int.parse(_selectedFinancialYear.split(' ')[1]);
    _financialYearInMarathi = getFinancialYearInMarathi(_selectedFinancialYear);
    // Start from April of the selected year
    DateTime financialYearStart = DateTime(startYear, 4);

    // Populate months for the financial year (April to March)
    for (int i = 0; i < 12; i++) {
      DateTime month =
          DateTime(financialYearStart.year, financialYearStart.month + i);
      monthsList.add(englishFormatter.format(month)); // English format
      _monthsListMarathi.add(marathiFormatter.format(month)); // Marathi format
    }

    // Set the current month dynamically
    DateTime nowdt = DateTime.now();
    String currentMonthEnglish = englishFormatter.format(nowdt);
    int currentMonthIndex = monthsList.contains(currentMonthEnglish)
        ? monthsList.indexOf(currentMonthEnglish)
        : 0;

    setState(() {
      _months = monthsList;
      _selectedMonth = _months[currentMonthIndex];
      _selectedMonthMarathi = _monthsListMarathi[currentMonthIndex];
    });
  }

  String getFinancialYearInMarathi(String financialYear) {
    // Extract the start year and end year from the financial year string
    int startYear = int.parse(financialYear.split(' ')[1]); // Extract 2024
    int endYear = int.parse(financialYear.split(' ')[4]); // Extract 2025

    // Convert the years to Marathi format
    var marathiFormatter = DateFormat('yyyy', 'mr');
    String startYearMarathi = marathiFormatter.format(DateTime(startYear));
    String endYearMarathi = marathiFormatter.format(DateTime(endYear));

    // Combine the years in Marathi format
    return '$startYearMarathi - $endYearMarathi';
  }

  Future<String> SchoolName() async {
    try {
      List<Map<String, dynamic>> rows =
          await DatabaseHelper.instance.getProfiles();
      if (rows.isNotEmpty) {
        var row = rows.first;
        _schoolName = row['schoolName'] ?? '';
      }
    } catch (error) {
      logMessage("Profile issue: $error");
    }
    return _schoolName;
  }

  // Function to create the Excel file and return the file path
  Future<String> createExcelFile() async {
    try {
      List<String> selectedMonths = _months;
      List<String>? selectedDataMonths = [];
      List<Map<String, dynamic>> allDailyExpenses = [];
      CalculateDailyExpenses calculateDailyExpenses =
          const CalculateDailyExpenses();
      // List<Map<String, dynamic>> dailyExpenses =
      //     await calculateDailyExpenses.calculateDailyExpenses(_selectedMonth);

      for (String month in selectedMonths) {
        // Call calculateDailyExpenses for each month individually
        List<Map<String, dynamic>> monthlyExpenses =
            await calculateDailyExpenses.calculateDailyExpenses(month);

        if (monthlyExpenses.isEmpty) {
          continue;
        } else {
          selectedDataMonths.add(month);
        }
        // Add the month name to each entry in monthlyExpenses
        for (var expense in monthlyExpenses) {
          expense["month"] = month; // Add the month name to each expense entry
        }

        // Add the fetched monthly expenses to the consolidated list
        allDailyExpenses.addAll(monthlyExpenses);
      }

      if (allDailyExpenses.isEmpty) {
        return "";
      }

      // Create a map to store expenses grouped by month
      Map<String, List<Map<String, dynamic>>> groupedExpenses = {};

      // Group expenses by month
      for (String month in selectedDataMonths) {
        // Filter expenses for the current month
        List<Map<String, dynamic>> monthlyExpenses =
            allDailyExpenses.where((data) {
          return data["month"] == month; // Filter by month
        }).toList();

        // Add the month's expenses to the map
        groupedExpenses[month] = monthlyExpenses;
      }

      var excelFile = excel.Excel.createExcel();
      excelFile.delete('Sheet1'); // Remove the default sheet
      Map<String, List<Map<String, dynamic>>> filteredExpensesgroup1to5 = {};
      Map<String, List<Map<String, dynamic>>> filteredExpensesgroup6to8 = {};

      // Filter dailyExpenses into two groups
      groupedExpenses.forEach((key, value) {
        filteredExpensesgroup1to5[key] = value.where((item) {
          String classValue =
              item["class"].toString().trim(); // Normalize the value
          return classValue == "१ ते ५" &&
              item["itemName"].toString().trim() != '';
        }).toList();
      });
      groupedExpenses.forEach((key, value) {
        filteredExpensesgroup6to8[key] = value.where((item) {
          String classValue =
              item["class"].toString().trim(); // Normalize the value
          return classValue == "६ ते ८" &&
              item["itemName"].toString().trim() != '';
        }).toList();
      });

      if (filteredExpensesgroup1to5.isNotEmpty) {
        var sheet1 = excelFile['१ ते ५'];
        await populateSheet(
            sheet1, filteredExpensesgroup1to5, calculateDailyExpenses);
      }
      if (filteredExpensesgroup6to8.isNotEmpty) {
        var sheet1 = excelFile['६ ते ८'];
        await populateSheet(
            sheet1, filteredExpensesgroup6to8, calculateDailyExpenses);
      }

      // Save the file
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/MDMAUDIT$_financialYearInMarathi.xlsx';
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excelFile.encode()!);

      _showPrintSuccessToast();

      return filePath;
    } catch (error) {
      logMessage("Failed to create Excel File: $error");
      return "";
    }
  }

  Future<void> populateSheet(
    excel.Sheet sheet,
    Map<String, List<Map<String, dynamic>>> data,
    CalculateDailyExpenses calculateDailyExpenses,
  ) async {
    try {
      List<dynamic> headerRow = [
        'अ. क्र',
        '',
      ]; // First column+ for serial number and empty column for महिना
      List<dynamic> subHeaderRow = [
        '',
        'महिना',
      ];

      String schoolName = "शाळेचे नाव : ${await SchoolName()}";

      sheet.cell(excel.CellIndex.indexByString("B1"))
        ..value =
            'शालेय पोषण आहार योजना वार्षिक उपयोगिता प्रमाणपत्र सन ${_financialYearInMarathi}';
      //..cellStyle = largeFontStyle;
      sheet.merge(excel.CellIndex.indexByString("B1"),
          excel.CellIndex.indexByString("H1"));

      // Set up the second row for school, center, and month details (row 2)
      sheet.cell(excel.CellIndex.indexByString("B2"))..value = schoolName;
      //..cellStyle = largeFontStyle;

      sheet.cell(excel.CellIndex.indexByString("G2"))..value = 'केंद्र : XXX';
      //..cellStyle = largeFontStyle;

      sheet.cell(excel.CellIndex.indexByString("K2"))
        ..value = 'इयत्ता: ${sheet.sheetName}';
      //..cellStyle = largeFontStyle;
      int id = 1;
      //bool headersAdded = false;
      final itemNames = await DatabaseHelper.instance.getElements();
      var itemNamesList = null;

      // Loop through the default items list for headers and subheaders
      itemNamesList = itemNames.toList();
      for (int i = 0; i < itemNamesList.length; i++) {
        headerRow.add(itemNamesList[i]['name'] ?? '');
        headerRow.add('');
        headerRow.add('');
        headerRow.add('');
        headerRow.add('');

        subHeaderRow.add('मागील शिल्लक');
        subHeaderRow.add('चालु महा.जमा');
        subHeaderRow.add('एकूण');
        subHeaderRow.add('अन्न शिजवण्यासाठी वापरलेल्या वस्तु');
        subHeaderRow.add('शिल्लक');
      }

      // Add the merged header row
      sheet.appendRow(headerRow);

      // Add subheaders row
      sheet.appendRow(subHeaderRow);

      for (var month in data.keys.toSet().toList()) {
        {
          //if (id == 3) break;

          final expenses = data[month]!;
          if (expenses.isEmpty) continue;
          //print("Item Name: ${expense["itemName"]}");
          final result = await ExcelUtils.populateSheetData(
              sheet.sheetName, expenses, calculateDailyExpenses, month);

          //if (result.isEmpty) return;

          final filteredTotals = result.where((row) {
            final filters = [
              "मागील शिल्लक",
              "चालु महा.जमा",
              "एकुण",
              "एकुण खर्च",
              "शिल्लक"
            ];
            // Check if the first cell (or any specific cell) contains any of the keywords
            return row.isNotEmpty &&
                filters.any((keyword) => row[0].toString().contains(keyword));
          }).toList();

          List<dynamic> row = [
            id, // Serial number
            _monthsListMarathi[_months.indexOf(month)], // Month
          ];

          for (int i = 0; i < itemNamesList.length; i++) {
            final previousBalance =
                getValue(filteredTotals[0], 3 + i); // मागील शिल्लक
            final currentReceived =
                getValue(filteredTotals[1], 3 + i); // चालु महा.जमा
            final totalQuantity = getValue(filteredTotals[2], 3 + i); // एकुण
            final usedForCooking =
                getValue(filteredTotals[3], 3 + i); // एकुण खर्च
            final remaining = getValue(filteredTotals[4], 3 + i); // शिल्लक

            row.add(previousBalance);
            row.add(currentReceived);
            row.add(totalQuantity);
            row.add(usedForCooking);
            row.add(remaining);
          }

          sheet.appendRow(row);
          id++;
        }
      }
    } catch (error) {
      logMessage("Populate sheet error: $error");
    }
  }

  //Helper function to retrieve the value
  dynamic getValue(List<dynamic> row, int columnIndex) {
    return (row.isNotEmpty && row.length > columnIndex)
        ? row[columnIndex] ?? ''
        : '';
  }

  // Function to show a success dialog after printing
  Future<void> _showPrintSuccessToast() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("The Excel file has been created successfully!"),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Function to open the file
  Future<void> _openFile(String filePath) async {
    try {
      logMessage("start open file");
      final file = File(filePath);
      if (await file.exists()) {
        OpenFile.open(filePath);
      } else {
        logMessage("File does not exist");
      }
    } catch (error) {
      logMessage("Network error occurred while saving user: $error");
    }
  }

  // Function to remove all previous reports and delete the files from storage
  Future<void> _removeAllReports() async {
    for (var filePath in _previousReports) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete(); // Delete the file
      }
    }

    setState(() {
      _previousReports.clear(); // Clear the list of previous reports
    });

    // Show confirmation dialog after removing all reports
    _showRemoveAllReportsDialog();
  }

  // Function to show a confirmation dialog after removing all reports
  Future<void> _showRemoveAllReportsDialog() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All previous reports have been successfully removed."),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Function to remove a specific report file
  Future<void> _removeReport(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete(); // Delete the file
      setState(() {
        _previousReports.remove(filePath); // Remove from the list of reports
      });

      // Show confirmation dialog after removing individual report
      _showRemoveReportDialog(filePath);
    } else {
      throw 'File does not exist';
    }
  }

  // Function to show a confirmation dialog after removing a specific report
  void _showRemoveReportDialog(String filePath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'The report "${filePath.split('/').last}" has been successfully removed.'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadAllExcelFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files =
          directory.listSync(); // List all files

      // Filter only `.xlsx` files
      List<String> excelFiles = files
          .where((file) =>
              file is File &&
              file.path.endsWith('.xlsx') &&
              !file.path.contains('PraPatraB') &&
              !file.path.contains('monthly')) // Check for Excel files
          .map((file) => file.path)
          .toList();

      setState(() {
        _previousReports =
            excelFiles; // Update state with the list of Excel files
      });
    } catch (e) {
      print("Error while loading Excel files: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('वार्षिक अहवाल'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'वर्ष निवडा:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedFinancialYear, //_selectedMonth,
                  icon: const Icon(Icons.arrow_drop_down),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedFinancialYear = newValue!;
                      _populateMonths();
                    });
                  },
                  items: _financialYears
                      .map<DropdownMenuItem<String>>((String year) {
                    return DropdownMenuItem<String>(
                      value: year,
                      child: Text(
                        year,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  String filePath = await createExcelFile();
                  if (filePath.isEmpty) {
                    // If file path is empty, show a SnackBar or handle as needed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Failed to generate Excel file or no data available."),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return; // Exit early if no valid file path is returned
                  }
                  setState(() {
                    _previousReports.add(filePath);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'अहवाल तयार करा',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'जुने अहवाल :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            _previousReports.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_forever),
                    onPressed: _removeAllReports,
                    tooltip: 'Remove All Reports',
                    iconSize: 30,
                    color: Colors.red,
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 10),
            _previousReports.isNotEmpty
                ? Column(
                    children: _previousReports.map((filePath) {
                      String fileName = filePath.split('/').last;
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            fileName,
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () {
                                  _openFile(filePath); // Open the file
                                },
                                tooltip: 'Open Report',
                                iconSize: 30,
                                color: Colors.green,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _removeReport(
                                      filePath); // Remove individual report
                                },
                                tooltip: 'Remove Report',
                                iconSize: 30,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : const Text("No previous reports available."),
          ],
        ),
      ),
    );
  }
}
