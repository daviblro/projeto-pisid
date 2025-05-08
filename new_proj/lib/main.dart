import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'Alerts.dart';

void main() {
  runApp(const LoginApp());
}

class LoginApp extends StatelessWidget {
  //Root Widget of the Application (StatelessWidget is unmutable, used for static UI components like icons, text and static layouts) this class sets up the overall structure and configuration of the app.
  const LoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false, //hides the debug banner typically shown in debug mode
      title: 'Login App',
      theme: ThemeData(
        //provides consistent theming across the app
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(), //sets the initial screen to the LoginPage
    );
  }
}

class LoginPage extends StatefulWidget {
  // This widget needs to manage user input, show a loading indicator while performing a login operation, and possibly update the UI based on the login response. (StatefulWidget has a mutable state. Suitable for dynamic UI components that need to change according to user interaction, like forms, animations and real.time updates)
  const LoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  //state management class for the 'LoginPage' widget+

  final usernameController = TextEditingController(
      text: "teste@gmail.com"); //controller that manages input for the username
  final passwordController = TextEditingController(
      text: "teste"); //controller that manages the input for the password
  final ipController = TextEditingController(
      text: "10.0.2.2"); //controller that manages input for the IP address
  final portController = TextEditingController(
      text: "80"); //controller that manages input for the port
  final bool _isLoading =
      false; //boolean variable that tracks whether a login attempt is in progress or not. It's used to show a loading indicator when the login button is pressed.

  @override
  Widget build(BuildContext context) {
    //builds the UI of the login page.
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 50),
              const Text(
                'PISID',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                //input field for the username
                controller: usernameController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 20),
              TextFormField(
                //input field for the password
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              TextFormField(
                //input field for the IP address
                controller: ipController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'IP (xxx.xxx...)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                //input field for the port
                controller: portController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Port Xamp',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30), //defines login button
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        validateLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 80.0),
                        child: Text('Login'),
                      ),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    //Dispose controllers when the widget is removed from the widget tree (as to free up resources)
    usernameController.dispose();
    passwordController.dispose();
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }

  validateLogin() async {
    String loginURL =
        "http://${ipController.text.trim()}:${portController.text.trim()}/validateLogin.php";
    print(loginURL);
    http.Response response = http.Response('', 400); //Default response
    try {
      //sending a POST request with the username and password
      response = await http.post(Uri.parse(loginURL), body: {
        'username': usernameController.text.trim(), //get the username text
        'password': passwordController.text.trim() //get password text
      });
      print("Resposta do servidor: ${response.body}");
    } catch (e) {
      //Shows alert dialog if the connection fails
      print("Status code: ${response.statusCode}");
      print("Body: ${response.body}");
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            content: Text("The connection to the database failed."),
          );
        },
      );
    }
    if (response.statusCode == 200) {
      //if the response is successful
      var jsonData = json.decode(response.body);
      if (jsonData["success"]) {
        //if login is successful then stores credentials in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', usernameController.text.trim());
        await prefs.setString('password', passwordController.text.trim());
        await prefs.setString('ip', ipController.text.trim());
        await prefs.setString('port', portController.text.trim());
        String? ip = ipController.text.trim();
        String? port = portController.text.trim();
        String gameIdURL = "http://$ip:$port/getIdJogo.php";

        var gameResponse = await http.post(Uri.parse(gameIdURL), body: {
          'username': usernameController.text.trim(),
          'password': passwordController.text.trim(),
        });

        if (gameResponse.statusCode == 200) {
          var gameData = json.decode(gameResponse.body);
          if (gameData["success"]) {
            int idJogo = int.parse(gameData["idJogo"]);
            await prefs.setInt('idJogo', idJogo);
            print("ID do jogo salvo: $idJogo");
          } else {
            print("Erro ao obter ID do jogo");
          }
        } else {
          print("Erro HTTP ao buscar jogo: ${gameResponse.statusCode}");
        }

        Navigator.pushReplacement(
          //Navigate to 'Mensagens' screen
          context,
          MaterialPageRoute(builder: (context) => const Mensagens()),
        );
      } else {
        //Shows alert dialog if login fails
        showDialog(
          context: context,
          builder: (context) {
            return const AlertDialog(
              content: Text("Mensagens"),
            );
          },
        );
      }
    }
  }
}
