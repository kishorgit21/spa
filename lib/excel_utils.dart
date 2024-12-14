class ExcelUtils {
  static Future<List<List<dynamic>>> populateSheetData(
    String sheetName,
    List<Map<String, dynamic>> data,
    dynamic calculateDailyExpenses,
  ) async {
    // Initialize the rows list
    List<List<dynamic>> rows = [];

    // Add the title row
    rows.add(["तपशील वार व दिनांक"]);

    final itemNames = <String>{};
    for (var dayData in data) {
      for (var item in dayData['expenses']) {
        itemNames.add(item['itemname']);
      }
    }

    // Header row for the sheet
    List<String> headers = [
      "आजचा आपला आहार",
      "दै.उपस्थिति",
      ...itemNames,
      "दैनिक खर्च"
    ];
    rows.add(headers);

    // Add balance rows
    var balanceTotal = await calculateDailyExpenses.balanceTotal(sheetName);
    List<String> balanceLabels = ["मागील शिल्लक", "चालु महा.जमा", "एकुण"];
    if (balanceTotal.isEmpty) return [];
    for (int i = 0; i < balanceLabels.length; i++) {
      List<dynamic> row = [balanceLabels[i]]; // Initialize row with label
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
      rows.add(row);
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
      rows.add(row);
    }

    // Add total row
    List<dynamic> totalRow = ["एकुण खर्च", "", totalStudents];
    for (var name in itemNames) {
      totalRow.add((itemTotals[name] ?? 0.0).toStringAsFixed(3));
    }
    totalRow.add(totalDailyExpense.toStringAsFixed(2));
    rows.add(totalRow);

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

    rows.add(balanceRow);
    return rows;
  }
}
