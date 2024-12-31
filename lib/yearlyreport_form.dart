import 'package:flutter/material.dart';
import 'package:spa/yearlyreportselection.dart';

class YearlyReportForm extends StatelessWidget {
  const YearlyReportForm({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16.0),
      crossAxisSpacing: 16.0,
      mainAxisSpacing: 16.0,
      children: [
        _buildGridItem(
          Icons.pie_chart, // Updated icon for Yearly Report
          'वार्षिक अहवाल',
          context,
        ),
      ],
    );
  }

  Widget _buildGridItem(IconData icon, String title, BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (title == 'वार्षिक अहवाल') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const YearlyReportSelection()),
          );
        }
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 60,
              color: Colors.blue,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
