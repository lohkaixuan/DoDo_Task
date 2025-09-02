import 'package:dodotask/controller/AuthController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginPage extends StatefulWidget{
  LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthGetxController controller = Get.find();
  late List<Map<String, dynamic>> loginField;//have a kosong container first
  late List<Map<String, dynamic>> loginButton;
  bool passwordVisible = false;

  @override
  void initState() {
    super.initState();
    loginField = [
      { 'label': 'Email', 'key': 'email', 'icon': Icons.email, 'controller': TextEditingController(),  'validator': (value) => value!.isEmpty ? 'Required' : null },
      { 'label': 'Password', 'key': 'password', 'icon': Icons.password, 'controller': TextEditingController(),  'validator': (value) => value!.isEmpty ? 'Required' : null }
    ];
    loginButton = [
      { 'label': 'Login', 'action': () { /* Handle login logic here */ }, },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Login Page',
                style: TextStyle(fontSize: 24),
              ),
              ...loginField.map((field) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextFormField(
                  keyboardType: field['key'] == 'email'
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  controller: field['controller'] ,
                  decoration: InputDecoration(
                    labelText: field['label'] as String,
                    prefixIcon: Icon(field['icon'] as IconData),
                    border: const OutlineInputBorder(),
                    suffixIcon: field['key'] == 'password'
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                passwordVisible = !passwordVisible;
                              });
                            },
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility : Icons.visibility_off,
                            ),
                          )
                        : null,
                  ),
                  validator: field['validator'] as String? Function(String?)?,
                  obscureText: field['key'] == 'password' ? !passwordVisible : false,
                ),
                )),
              const SizedBox(height: 20),
              ...loginButton.map((button) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: ElevatedButton(
                  onPressed: () {
                    if(button['label'] == 'Login'){
                                          if (loginField.any((field) => field['controller'].text.isEmpty)) {
                      Get.snackbar('Error', 'Please fill all fields');
                      return;
                    }            
                    if (!GetUtils.isEmail(loginField[0]['controller'].text)) {
                      Get.snackbar('Error', 'Invalid email format');
                      return;
                    } 
                      controller.login(
                        loginField[0]['controller'].text,
                        loginField[1]['controller'].text,
                      );
                    }
                  },
                  child: Text(button['label'] as String,
                ),
              ))),
              const Text(
                'New User?',
              ),
              GestureDetector(
                child: const Text("Sign Up"),
                onTap: () {
                Get.toNamed('/register');
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}