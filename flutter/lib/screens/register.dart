import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/authController.dart';

class RegisterPage extends StatefulWidget {
  RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthController controller = Get.find();
  late List<Map<String, dynamic>> registerField;
  late List<Map<String, dynamic>> registerButton;
  bool passwordVisible = false;

  @override
  void initState() {
    super.initState();
    registerField = [
      { 'label': 'Display Name', 'key': 'name', 'icon': Icons.person, 'controller': TextEditingController(), 'validator': (value) => value!.isEmpty ? 'Required' : null },
      { 'label': 'Email', 'key': 'email', 'icon': Icons.email, 'controller': TextEditingController(),  'validator': (value) => value!.isEmpty ? 'Required' : null },
      { 'label': 'Password', 'key': 'password', 'icon': Icons.password, 'controller': TextEditingController(),  'validator': (value) => value!.isEmpty ? 'Required' : null },
      { 'label': 'Confirm Password', 'key': 'password2', 'icon': Icons.password, 'controller': TextEditingController(),  'validator': (value) => value!.isEmpty ? 'Required' : null }
    ];
    registerButton = [
      { 'label': 'Register', 'action': () { /* Handle registration logic here */ }, },
      { 'label': 'Back', 'action': () { Get.back(); }, }, 
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
                'Register Page',
                style: TextStyle(fontSize: 24),
              ),
              ...registerField.map((field) => Padding(
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
                    suffixIcon: field['key'] == 'password' || field['key'] == 'password2'
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                passwordVisible = !passwordVisible;
                              });
                            },
                            icon: Icon(
                              passwordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Theme.of(context).primaryColorDark,
                            ),
                          )
                        : null,
                  ),
                  validator: (value) => value == null ? 'Required' : null,
                  obscureText: (field['key'] == 'password' || field['key'] == 'password2') ? !passwordVisible : false,
                ),
              )),
              const SizedBox(height: 20),
              ...registerButton.map((btn) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: ElevatedButton(
                  onPressed: () {
                    if (btn['label'] == 'Register') {    
                      if (registerField[2]['controller'].text != registerField[3]['controller'].text) {
                        Get.snackbar('Error', 'Passwords do not match');
                        return;
                      }
                      if (registerField.any((field) => field['controller'].text.isEmpty)) {
                        Get.snackbar('Error', 'Please fill all fields');
                        return;
                      }            
                      if (!GetUtils.isEmail(registerField[1]['controller'].text)) {
                        Get.snackbar('Error', 'Invalid email format');
                        return;
                      } 
                      controller.register(
                        registerField[1]['controller'].text,
                        registerField[2]['controller'].text,
                        registerField[0]['controller'].text,
                      );
                      
                    } else if (btn['label'] == 'Back') {
                      Get.back();
                    }
                  },
                  child: Text(btn['label'] as String),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
