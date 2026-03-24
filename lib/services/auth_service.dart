import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseurl ="http://10.0.2.2:5000";

  ///register
  static Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
})
  async{
    final url =
        Uri.parse("$baseurl/register");
        print("sending request to: $url");
    final response =
        await http.post(
          url,
          headers:{
            "content-type":"application/json"
          },
          body: jsonEncode({
            "name": name,
            "email": email,
            "password":password,
          })
        );
        print("status code: ${response.statusCode}");
        print("response body: ${response.body}");

        if (response.statusCode == 200){
          return true;
        }
        else{
          return false;
        }
  }

  /// LOGIN
  static Future<bool> loginUser({
    required String email,
    required String password,
})
  async{
    final url =
        Uri.parse("$baseurl/login");
    final response =
        await http.post(
          url,
          headers:{
            "content-type":"application/json"
          },
          body: jsonEncode({
            "email": email,
            "password":password,
          }),
        );
        if (response.statusCode == 200){
          return true;
        }
        else{
          return false;
        }
  }
}