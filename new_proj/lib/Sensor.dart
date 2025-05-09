import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:new_proj/Alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:async';

//Provides a visual representation of sensor data using a line chart. It's connected to other parts of the app through navigation, ensuring a cohesive and interactive user experience.
void main() {
  runApp(const Sensor());
}

class Sensor extends StatelessWidget {
  const Sensor({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sensor Chart App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SensorChartPage(),
    );
  }
}

class SensorChartPage extends StatefulWidget {
  const SensorChartPage({super.key});

  @override
  _SensorChartPageState createState() =>
      _SensorChartPageState(); //Creates the mutable state for this widget
}

class _SensorChartPageState extends State<SensorChartPage> {
  List<FlSpot> sensor1Data = [];
  List<FlSpot> sensor2Data = [];
  var nSensors = 1;
  late Timer timer;
  double timeLimit = 10;
  var readingNormalNoise;
  var readingTolerationNoise;
  bool dataLoaded = false; //Flag to check if data is loaded
  Color sensor1Color = Colors.green;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Chart'),
      ),
      body: Center(
        child: dataLoaded
            ? Padding(
                padding:
                    const EdgeInsets.all(16.0), //Padding around the LineChart
                child: LineChart(
                  LineChartData(
                    minY: 00, // Limite inferior do eixo Y
                    maxY: readingNormalNoise * 1.5, // Limite superior do eixo Y
                    lineBarsData: [
                      //Data for the lines in the chart
                      LineChartBarData(
                        spots: sensor1Data, //Data points for the first sensor
                        isCurved: false, //Curved line
                        barWidth: 2, //Width of the line
                        //colors: [Colors.blue], //Color of the line
                        colors: [sensor1Color], // Usa a cor dinâmica
                      ),
                      LineChartBarData(
                        spots: sensor2Data, //Data points for the second sensor
                        isCurved: false,
                        barWidth: 2,
                        colors: [Colors.red],
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles:
                          SideTitles(showTitles: true), //Show left titles
                      bottomTitles: SideTitles(showTitles: true),
                      rightTitles:
                          SideTitles(showTitles: false), //Hide right titles
                      topTitles: SideTitles(showTitles: false),
                    ),
                    gridData: FlGridData(show: true), //show grid in the chart
                    // Adiciona uma linha horizontal vermelha no valor 25
                    extraLinesData: ExtraLinesData(horizontalLines: [
                      HorizontalLine(
                        y: readingNormalNoise + readingTolerationNoise, //AQUI
                        color: Colors.blue,
                        strokeWidth: 2,
                        dashArray: [10, 5], // Linha pontilhada
                      ),
                    ]),
                  ),
                ),
              )
            : const CircularProgressIndicator(), // mostra loading se ainda não carregou
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
          child: const Text('Mensagens'), //Button text
        ),
      ),
    );
  }

  @override
  void initState() {
    const interval = Duration(seconds: 1);
    timer = Timer.periodic(interval, (Timer t) {
      getReadings();
    });
    super.initState();
  }

  getReadings() async {
    sensor1Data.clear();
    sensor2Data.clear();
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');
    String? ip = prefs.getString('ip');
    String? port = prefs.getString('port');
    int? idJogo = prefs.getInt('idJogo');
    print("idJogo getReadings(): $idJogo");
    for (int id = 1; id <= nSensors; id++) {
      String readingsURL = "http://$ip:$port/getSensors.php";
      var response = await http.post(Uri.parse(readingsURL), body: {
        'username': username,
        'password': password,
        'sensor': (id).toString(),
        'jogo': (idJogo).toString()
      });

      var flaglimit = 0;
      if (response.statusCode == 200) {
        print("Resposta bruta do PHP Sensors: ${response.body}");
        var jsonData = json.decode(response.body);
        if (jsonData != null && jsonData.length > 0) {
          DateTime readingTime;
          DateTime currentTime;
          double timeDiff;

          for (var reading in jsonData) {
            readingNormalNoise =
                double.parse(reading["normalnoise"].toString());
            print("Normal noise getReadings(): $readingNormalNoise");
            //readingTolerationNoise= double.parse(reading["noisevartoteration"].toString());
            readingTolerationNoise = readingNormalNoise * 0.15;
            readingTime = DateTime.parse(reading["Hour"].toString());
            print("Hour getReadings(): $readingTime");
            currentTime = DateTime.now()
                .add(const Duration(hours: 1)); // correct time to GMT+0
            timeDiff = currentTime.difference(readingTime).inSeconds.toDouble();
            //if (timeDiff >= 0.0 && timeDiff < timeLimit) {
            if (timeDiff.isFinite) {
              if (timeDiff >= 0.0) {
                var value = double.parse(reading["Sound"].toString());
                print("Sound getReadings(): $value");
                sensor1Color = Colors.green;
                //print(readingNormalNoise);
                //print(readingTolerationNoise);
                if (value > readingNormalNoise + (readingTolerationNoise / 2)) {
                  flaglimit = 1;
                }
                switch (id) {
                  case 1:
                    if (!sensor1Data.contains(FlSpot(timeDiff, value))) {
                      sensor1Data.add(FlSpot(timeDiff, value));
                      // correct id so it start at 0 and not 1
                    }
                    break;
                  case 2:
                    if (!sensor2Data.contains(FlSpot(timeDiff, value))) {
                      sensor2Data.add(FlSpot(timeDiff, value));
                    }
                    break;
                }
              }
            }
          }
        }
        if (flaglimit == 1) {
          sensor1Color = Colors.red;
          print("RED");
        } else {
          sensor1Color = Colors.green;
          //print ("GREEN");
        }
        print("readingNormalNoise getReadings(): $readingNormalNoise");
        print("readingTolerationNoise getReadings(): $readingTolerationNoise");
        print("dataLoaded getReadings(): $dataLoaded");
        if (readingNormalNoise != null &&
            readingTolerationNoise != null &&
            !dataLoaded) {
          setState(() {
            dataLoaded = true;
          });
        }
      } else {
        print(
            'Failed to load data: ${response.statusCode}'); // Handle the error
      }
    }
  }
}
