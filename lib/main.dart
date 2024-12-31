import 'package:flutter/material.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'package:spa/balance_form.dart';
import 'package:spa/profile.dart';
import 'package:spa/rice_grain_record_form.dart';
import 'package:spa/rice_grains_ perstudent_form.dart';
import 'package:spa/attendance_form.dart';
import 'database_helper.dart';
import 'package:spa/logviewer.dart';
import 'package:spa/monthlyreport_form.dart';
//import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:spa/logToFile.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spa/api_services.dart';
import 'package:spa/deviceInfo.dart';
import 'package:spa/SPAUserModel.dart';
import 'package:spa/yearlyreport_form.dart';

void main() async {
  // Initialize locale data
  await initializeDateFormatting('mr', null);
  WidgetsFlutterBinding.ensureInitialized();
  //await DatabaseHelper.instance.resetDatabase();
  await DatabaseHelper().database; // Initialize the database
  await dotenv.load(fileName: "assets/config/.env");
  bool isProfileComplete = await _checkProfileCompletion();
  runApp(ShaleyaPoshanApp(isProfileComplete: isProfileComplete));
}

Future<bool> _checkProfileCompletion() async {
  try {
    String? deviceId = await Deviceinfo.getDeviceId();

    ApiServices apiServices = ApiServices();
    SPAUserModel? result = await apiServices.fetchSPAUser(deviceId);
    if (result != null && result.paymentId != null) {
      List<Map<String, dynamic>> rows =
          await DatabaseHelper.instance.getProfiles();
      return rows.isNotEmpty;
    }
  } catch (error) {
    logMessage("Failed to load Profile: $error");
  }
  return false;
}

class ShaleyaPoshanApp extends StatelessWidget {
  final bool isProfileComplete;
  const ShaleyaPoshanApp({super.key, required this.isProfileComplete});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shaleya Poshan',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue, // AppBar background color
          foregroundColor: Colors.white, // AppBar text/icon color
          elevation: 4,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.blue, // BottomNavigationBar background color
          selectedItemColor: Colors.white, // Color for selected items
          unselectedItemColor: Colors.white70, // Color for unselected items
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue, // Floating Action Button color
          foregroundColor: Colors.white, // Floating Action Button icon color
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, // Elevated Button color
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.blue.shade50,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black54),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
      home: isProfileComplete ? const HomeScreen() : const ProfileForm(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const RecordScreen(),
    const MonthlyReportScreen(),
    const YearlyReportScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _checkProfileCompletion() async {
    try {
      List<Map<String, dynamic>> rows =
          await DatabaseHelper.instance.getProfiles();
      return rows.isNotEmpty;
    } catch (error) {
      logMessage("Failed to load Profile: $error");
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('शालेय पोषण', style: TextStyle(fontSize: 22)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: () {
            // Navigate to Profile Screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileForm()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () {
              // Action for Help button
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Help'),
                    content: const Text('This is the help section.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          //Navigator.of(context).pop();
                          // Navigate to Profile Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LogViewer()),
                          );
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'नोंद विभाग',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'मासिक अहवाल',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'वार्षिक अहवाल',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildGridItem(Icons.list, 'आरंभीची शिल्लक नोंदवा', context),
        _buildGridItem(Icons.person, 'दैनिक उपस्थिती नोंदवा', context),
        _buildGridItem(Icons.shopping_cart, 'प्राप्त धान्य नोंद करा', context),
        _buildGridItem(Icons.people, 'विद्यार्थी पट नोंदवा', context),
        _buildGridItem(Icons.calculate, 'धान्याचे प्रमाण नोंदवा', context),
        _buildGridItem(Icons.info, 'आमच्या विषयी', context),
      ],
    );
  }

  Widget _buildGridItem(IconData icon, String title, BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to different pages based on selection
        if (title == 'आरंभीची शिल्लक नोंदवा') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BalanceForm()),
          );
        } else if (title == 'प्राप्त धान्य नोंद करा') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const RiceGrainRecordForm()),
          );
        } else if (title == 'धान्याचे प्रमाण नोंदवा') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const RiceGrainsPerStudentForm()),
          );
        } else if (title == 'दैनिक उपस्थिती नोंदवा') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AttendanceForm()),
          );
        }
      },
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.blue),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class MonthlyReportScreen extends StatelessWidget {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonthlyReportForm();
  }
}

class YearlyReportScreen extends StatelessWidget {
  const YearlyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const YearlyReportForm();
  }
}
