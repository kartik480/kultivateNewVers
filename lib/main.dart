import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main(){
  runApp(app());
}
class app extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      home: LoginScreen(),
    );
  }
}