import 'package:flutter/material.dart';
import 'package:spa/monthlyreportselection.dart';
import 'package:spa/PraPatraFormB.dart';

class MonthlyReportForm extends StatelessWidget {
  const MonthlyReportForm({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16.0),
      crossAxisSpacing: 16.0,
      mainAxisSpacing: 16.0,
      children: [
        _buildGridItem(
          Icons.book, // Replace with appropriate icon
          'Monthly Report Type A',
          context,
        ),
        _buildGridItem(
          Icons.book_outlined,
          'Monthly Report Type B',
          context,
        )
        // ,
        // _buildGridItem(
        //   Icons.insert_chart, // Replace with appropriate icon
        //   'Monthly Report Type A',
        //   context,
        // ),
        // _buildGridItem(
        //   Icons.insert_chart_outlined,
        //   'Monthly Report Type B',
        //   context,
        // ),
      ],
    );
  }

  Widget _buildGridItem(IconData icon, String title, BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (title == 'Monthly Report Type A') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MdmRegExportForm()),
          );
        } else if (title == 'Monthly Report Type B') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PraPatraFormB()),
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
