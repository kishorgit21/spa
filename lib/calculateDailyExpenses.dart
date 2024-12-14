import 'database_helper.dart';
import 'package:spa/logToFile.dart';

class CalculateDailyExpenses {
  const CalculateDailyExpenses();

  Future<List<Map<String, dynamic>>> calculateDailyExpenses(
      String selectedMonth) async {
    List<Map<String, dynamic>> dailyExpenses = [];
    List<Map<String, dynamic>> attendanceData = [];
    List<Map<String, dynamic>> riceGrainsPerStudentData = [];
    List<Map<String, dynamic>> balanceTotalData = [];
    try {
      // Fetch attendance data asynchronously
      attendanceData =
          await DatabaseHelper.instance.getMonthlyAttendance(selectedMonth);
      riceGrainsPerStudentData =
          await DatabaseHelper.instance.getAllRiceGrainsPerStudentRecord();
      //balanceTotalData = await balanceTotal();
      Map<String, List<Map<String, dynamic>>> balanceCache = {};

      if (attendanceData.isEmpty || riceGrainsPerStudentData.isEmpty) {
        logMessage("No data available for calculations.");
        //return [];
      }
      for (var attendance in attendanceData) {
        String dayClass = attendance['class'];
        int totalStudents = attendance['total'];
        int dalItemId = attendance['itemid'];
        String dalItemName = ""; //attendance['name'];

        // Filter rice grains data based on the class (e.g., १ ते ५, 6ते8)
        var classWiseData = riceGrainsPerStudentData
            .where((item) => item['class'] == dayClass)
            .toList();
        List<Map<String, dynamic>> dailyExpenseEntry = [];

        // Check if the balance for this class is already cached
        if (!balanceCache.containsKey(dayClass)) {
          balanceCache[dayClass] = await balanceTotal(dayClass);
        }

        // Use the cached balance data
        var balanceTotalData = balanceCache[dayClass]!;

        for (var item in classWiseData) {
          int itemId = item['itemid'];
          String itemName = item['name'];
          double weight = double.parse(item['weight']);
          double calculatedWeight = totalStudents * weight;

          // Retrieve opening, current, and total balance for the item
          var balanceData = balanceTotalData.firstWhere(
            (b) => b['itemid'] == itemId,
            orElse: () => {
              "opening_weight": 0.0,
              "current_weight": 0.0,
              "total_weight": 0.0
            },
          );

          double openingBalance =
              double.tryParse(balanceData['opening_weight'].toString()) ?? 0.0;
          double currentBalance =
              double.tryParse(balanceData['current_weight'].toString()) ?? 0.0;
          double totalBalance =
              double.tryParse(balanceData['total_weight'].toString()) ?? 0.0;

          // Apply the conditions based on item IDs
          if (itemId == 1 ||
              itemId == dalItemId ||
              (itemId >= 10 && itemId <= 15)) {
            if (itemId == dalItemId) dalItemName = itemName;
            // Only calculate for rice (itemid 1), the daily dal item, and items 10-14
            dailyExpenseEntry.add({
              "itemid": itemId,
              "itemname": itemName,
              "calculated_weight":
                  double.parse(calculatedWeight.toStringAsFixed(3)),
              "openingBalance": openingBalance,
              "currentBalance": currentBalance,
              "totalBalance": totalBalance
            });
          } else {
            dailyExpenseEntry.add({
              "itemid": itemId,
              "itemname": itemName,
              "calculated_weight": 0,
              "openingBalance": openingBalance,
              "currentBalance": currentBalance,
              "totalBalance": totalBalance
            });
          }
        }

        // Adding daily expense entry for the day in expenses list
        dailyExpenses.add({
          "itemName": dalItemName,
          "day": attendance['day'],
          "class": dayClass,
          "totalStudents": totalStudents ?? 0,
          "expenses": dailyExpenseEntry,
        });
      }

      return dailyExpenses;
    } catch (error) {
      logMessage("Failed to calculate Daily Expenses: $error");
    }
    return dailyExpenses;
  }

  Future<List<Map<String, dynamic>>> balanceTotal(String? selectedClass) async {
    List<Map<String, dynamic>> openingBalance = [];
    List<Map<String, dynamic>> currentBalance = [];
    List<Map<String, dynamic>> balanceTotal = [];

    try {
      openingBalance =
          await DatabaseHelper.instance.getOpeningStock(selectedClass);
      currentBalance =
          await DatabaseHelper.instance.getAllRiceGrainRecord(selectedClass);
      if (openingBalance.isEmpty || currentBalance.isEmpty) {
        logMessage("No data available for balanceTotal.");
        return [];
      }
      for (var opening in openingBalance) {
        var current = currentBalance.firstWhere(
          (c) => c["itemid"] == opening["itemid"],
          orElse: () => {"weight": 0},
        );

        double total = (double.tryParse(opening["weight"].toString()) ?? 0.0) +
            (double.tryParse(current["weight"].toString()) ?? 0.0);

        balanceTotal.add({
          "itemid": opening["itemid"],
          "name": opening["name"],
          "opening_weight": opening["weight"],
          "current_weight": current["weight"],
          "total_weight": total,
        });
      }
      return balanceTotal;
    } catch (e, stacktrace) {
      logMessage("Error in balanceTotal: $e\n$stacktrace");
      return [];
    }
  }
}
