import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:v3/controller/authController.dart';
import 'package:v3/controller/walletController.dart';

class LoginPage extends StatefulWidget {
  LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthController controller = Get.find();
  late List<Map<String, dynamic>> loginField; //have a kosong container first
  late List<Map<String, dynamic>> loginButton;
  bool passwordVisible = false;

  @override
  void initState() {
    super.initState();
    loginField = [
      {
        'label': 'Email',
        'key': 'email',
        'icon': Icons.email,
        'controller': TextEditingController(),
        'validator': (value) => value!.isEmpty ? 'Required' : null
      },
      {
        'label': 'Password',
        'key': 'password',
        'icon': Icons.password,
        'controller': TextEditingController(),
        'validator': (value) => value!.isEmpty ? 'Required' : null
      }
    ];
    final authC = Get.find<AuthController>();
    loginButton = [
      {
        'label': 'Login',
        'action': () {
          authC.login(
            loginField[0]['controller'].text.trim(),
            loginField[1]['controller'].text,
          );
        },
      },
    ];
    if (Get.isRegistered<WalletController>()) {
      Get.find<WalletController>().fetchBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(
                image: const AssetImage('assets/logo.png'),
                height: 100,
                width: 100,
              ),
              const SizedBox(height: 10),
              const Text(
                'Login Page',
                style: TextStyle(fontSize: 24),
              ),
              ...loginField.map((field) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: TextFormField(
                      keyboardType: field['key'] == 'email'
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                      controller: field['controller'],
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
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              )
                            : null,
                      ),
                      validator: field['validator'],
                      obscureText:
                          field['key'] == 'password' ? !passwordVisible : false,
                    ),
                  )),
              const SizedBox(height: 20),
              ...loginButton.map((button) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: ElevatedButton(
                    onPressed: () {
                      if (button['label'] == 'Login') {
                        if (loginField
                            .any((field) => field['controller'].text.isEmpty)) {
                          Get.snackbar('Error', 'Please fill all fields');
                          return;
                        }
                        if (!GetUtils.isEmail(
                            loginField[0]['controller'].text)) {
                          Get.snackbar('Error', 'Invalid email format');
                          return;
                        }
                        controller.login(
                          loginField[0]['controller'].text.trim(),
                          loginField[1]['controller'].text.trim(),
                        );
                      }
                    },
                    child: Text(
                      button['label'] as String,
                    ),
                  ))),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'New User?  ',
                  ),
                  GestureDetector(
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Colors.blue,
                      ),
                    ),
                    onTap: () {
                      Get.toNamed('/register');
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
