import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class LogViewer extends StatefulWidget {
  const LogViewer({super.key});
  @override
  _LogViewerState createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  String logContent = "Loading logs...";

  @override
  void initState() {
    super.initState();
    _loadLogFile();
  }

  Future<void> _loadLogFile() async {
    try {
      // Get the application's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_logs.txt');

      // Check if the file exists
      if (await file.exists()) {
        // Read the contents of the file
        String contents = await file.readAsString();
        setState(() {
          logContent = contents;
        });
      } else {
        setState(() {
          logContent = "Log file not found.";
        });
      }
    } catch (e) {
      setState(() {
        logContent = "Error loading logs: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Viewer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Text(
            logContent,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
