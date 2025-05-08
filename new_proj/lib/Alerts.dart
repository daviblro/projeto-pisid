import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:async';
import './Movement.dart';
import './Sensor.dart';
import 'Buttons.dart';

class Mensagens extends StatelessWidget {
  //sets up the main structure for the 'Mensagens' screen
//class Mensagens extends StatefulWidget {
  const Mensagens({super.key});
  @override
  Widget build(BuildContext context) {
    //builds the UI for the 'Mensagens' screen.
    const appTitle = 'Mensagens';

    return Scaffold(
      //Uses a 'scaffold' widget to provide a basic material design layout structure, including an 'AppBar' with the title 'Mensagens' and the main body containing the 'MensagensMain' widget.
      appBar: AppBar(
        centerTitle: true,
        title: const Text(appTitle),
      ),
      body: const MensagensMain(),
    );
  }
}

class MensagensMain extends StatefulWidget {
  //represents the main content area of the 'Mensagens' screen.
  const MensagensMain({super.key});
  @override
  MensagensMainState createState() {
    //creates and returns an instance of 'MensagensMainState', which will hold the mutable state for 'MensagensMain'
    return MensagensMainState();
  }
}

class MensagensMainState extends State<MensagensMain> {
  //State object for the 'MensagensMain' widget
  int currentIndex = 2; //Current index for navigation
  late Timer timer; //Timer for periodic updates
  DateTime selectedDate = DateTime.now(); //Selected date for filtering messages
  var mostRecentMensagens = 0; //Most recent messages counter

  //Fields for the data table
  var tableFields = [
    'Msg',
    'Leitura',
    'Sensor',
    'TipoMensagem',
    'Hora',
    'HoraEscrita'
  ];
  var tableMensagens = <int, List<String>>{};

  int _selectedIndex = 0; //Index of the selected navigation item

  Future<void> _onItemTapped(int index) async {
    //Method called when a navigation item is tapped
    setState(() {
      _selectedIndex = index;
    });
    mostRecentMensagens = 0;
    tableMensagens.clear();
    //Navigate to different screens based on what the index is
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Sensor()),
      );
    }
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Buttons()),
      );
    }
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Movement()),
      );
    }
  }

  @override
  void initState() {
    //Initializes the state of the widget and sets up a periodic timer to fetch messages
    const oneSec = Duration(seconds: 1); //Interval for the timer
    timer = Timer.periodic(
        oneSec, (Timer t) => getMensagens()); //Periodically fetch messages
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical, //Allows vertical scrolling
          child: Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal, //Allows horizontal scrolling
                child: DataTable(
                  columns: listFields(), //List of data columns
                  rows: listMensagens(), //List of data rows
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
            backgroundColor:
                Colors.blue, //background color of the navigation bar
            iconSize: 40, //Size of the icons
            selectedFontSize: 16, //Font size of selected item labels
            unselectedFontSize: 16, //Font size of unselected item labels
            showSelectedLabels: true, //Show labels for selected items
            showUnselectedLabels: true, //how labels for unselected items
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.sensors),
                label: 'Sensor Sound',
                backgroundColor: Colors.blue,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.update),
                label: 'Procedures',
                backgroundColor: Colors.blue,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard),
                label: 'Marsami/Room',
                backgroundColor: Colors.blue,
              ),
            ],
            type: BottomNavigationBarType.fixed, //Fixed type navigation bar
            currentIndex: _selectedIndex, //Index of the currently selected item
            selectedItemColor: Colors.black, //Color of the selected items
            unselectedItemColor: Colors.black, //Color of the unselected items
            //iconSize: 40,
            onTap: _onItemTapped, //Callback for item taps
            elevation: 5 //Elevation of the navigation bar
            ));
  }

  selectDate(BuildContext context) async {
    //Method to select a date using a date picker
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: selectedDate, //initially selected date
      firstDate: DateTime(selectedDate.year - 2), //Sart of date range
      lastDate: DateTime(selectedDate.year + 2), //End of date range
    );
    if (selected != null && selected != selectedDate) {
      setState(() {
        selectedDate = selected;
      });
      getMensagens(); //Fetch messages for the selected date
    }
  }

  //Method to fetch Messages from the server
  getMensagens() async {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? ip = prefs.getString('ip');
    String? port = prefs.getString('port');
    String? password = prefs.getString('password');
    String MensagensURL = "http://${ip!}:${port!}/getMsgs.php";
    var response = await http.post(Uri.parse(MensagensURL),
        body: {'username': username, 'password': password});
    if (response.statusCode == 200) {
      var jsonData = json.decode(response.body);
      print("Resposta bruta do PHP Mensagens: ${response.body}");
      var Mensagens = jsonData["mensagens"];
      if (Mensagens != null && Mensagens.length > 0) {
        setState(() {
          tableMensagens.clear();
          for (var i = 0; i < Mensagens.length; i++) {
            Map<String, dynamic> newMensagens = Mensagens[i];
            int timeKey = int.parse(newMensagens["Hora"]
                .toString()
                .split(" ")[1]
                .replaceAll(":", ""));
            var MensagensValues = <String>[];
            for (var key in newMensagens.keys) {
              if (newMensagens[key] == null) {
                MensagensValues.add("");
              } else {
                MensagensValues.add(newMensagens[key]);
              }
            }
            tableMensagens[timeKey] = MensagensValues;
          }
        });
      }
    }
  }

  listMensagens() {
    //Method to generate data rows for the data table
    var MensagensList = <DataRow>[];
    if (tableMensagens.isEmpty) return MensagensList;
    for (var i = tableMensagens.length - 1; i >= 0; i--) {
      var key = tableMensagens.keys.elementAt(i);
      var MensagensRow = <DataCell>[];
      tableMensagens[key]?.forEach((MensagensField) {
        if (i == 0) {
          MensagensRow.add(DataCell(Text(MensagensField,
              style: const TextStyle(color: Colors.blue))));
        } else {
          MensagensRow.add(DataCell(Text(MensagensField)));
        }
      });
      MensagensList.add(DataRow(cells: MensagensRow));
    }
    mostRecentMensagens =
        tableMensagens.keys.elementAt(tableMensagens.length - 1);
    return MensagensList.reversed.toList();
  }

  listFields() {
    //Method to generate data columns for the data table
    var fields = <DataColumn>[];
    for (var field in tableFields) {
      fields.add(
          DataColumn(label: Text(field))); //Create a DataColumn for each field
    }
    return fields;
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }
}
