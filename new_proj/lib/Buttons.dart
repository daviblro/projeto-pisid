import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'Alerts.dart';

void main() {
  runApp(const Buttons());
}

 void _showValueDialog(BuildContext context, String decoded) {
    // Valor a ser exibido
    String valueToDisplay = decoded;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pontuação'),
          content: Text(valueToDisplay),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o dialog
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

class Buttons extends StatelessWidget {
  const Buttons({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,  //Disables the debug banner
      title: 'Stored Procedures App',  
      theme: ThemeData(
        primarySwatch: Colors.blue,  //Defines the theme color
      ),
      home: const StoredProceduresPage(),  //Defines the Home page of the app
    );
  }
}

class StoredProceduresPage extends StatefulWidget {
  const StoredProceduresPage({super.key});
 
  @override
  _StoredProceduresPageState createState() => _StoredProceduresPageState();  //Creates and returns the state object
}

class _StoredProceduresPageState extends State<StoredProceduresPage> {
  //Text editing controllers for input fields
  final TextEditingController SalaOrigemController = TextEditingController();
  final TextEditingController SalaDestinoController = TextEditingController();




@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Center(
        child: Text('Stored Procedures'),  //Title of the app bar
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center( // Wrap Column with Center
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
          children: <Widget>[
            const SizedBox(height: 30), //Spacer
            //Elevated buttons for different actions 
            ElevatedButton(
              onPressed: () => _showArgumentDialog('IniciarJogo.php', [], [], context),
              child: const Text('Iniciar jogo'),
            ),
            ElevatedButton(
              onPressed: () => _showArgumentDialog('abrirPorta.php', ["Sala de Origem", "Sala de Destino"], [SalaOrigemController,SalaDestinoController], context),
              child: const Text('Abrir porta'),
            ),
            ElevatedButton(
              onPressed: () => _showArgumentDialog('fecharPorta.php', ["Sala de Origem", "Sala de Destino"], [SalaOrigemController,SalaDestinoController], context),
              child: const Text('Fechar porta'),
            ),
            ElevatedButton(
              onPressed: () => _showArgumentDialog('abrirTodasPortas.php', [], [], context),
              child: const Text('Abrir todas as portas'),
            ),
            ElevatedButton(
              onPressed: () => _showArgumentDialog('fecharTodasPortas.php', [], [], context),
              child: const Text('Fechar todas as portas'),
            ),
            ElevatedButton(
              onPressed: () => _showArgumentDialog('triggerSala.php', ["Sala:"], [SalaOrigemController], context),
              child: const Text('Trigger uma sala'),
            ),            
            ElevatedButton(
              onPressed: () => _showArgumentDialog('obterPontuacao.php', [], [], context),
              child: const Text('Obter Pontuação'),
            ),

          ],
        ),
      ),
    ),
    bottomNavigationBar: BottomAppBar(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Mensagens()),  //Navigate to the 'Mensagens' screen
          );
        },
        child: const Text('Mensagens'),  //Button text
      ),
    ),
  );
}


  Future<void> _showArgumentDialog(String script, List<String> argLabels, List<TextEditingController> controllers, BuildContext context) async {
  if(argLabels.isEmpty) {
    return _getDataWithArgs(script, [], [], context); //If there are no arguments, directly fetch data
  }
  assert(argLabels.length == controllers.length);  //Ensure labels and controllers match
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Enter Arguments'),  //Dialog title
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,  //Adjust column size
            children: List.generate(
              argLabels.length,
              (index) => TextField(
                controller: controllers[index],  //Input field for each argument
                decoration: InputDecoration(labelText: argLabels[index]),  //label for each input field
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _getDataWithArgs(script, argLabels, controllers,  context);  //Fetch data with arguments
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

Future<void> _getDataWithArgs(String script,  List<String> argLabels, List<TextEditingController> controllers, BuildContext context) async {  //Method to fetch data with arguments
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');
    String? ip = prefs.getString('ip');
    String? port = prefs.getString('port');

    String readingsURL = "http://${ip!}:${port!}/scripts/php/$script";
    Map<String,String?> body = {'username': username, 'password': password,};
    for (int index = 0; index < argLabels.length; index++) {
      String value = "null";
      if(controllers[index].text!=""){value = '"${controllers[index].text}"';}
      body[argLabels[index]] = value;
      controllers[index].text = "";  //Clears the controller
    }
    var response = await http.post(Uri.parse(readingsURL), body: body);
    if (response.statusCode == 200) {
      var decoded = json.decode(response.body);
      _showValueDialog(context, decoded.toString());
      print("sucesss");
    }
  }
}
