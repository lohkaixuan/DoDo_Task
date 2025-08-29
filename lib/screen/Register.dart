import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  
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
                  obscureText: true,
                ),
              ),
              const SizedBox(
                width: 300,
                height: 60,
                child: TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Confirm your password',
                  ),
                  obscureText: true,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Handle registration logic here
                },
                child: const Text('Register'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Handle registration logic here
                  Get.back();
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}