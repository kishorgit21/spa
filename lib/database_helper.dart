import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shaleya_poshan.db');
    return _database!;
  }

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'shaleya_poshan.db');

    // Delete the existing database
    await deleteDatabase(path);

    // Reinitialize the database
    _database = await _initDB('shaleya_poshan.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Drop tables if they exist
    await db.execute('DROP TABLE IF EXISTS SchoolProfile');
    await db.execute('DROP TABLE IF EXISTS Elements');
    await db.execute('DROP TABLE IF EXISTS OpeningStock');
    await db.execute('DROP TABLE IF EXISTS Aattendance');
    await db.execute('DROP TABLE IF EXISTS RiceGrainRecord');
    await db.execute('DROP TABLE IF EXISTS RiceGrainsPerStudent');

    // Create the tables
    await db.execute('''
      CREATE TABLE Elements (
        itemid INTEGER PRIMARY KEY,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        day  TEXT,
        class TEXT,
        boys INTEGER,
        girls INTEGER,
        total INTEGER,	
        itemid INTEGER,
        name TEXT,
        created_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE OpeningStock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class TEXT,
        itemid INTEGER,
        name TEXT,
        weight TEXT,
        created_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
          CREATE TABLE RiceGrainRecord (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class TEXT,
            itemid INTEGER,
            name TEXT NOT NULL,
            weight TEXT NOT NULL,
            received_date TEXT NOT NULL
          )
        ''');

    await db.execute('''
          CREATE TABLE RiceGrainsPerStudent (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            class TEXT NOT NULL,
            itemid INTEGER,
            name TEXT NOT NULL,
            weight TEXT NOT NULL,
            created_date TEXT NOT NULL
          )
        ''');

    await db.execute('''
          CREATE TABLE SchoolProfile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,           -- Unique ID for each profile entry
            schoolName TEXT NOT NULL,                       -- School name
            udiseCode TEXT NOT NULL UNIQUE,                 -- Unique UDISE code for each school
            city TEXT NOT NULL,                             -- City or village name
            taluka TEXT NOT NULL,                           -- Taluka
            district TEXT NOT NULL,                         -- District
            principalName TEXT NOT NULL,                    -- Principal's name
            mobileNumber TEXT NOT NULL,                     -- Mobile number
            email TEXT,                                     -- Email (optional but can be validated in the app)
            startDate TEXT NOT NULL,                        -- Start date of the financial year, stored as a string (e.g., 'YYYY-MM-DD')
            endDate TEXT NOT NULL,                           -- End date of the financial year, stored as a string (e.g., 'YYYY-MM-DD')
            isOnline INTEGER DEFAULT 0,                     -- Indicates if the school is online (0 = false, 1 = true) 
            paymentId TEXT,
            orderId TEXT,
            signature TEXT
            createdDate TEXT DEFAULT CURRENT_TIMESTAMP      -- Automatically set to current date and time on insertion
          )
        ''');

    // Insert default items after tables have been created
    await insertDefaultItems(db);
  }

  Future<void> insertDefaultItems(Database db) async {
    // Check if the table already has data
    List<Map<String, dynamic>> existingItems = await db.query('elements');
    if (existingItems.isNotEmpty) return;

    final List<Map<String, dynamic>> defaultItems = [
      {"itemid": 1, "name": "तांदूळ"},
      {"itemid": 2, "name": "मुगडाळ"},
      {"itemid": 3, "name": "तूरडाळ"},
      {"itemid": 4, "name": "मसूरडाळ"},
      {"itemid": 5, "name": "मटकी"},
      {"itemid": 6, "name": "वाटाणा"},
      {"itemid": 7, "name": "हरभरा"},
      {"itemid": 8, "name": "हिरवा मूग"},
      {"itemid": 9, "name": "चवळी"},
      {"itemid": 10, "name": "मोहरी"},
      {"itemid": 11, "name": "जिरे"},
      {"itemid": 12, "name": "हळद"},
      {"itemid": 13, "name": "तिखट"},
      {"itemid": 14, "name": "तेल"},
      {"itemid": 15, "name": "मीठ"},
    ];

    // Insert each default item
    for (var item in defaultItems) {
      await db.insert(
        'Elements',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> insertProfile(
      List<Map<String, dynamic>> records) async {
    var mobileNumber = records.first['mobileNumber'].toString();
    var email = records.first['email'].toString();

    final db = await database;
    List<Map<String, dynamic>> updatedOrInsertedRecords = [];

    List<Map<String, dynamic>> existingRecord =
        await getProfile(mobileNumber, email);

    await db.transaction((txn) async {
      if (existingRecord.isEmpty) {
        for (var record in records) {
          int id = await txn.insert(
            'SchoolProfile',
            record,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          // Fetch the newly inserted record
          final insertedRecord = await txn.query(
            'SchoolProfile',
            where: 'rowid = ?',
            whereArgs: [id],
          );
          updatedOrInsertedRecords.addAll(insertedRecord);
        }
      } else {
        // Update the existing record for this receivedDate
        for (var record in records) {
          await txn.update(
            'SchoolProfile',
            record,
            where:
                'mobileNumber = ? AND email = ?', // Update based on the received_date
            whereArgs: [mobileNumber, email],
          );
          // Fetch the updated record
          final updatedRecord = await txn.query(
            'SchoolProfile',
            where: 'mobileNumber = ? AND email = ?',
            whereArgs: [mobileNumber, email],
          );
          updatedOrInsertedRecords.addAll(updatedRecord);
        }
      }
    });
    return updatedOrInsertedRecords;
  }

  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('OpeningStock', row);
  }

  Future<void> insertOpeningStock(List<Map<String, dynamic>> records) async {
    Database db = await instance.database;
    var classValue = records.first['class'].toString();

    List<Map<String, dynamic>> existingRecord =
        await getOpeningStock(classValue);

    await db.transaction((txn) async {
      if (existingRecord.isEmpty) {
        for (var record in records) {
          await txn.insert(
            'OpeningStock',
            record,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        // Update the existing record for this class
        for (var record in records) {
          await txn.update(
            'OpeningStock',
            record,
            where: 'class = ? AND itemid = ?', // Update based on the class
            whereArgs: [classValue, record.values.elementAt(1)],
          );
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getElements() async {
    final db = await database;
    return await db.query('Elements');
  }

  Future<List<Map<String, dynamic>>> getProfiles() async {
    final db = await database;
    return await db.query('SchoolProfile');
  }

  Future<List<Map<String, dynamic>>> getProfile(
      String mobileNumber, String email) async {
    final db = await database;
    if (mobileNumber.isEmpty && email.isEmpty) {
      return [];
    }
    return await db.query(
      'SchoolProfile',
      where: 'mobileNumber = ? AND email= ?',
      whereArgs: [mobileNumber, email],
    );
  }

  Future<List<Map<String, dynamic>>> getOpeningStockO() async {
    final db = await database; // Assuming you have a database getter
    return await db.rawQuery('''
    SELECT * 
    FROM OpeningStock
    ORDER BY created_date DESC
    LIMIT 15
  ''');
  }

  Future<List<Map<String, dynamic>>> getOpeningStock(
      String? selectedClass) async {
    final db = await database;
    if (selectedClass == null || selectedClass.isEmpty) {
      return [];
    }
    return await db.query(
      'OpeningStock',
      where: 'class = ?',
      whereArgs: [selectedClass],
    );
  }

  Future<List<Map<String, dynamic>>> getAllRiceGrainRecord(
      String? selectedClass) async {
    final db = await database;
    return await db.query(
      'RiceGrainRecord',
      where: 'class = ?',
      whereArgs: [selectedClass],
    );
  }

  Future<List<Map<String, dynamic>>> getRiceGrainRecord(
      String selectedDate, String? selectedClass) async {
    final db = await database;
    if (selectedDate.isEmpty &&
        (selectedClass == null || selectedClass.isEmpty)) {
      return [];
    }

    return await db.query(
      'RiceGrainRecord',
      where: 'received_date = ? AND class = ?',
      whereArgs: [selectedDate, selectedClass],
    );
  }

  Future<List<Map<String, dynamic>>> getAllAttendance() async {
    final db = await database;
    return await db.query('Attendance');
  }

  Future<List<Map<String, dynamic>>> getMonthlyAttendance(
      String selectedMonth) async {
    // Extract the month and year from the parameter
    List<String> parts = selectedMonth.split(" ");
    String monthName = parts[0];
    int year = int.parse(parts[1]);
    // Convert the month name to its corresponding number
    int month = DateFormat('MMMM').parse(monthName).month;
    // Construct the start and end date for the given month
    String startDate = "$year-${month.toString().padLeft(2, '0')}-01";
    String endDate = DateTime(year, month + 1, 0)
        .toIso8601String()
        .split("T")[0]; // Get the last day of the month

    final db = await database;

    // Use a raw query to reformat the `date` field in SQLite
    return await db.rawQuery('''
    SELECT * FROM Attendance
    WHERE 
      date(substr(date, 7, 4) || '-' || substr(date, 4, 2) || '-' || substr(date, 1, 2)) 
      BETWEEN ? AND ?
  ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getAttendance(
      String selectedDate, String selectedDay, String selectedClass) async {
    final db = await database;
    if (selectedDate.isEmpty && selectedDay.isEmpty && selectedClass.isEmpty) {
      return [];
    }

    return await db.query(
      'Attendance',
      where:
          'date = ? AND day = ? AND class= ?', // Update based on the received_date
      whereArgs: [selectedDate, selectedDay, selectedClass],
    );
  }
// Future<List<Map<String, dynamic>>> getRiceGrainRecordByDate(String selectedDate) async {
//   final db = await database;

//   // Query records where the received_date matches the selected date
//   return await db.query(
//     'RiceGrainRecord',
//     where: 'received_date = ?',
//     whereArgs: [selectedDate],
//   );
//}
  Future<List<Map<String, dynamic>>> getRiceGrainsPerStudentRecord(
      String? selectedClass) async {
    final db = await database;
    if (selectedClass == null || selectedClass.isEmpty) {
      return [];
    }
    return await db.query(
      'RiceGrainsPerStudent',
      where: 'class = ?',
      whereArgs: [selectedClass],
    );
  }

  Future<List<Map<String, dynamic>>> getAllRiceGrainsPerStudentRecord() async {
    final db = await database;
    return await db.query(
      'RiceGrainsPerStudent',
    );
  }

  Future<void> insertRiceGrainRecords(
      List<Map<String, dynamic>> records) async {
    var receivedDate = records.first['received_date'].toString();
    var classValue = records.first['class'].toString();
    final db = await database;
    List<Map<String, dynamic>> existingRecord =
        await getRiceGrainRecord(receivedDate, classValue);

    await db.transaction((txn) async {
      if (existingRecord.isEmpty) {
        for (var record in records) {
          await txn.insert(
            'RiceGrainRecord',
            record,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        // Update the existing record for this receivedDate
        for (var record in records) {
          await txn.update(
            'RiceGrainRecord',
            record,
            where:
                'received_date = ? AND itemid = ? AND class= ?', // Update based on the received_date
            whereArgs: [receivedDate, record.values.elementAt(1), classValue],
          );
        }
      }
    });
  }

  Future<void> insertRiceGrainsPerStudentRecords(
      List<Map<String, dynamic>> records) async {
    var classValue = records.first['class'].toString();
    final db = await database;
    List<Map<String, dynamic>> existingRecord =
        await getRiceGrainsPerStudentRecord(classValue);

    await db.transaction((txn) async {
      if (existingRecord.isEmpty) {
        for (var record in records) {
          await txn.insert(
            'RiceGrainsPerStudent',
            record,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        // Update the existing record for this class
        for (var record in records) {
          await txn.update(
            'RiceGrainsPerStudent',
            record,
            where: 'class = ? AND itemid = ?', // Update based on the class
            whereArgs: [classValue, record.values.elementAt(1)],
          );
        }
      }
    });
  }

  Future<void> insertAttendance(List<Map<String, dynamic>> records) async {
    var selectedDate = records.first['date'].toString();
    var selectedDay = records.first['day'].toString();
    var selectedClass = records.first['class'].toString();

    final db = await database;
    List<Map<String, dynamic>> existingRecord =
        await getAttendance(selectedDate, selectedDay, selectedClass);

    await db.transaction((txn) async {
      if (existingRecord.isEmpty) {
        for (var record in records) {
          await txn.insert(
            'Attendance',
            record,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        // Update the existing record for this receivedDate
        for (var record in records) {
          await txn.update(
            'Attendance',
            record,
            where:
                'date = ? AND day = ? AND class= ?', // Update based on the received_date
            whereArgs: [selectedDate, selectedDay, selectedClass],
          );
        }
      }
    });
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
