import 'package:dodotask/main.dart';
import 'package:dodotask/screen/register.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

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
              const SizedBox(
                width: 300,
                height: 60,
                child: TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter your email',
                  ),
                ),
              ),
              const SizedBox(
                width: 300,
                height: 60,
                child: TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter your password',
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  textStyle: const TextStyle(
                    color: Colors.white)
                ),
                onPressed: () {},
                child: const Text('Login'),
              ),
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