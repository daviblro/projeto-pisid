import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:new_proj/Alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const Movement());
}

class Movement extends StatelessWidget {
  const Movement({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, //Disables debug banner
      title: 'Marsamis por Sala',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StackedBarChartPage(), //Home page of the app
    );
  }
}

class StackedBarChartPage extends StatefulWidget {
  const StackedBarChartPage({super.key});

  //for displaying the bar chart
  @override
  _StackedBarChartPageState createState() => _StackedBarChartPageState();
}

class _StackedBarChartPageState extends State<StackedBarChartPage> {
  List<BarChartGroupData> barGroups = []; //List of bar groups for the chart
  double maxY = 15.0; //Maximum value on the Y-axis
  List<double> oddValues = List.filled(11, 0.0); //Initial blue bar values
  List<double> evenValues = List.filled(11, 0.0); //Initial red bar values

  Future<void> getReadings() async {
    //Fetches readings and updates the chart data
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? ip = prefs.getString('ip');
    String? port = prefs.getString('port');
    String? password = prefs.getString('password');
    String MensagensURL = "http://${ip!}:${port!}/getMarsamiRoom.php";
    var response = await http.post(Uri.parse(MensagensURL),
        body: {'username': username, 'password': password});

    if (response.statusCode == 200) {
      print("Resposta bruta do PHP Marsamis: ${response.body}");
      var jsonData = json.decode(response.body);
      if (jsonData != null && jsonData.length > 0) {
        setState(() {
          //Simulated data fetching and chart data preparation
          for (int sala = 0; sala < 11; sala++) {
            try {
              var roomData = jsonData[sala];
              oddValues[sala] = double.parse(roomData["NumeroMarsamisOdd"]);
              evenValues[sala] = double.parse(roomData["NumeroMarsamisEven"]);
            } catch (e) {
              print('Error processing response: $e');
            }
          }
          maxY = (oddValues + evenValues).reduce(max) + 1;
          barGroups = [];
          for (int index = 0; index < oddValues.length; index++) {
            barGroups.add(
              BarChartGroupData(
                x: index + 1,
                barRods: [
                  BarChartRodData(
                    y: evenValues[index],
                    colors: [Colors.red], //Color for red bars
                  ),
                  BarChartRodData(
                    y: oddValues[index],
                    colors: [Colors.blue], //Color for blue bars
                  ),
                ],
              ),
            );
          }
        });
      }
    }
  }

  @override
  void initState() {
    //Initializes the state and fetches readings
    super.initState();
    getReadings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Marsamis por Sala'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: barGroups,
              titlesData: FlTitlesData(
                rightTitles: SideTitles(showTitles: false), //Hide right titles
                topTitles: SideTitles(showTitles: false), //Hide top titles
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const Mensagens()), //Navigate to 'Mensagens' screen
            );
          },
          child: const Text('Mensagens'),
        ),
      ),
    );
  }
}
