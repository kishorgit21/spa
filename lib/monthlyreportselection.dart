import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spa/calculateDailyExpenses.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:spa/logToFile.dart';
import 'package:open_file/open_file.dart';
import 'database_helper.dart';

//import 'package:flutter/src/painting/box_border.dart';

class MdmRegExportForm extends StatefulWidget {
  const MdmRegExportForm({super.key});

  @override
  MdmRegExportFormState createState() => MdmRegExportFormState();
}

class MdmRegExportFormState extends State<MdmRegExportForm> {
  String _selectedMonth = '';
  String _selectedMonthMarathi = '';
  List<String> _months = [];
  final List<String> _monthsListMarathi = [];
  List<String> _previousReports = []; // List to hold previous reports
  String filePath = '';
  String _schoolName = '';

  final largeFontStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    fontSize: 18,
    bold: true, // Optional, if you want large fonts to be bold
    horizontalAlign:
        excel.HorizontalAlign.Center, // Align text horizontally to center
    verticalAlign: excel.VerticalAlign.Center,
    leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  );
  final boldStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    bold: true,
    fontSize: 12,
    leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  );

  final totalItemsboldStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    fontSize: 12,
    bold: true,
    horizontalAlign: excel.HorizontalAlign.Right, // Right align numbers
    verticalAlign: excel.VerticalAlign.Center,
    leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  );

  final defaultStyle = excel.CellStyle(
    fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  );
  // var cellStyle = excel.CellStyle(
  //   leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //   rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //   topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //   bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  // );

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
      excelFile.delete('Sheet1'); // Remove the default sheet

      // Filter dailyExpenses into two groups
      List<Map<String, dynamic>> group1to5 = dailyExpenses
          .where((data) => data["class"] == "१ ते ५" && data["itemName"] != '')
          .toList();
      List<Map<String, dynamic>> group6to8 = dailyExpenses
          .where((data) => data["class"] == "६ ते ८" && data["itemName"] != '')
          .toList();

      if (group1to5.isNotEmpty) {
        var sheet1 = excelFile['१ ते ५'];
        await populateSheet(sheet1, group1to5, calculateDailyExpenses);
      }
      if (group6to8.isNotEmpty) {
        var sheet2 = excelFile['६ ते ८'];
        await populateSheet(sheet2, group6to8, calculateDailyExpenses);
      }

      // Save the file
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/monthly_expenses_$_selectedMonth.xlsx';
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

  Future<void> populateSheet(excel.Sheet sheet, List<Map<String, dynamic>> data,
      CalculateDailyExpenses calculateDailyExpenses) async {
    final itemNames = <String>{};
    for (var dayData in data) {
      for (var item in dayData['expenses']) {
        itemNames.add(item['itemname']);
      }
    }

    // Header row for both sheets
    List<String> headers = [
      "आजचा आपला आहार",
      "दै.उपस्थिति",
      ...itemNames,
      "दैनिक खर्च"
    ];
    void addHeaderRow(excel.Sheet sheet) {
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(rowIndex: 3, columnIndex: i + 1));
        cell.value = headers[i];
        cell.cellStyle = boldStyle;
      }
    }

    // Add balance rows
    var balanceTotal = await calculateDailyExpenses.balanceTotal(
        sheet.sheetName, _selectedMonth);
    List<String> balanceLabels = ["मागील शिल्लक", "चालु महा.जमा", "एकुण"];
    if (balanceTotal.isEmpty) return;

    // Header for both sheets
    String headerTitle =
        "शालेय पोषण आहार इयत्ता ${sheet.sheetName} दैनंदिन खर्चाची नोंदवही सन 2023/2024";
    String schoolName = "शाळेचे नाव : ${await SchoolName()}";

    sheet.cell(excel.CellIndex.indexByString("A1"))
      ..value = headerTitle
      ..cellStyle = largeFontStyle;
    sheet.merge(excel.CellIndex.indexByString("A1"),
        excel.CellIndex.indexByString("S1"));

    sheet.cell(excel.CellIndex.indexByString("B2"))
      ..value = schoolName
      ..cellStyle = largeFontStyle;
    sheet.merge(excel.CellIndex.indexByString("B2"),
        excel.CellIndex.indexByString("J2"));

    sheet.cell(excel.CellIndex.indexByString("K2"))
      ..value = _selectedMonthMarathi
      ..cellStyle = largeFontStyle;
    sheet.merge(excel.CellIndex.indexByString("K2"),
        excel.CellIndex.indexByString("O2"));

// Add the main header row below the custom headers
    sheet.cell(excel.CellIndex.indexByString("A4"))
      ..value = "तपशील वार व दिनांक"
      ..cellStyle = boldStyle;

    addHeaderRow(sheet);

    for (int i = 0; i < balanceLabels.length; i++) {
      List<dynamic> row = [balanceLabels[i]]; // Initialize row with label
      // var cell = sheet
      //     .cell(CellIndex.indexByColumnRow(rowIndex: 3, columnIndex: i + 1));
      // cell.value = balanceLabels[i];
      // cell.cellStyle = boldStyle;
      // Add placeholders for Day, Class, and Students
      row.addAll(["", ""]);

      // Add item balances
      for (var itemName in itemNames) {
        var itemData = balanceTotal.firstWhere(
          (item) => item['name'] == itemName,
          orElse: () =>
              {"opening_weight": 0, "current_weight": 0, "total_weight": 0},
        );

        double balanceValue;
        if (i == 0) {
          balanceValue =
              double.tryParse(itemData['opening_weight'].toString()) ?? 0.0;
        } else if (i == 1) {
          balanceValue =
              double.tryParse(itemData['current_weight'].toString()) ?? 0.0;
        } else {
          balanceValue =
              double.tryParse(itemData['total_weight'].toString()) ?? 0.0;
        }

        row.add(balanceValue.toStringAsFixed(3));
      }
      sheet.appendRow(row);
      // Apply bold style to the first column of balance rows
      var cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(rowIndex: 4 + i, columnIndex: 0));
      cell.cellStyle = boldStyle;
    }

    int lastRowIndex = sheet.maxRows - 1; // Get the last row index
    for (int i = 0; i < sheet.maxCols; i++) {
      var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
          rowIndex: lastRowIndex, columnIndex: i));
      cell.cellStyle = totalItemsboldStyle;
    }

    // Add daily data rows and calculate totals
    int totalStudents = 0; // Total students for the month
    Map<String, double> itemTotals = {for (var name in itemNames) name: 0.0};
    double totalDailyExpense = 0.0;

    for (var dayData in data) {
      Map<String, double> expenses = {
        for (var item in dayData['expenses'])
          item['itemname']: (item['calculated_weight'] as num).toDouble()
      };

      int dailyStudents = dayData["totalStudents"] as int? ?? 0;
      totalStudents += dailyStudents;

      // Calculate total daily expense
      double dailyExp = dailyStudents * 2.0; // Example multiplier
      totalDailyExpense += dailyExp;
      // Accumulate item totals
      for (var name in itemNames) {
        itemTotals[name] = (itemTotals[name] ?? 0.0) + (expenses[name] ?? 0.0);
      }

      List<dynamic> row = [
        dayData["day"],
        dayData["itemName"],
        dailyStudents,
        ...itemNames
            .map((name) => expenses[name]?.toStringAsFixed(3) ?? "0.000"),
        dailyExp.toStringAsFixed(2)
      ];
      sheet.appendRow(row);
    }

    // Add total row
    List<dynamic> totalRow = ["एकुण खर्च", "", totalStudents];
    for (var name in itemNames) {
      totalRow.add((itemTotals[name] ?? 0.0).toStringAsFixed(3));
    }
    totalRow.add(totalDailyExpense.toStringAsFixed(2));
    sheet.appendRow(totalRow);

    for (int i = 0; i < totalRow.length; i++) {
      var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
          rowIndex: sheet.maxRows - 1, columnIndex: i));
      cell.cellStyle = totalItemsboldStyle;
    }

    // Add the balance row
    List<dynamic> balanceRow = ["शिल्लक", "", ""]; // Label for the row
    for (var name in itemNames) {
      // Get the total_weight for each item
      double totalWeight = 0.0;
      for (var item in balanceTotal) {
        if (item['name'] == name) {
          totalWeight = double.tryParse(item['total_weight'].toString()) ?? 0.0;
          break;
        }
      }

      // Calculate the balance: Total Row Value - total_weight
      double balanceValue = totalWeight - (itemTotals[name] ?? 0.0);

      // Add the calculated balance to the balance row
      balanceRow.add(balanceValue.toStringAsFixed(3));
    }

    // Append the balance row
    sheet.appendRow(balanceRow);
    // Apply bold style to "शिल्लक"
    // sheet.cell(excel.CellIndex.indexByColumnRow(
    //     rowIndex: sheet.maxRows - 1, columnIndex: 0))
    //   ..cellStyle = boldStyle;
    for (int i = 0; i < balanceRow.length; i++) {
      var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
          rowIndex: sheet.maxRows - 1, columnIndex: i));
      cell.cellStyle = totalItemsboldStyle;
    }

    await applyStylesWithBorders(sheet);
  }

  Future<void> applyStylesWithBorders(excel.Sheet sheet) async {
    // Define the style for cells
    var defaultStyle = excel.CellStyle(
      fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
      fontSize: 12,
      bold: false,
      // No background color or fill available directly in the excel package
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );
    // Define the style for numeric cells (right-aligned)
    var numericStyle = excel.CellStyle(
      fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
      fontSize: 12,
      bold: false,
      horizontalAlign: excel.HorizontalAlign.Right, // Right align for numbers
      verticalAlign: excel.VerticalAlign.Center,
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );
    // Loop through all rows and columns to apply the style
    for (int row = 0; row < sheet.maxRows; row++) {
      for (int col = 0; col < sheet.maxCols; col++) {
        var cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(rowIndex: row, columnIndex: col),
        );

        if (cell.value != null && cell.cellStyle == null) {
          // Check if the cell value is numeric
          if (num.tryParse(cell.value.toString()) != null) {
            // Apply numeric style
            cell.cellStyle = numericStyle;
          } else {
            // Apply default style
            cell.cellStyle = defaultStyle;
          }
        }
      }
    }
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
              !file.path.contains('PraPatraB')) // Check for Excel files
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
        title: const Text('Monthly Report Type A'),
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
