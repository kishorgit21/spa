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

class PraPatraFormB extends StatefulWidget {
  const PraPatraFormB({super.key});

  @override
  _PraPatraFormB createState() => _PraPatraFormB();
}

class _PraPatraFormB extends State<PraPatraFormB> {
  String _selectedMonth = '';
  String _selectedMonthMarathi = '';
  List<String> _months = [];
  final List<String> _monthsListMarathi = [];
  List<String> _previousReports = []; // List to hold previous reports
  String filePath = '';
  String _schoolName = '';
  final globalData = GlobalData();

  final largeFontStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    fontSize: 18,
    bold: true, // Optional, if you want large fonts to be bold
    horizontalAlign:
        excel.HorizontalAlign.Center, // Align text horizontally to center
    verticalAlign: excel.VerticalAlign.Center,
  );
  final boldStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    bold: true,
    fontSize: 12,
  );

  final totalItemsboldStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    fontSize: 12,
    bold: true,
    horizontalAlign: excel.HorizontalAlign.Right, // Right align numbers
    verticalAlign: excel.VerticalAlign.Center,
  );
  final defaultStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
  );

  @override
  void initState() {
    super.initState();
    _populateMonths();
    _loadAllExcelFiles();
  }

  // Dynamically populate months
  void _populateMonths() {
    DateTime now = DateTime.now();
    List<String> monthsList = [];
    //List<String> monthsListMarathi = [];

    // Formatters for English and Marathi
    var englishFormatter = DateFormat('MMMM yyyy', 'en');
    var marathiFormatter = DateFormat('MMMM yyyy', 'mr');

    for (int i = 0; i < 12; i++) {
      DateTime month = DateTime(now.year, now.month + i);
      monthsList.add(englishFormatter.format(month)); // English format
      _monthsListMarathi.add(marathiFormatter.format(month)); // Marathi format
    }

    setState(() {
      _months = monthsList; // Months in English
      _selectedMonth = _months[0]; // Default selection in English
      _selectedMonthMarathi =
          _monthsListMarathi[0]; // Default selection in Marathi
    });
  }

  Future<String> SchoolName() async {
    try {
      List<Map<String, dynamic>> rows =
          await DatabaseHelper.instance.getProfiles();
      if (rows.isNotEmpty && rows.isNotEmpty) {
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
      CalculateDailyExpenses calculateDailyExpenses =
          const CalculateDailyExpenses();
      List<Map<String, dynamic>> dailyExpenses =
          await calculateDailyExpenses.calculateDailyExpenses(_selectedMonth);

      if (dailyExpenses.isEmpty) {
        return "";
      }

      var excelFile = excel.Excel.createExcel();
      //  excelFile.delete('Sheet1'); // Remove the default sheet`

      // Filter dailyExpenses into two groups
      List<Map<String, dynamic>> group1to5 = dailyExpenses
          .where((data) => data["class"] == "१ ते ५" && data["itemName"] != '')
          .toList();
      List<Map<String, dynamic>> group6to8 = dailyExpenses
          .where((data) => data["class"] == "६ ते ८" && data["itemName"] != '')
          .toList();

      if (group1to5.isNotEmpty) {
        globalData.totalGroupedSums = 0;
        globalData.totalFoodDays = 0;
        var sheet1 = excelFile['१ ते ५'];
        await populateSheet(sheet1, group1to5, calculateDailyExpenses);
      }
      if (group6to8.isNotEmpty) {
        globalData.totalGroupedSums = 0;
        globalData.totalFoodDays = 0;
        var sheet2 = excelFile['६ ते ८'];
        await populateSheet(sheet2, group6to8, calculateDailyExpenses);
      }

      //Save the file
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/monthly_PraPatraB_$_selectedMonth.xlsx';
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
    List<Map<String, dynamic>> data,
    CalculateDailyExpenses calculateDailyExpenses,
  ) async {
    try {
      var result = await ExcelUtils.populateSheetData(
          sheet.sheetName, data, calculateDailyExpenses, _selectedMonth);
      if (result.isEmpty) return;
      String schoolName = "शाळेचे नाव : ${await SchoolName()}";

      sheet.cell(excel.CellIndex.indexByString("B1"))
        ..value = 'शालेय पोषण आहार (प्रपत्र ब) इयत्ता ${sheet.sheetName}'
        ..cellStyle = largeFontStyle;
      sheet.merge(excel.CellIndex.indexByString("B1"),
          excel.CellIndex.indexByString("H1"));

      // Set up the second row for school, center, and month details (row 2)
      sheet.cell(excel.CellIndex.indexByString("A2"))
        ..value = schoolName
        ..cellStyle = largeFontStyle;

      sheet.cell(excel.CellIndex.indexByString("E2"))
        ..value = 'केंद्र : XXX'
        ..cellStyle = largeFontStyle;

      sheet.cell(excel.CellIndex.indexByString("H2"))
        ..value = 'महिना: $_selectedMonthMarathi'
        ..cellStyle = largeFontStyle;
      // Apply values and bold style to cells
      sheet.cell(excel.CellIndex.indexByString("A3"))
        ..value = 'एकूण पट संख्या :'
        ..cellStyle = boldStyle;
      sheet.cell(excel.CellIndex.indexByString("B3"))
        ..value = '0'
        ..cellStyle = boldStyle;
      sheet.cell(excel.CellIndex.indexByString("D3"))
        ..value = 'महिन्यातील एकूण उपस्थिती संख्या :'
        ..cellStyle = boldStyle;
      // sheet.cell(excel.CellIndex.indexByString("E3")).value =
      //     globalData.totalGroupedSums / globalData.totalFoodDays;
      sheet.cell(excel.CellIndex.indexByString("G3"))
        ..value = 'कामाचे एकूण दिवस :'
        ..cellStyle = boldStyle;
      // sheet.cell(excel.CellIndex.indexByString("H3")).value =
      //     globalData.totalFoodDays;

      // // Add column headers (row 4)

      final itemNames = <String>{};
      for (var dayData in data) {
        for (var item in dayData['expenses']) {
          itemNames.add(item['itemname']);
        }
      }
      final List<String> headers = [
        'अ. सं.',
        'वस्तुचे नाव',
        'मागील शिल्लक वस्तु (कि.ग्रॅम)',
        'चालु महा. प्राप्त वस्तु (कि.ग्रॅम)',
        'एकूण वस्तु (कि.ग्रॅम)',
        'अन्न शिजवण्यासाठी वापरलेल्या वस्तु (कि.ग्रॅम)',
        'शिल्लक वस्तु (कि.ग्रॅम)',
        'एकूण ताटे',
        //'शेरा',
      ];

      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
        cell.value = headers[i];
        cell.cellStyle = excel.CellStyle(
            bold: true,
            fontSize: 12,
            fontFamily: excel.getFontFamily(excel.FontFamily.Calibri));
      }
      final filterDays = [
        "सोमवार",
        "मंगळवार",
        "बुधवार",
        "गुरुवार",
        "शुक्रवार",
        "शनिवार",
        "रविवार"
      ];
      final filteredDays = result.where((row) {
        if (row.isEmpty) return false; // Skip empty rows
        return row.isNotEmpty &&
            filterDays.any((keyword) => row[0].toString().contains(keyword));
      }).toList();

// Group by Row2 (index 1) and sum Row3 (index 2)
      Map<String, int> groupedSums = {};

      for (var data in filteredDays) {
        final key = data[1]?.toString(); // Access the itemname
        final value = data[2]?.toInt(); // Access the quantity
        if (key is String && value is int) {
          groupedSums[key] = (groupedSums[key] ?? 0) + value;
        }
      }

      if (filteredDays.isNotEmpty) {
        globalData.totalFoodDays = filteredDays.length;
      }
      if (groupedSums.isNotEmpty) {
        globalData.totalGroupedSums =
            groupedSums.values.fold(0, (sum, value) => sum + value);
      } else {
        print('groupedSums is null or empty.');
      }

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

      final List<List<dynamic>> data1 = [];
      final itemNamesList = itemNames.toList();

      for (int i = 0; i < itemNamesList.length; i++) {
        final firstItem = getValue(filteredTotals[0], 3 + i); // मागील शिल्लक
        final secondItem = getValue(filteredTotals[1], 3 + i); // चालु महा.जमा
        final thirdItem = getValue(filteredTotals[2], 3 + i); // एकुण
        final forthItem = getValue(filteredTotals[3], 3 + i); // एकुण खर्च
        final fifthItem = getValue(filteredTotals[4], 3 + i); // शिल्लक
        final shera;
        // Auto-increment ID and prepare values for the row
        final id = i + 1;
        final name = itemNamesList[i] ?? '';
        final previousBalance = firstItem ?? '';
        final currentReceived = secondItem ?? '';
        final totalQuantity = thirdItem ?? '';
        final usedForCooking = forthItem ?? '';
        final remaining = fifthItem ?? '';
        if (name == 'तांदूळ') {
          shera = globalData.totalGroupedSums ?? '';
        } else {
          shera = groupedSums[name] ?? '';
        }
        // Add to data1 with only selected columns
        data1.add([
          id,
          name,
          previousBalance,
          currentReceived,
          totalQuantity,
          usedForCooking,
          remaining,
          shera,
        ]);
      }
      sheet.cell(excel.CellIndex.indexByString("E3")).value =
          globalData.totalGroupedSums / globalData.totalFoodDays;
      sheet.cell(excel.CellIndex.indexByString("H3")).value =
          globalData.totalFoodDays;

      // Add data rows
      for (int i = 0; i < data1.length; i++) {
        for (int j = 0; j < data1[i].length; j++) {
          var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(rowIndex: i + 4, columnIndex: j),
          );

          cell.value = data1[i][j].toString();
          cell.cellStyle = excel.CellStyle(
            horizontalAlign: excel.HorizontalAlign.Center,
            fontSize: 12,
            fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
          );
          // Apply style only from the second column onwards
          if (j > 1) {
            cell.cellStyle = excel.CellStyle(
              horizontalAlign: excel.HorizontalAlign.Right,
              fontSize: 12,
              fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
            );
          }
        }
      }
    } catch (error) {
      logMessage("Populate sheet error: $error");
    }
  }

  // Helper function to retrieve the value
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
              file.path.contains('PraPatraB'))
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
        title: const Text('Monthly Report Type B'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'महिना निवडा:',
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
                  value: _selectedMonth,
                  icon: const Icon(Icons.arrow_drop_down),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedMonth = newValue!;
                      int selectedIndex = _months.indexOf(newValue);
                      _selectedMonthMarathi = _monthsListMarathi[selectedIndex];
                    });
                  },
                  items: _months.map<DropdownMenuItem<String>>((String month) {
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(
                        month,
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

class GlobalData {
  // Singleton instance
  static final GlobalData _instance = GlobalData._internal();

  // Private constructor
  GlobalData._internal();

  // Factory constructor to return the singleton instance
  factory GlobalData() => _instance;

  // Private variables
  int _totalGroupedSums = 0;
  int _totalFoodDays = 0;

  // Getters
  int get totalGroupedSums => _totalGroupedSums;
  int get totalFoodDays => _totalFoodDays;

  // Setters
  set totalGroupedSums(int value) {
    _totalGroupedSums = value;
  }

  set totalFoodDays(int value) {
    _totalFoodDays = value;
  }
}
