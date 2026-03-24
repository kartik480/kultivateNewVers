import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:kultivate_new_ver/services/auth_service.dart';
import '../screens/home_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {


  final PageController _pageController = PageController();

  // Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final signUpEmailController = TextEditingController();
  final signUpPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                Color(0xFF0F1023),
                Color(0xFF1A1B3A),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _loginPage(),
                _signUpPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //login page
  Widget _loginPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 50),
        // 🌱 Logo
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.lightBlueAccent,
                    width: 2,
                  ),
                ),
                child: Image.asset(
                  'images/logo.png',
                  height: 100,
                  width: 100,
                ),
              ),

              SizedBox(height: 10),
              Text(
                "Kultivate",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Build Better Habits",
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          "Welcome Back",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,

          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Sign in to continue your journey",
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 25),
        _buildTextField(
          controller: emailController,
          hint: "Email",
          icon: Icons.email,
          isPassword: false,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: passwordController,
          hint: "Password",
          icon: Icons.lock,
          isPassword: true,
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: false,
                  onChanged: (value) {},
                ),
                const Text(
                  "Remember my Habit!",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            "Forgot Your Habit??",
            style: TextStyle(color: Colors.lightBlueAccent),

          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF00D9FF),
                Color(0xFF00D8FF),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ElevatedButton(
            onPressed: () async {
              bool success =
                  await AuthService.loginUser(
                    email: emailController.text,
                    password: passwordController.text,
                  );
                  if (success){
                    ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(
                       content: Text("Login Successful"),
                     ),
                    );
                    //going to home screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  }
                  else{
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Login Failed"),
                      ),
                    );
                  }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: const Text(
              "Login on-Habit on",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Row(
          children: const[
            Expanded(
              child: Divider(
                color: Colors.white24,
              ),
            ),
            Padding(
              padding:
              EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "or continue with",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _socialButton(
                icon: Icons.g_mobiledata,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _socialButton(
                icon: Icons.apple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Center(
            child: RichText(
                text: TextSpan(
                    text: "Don't have an account? ",
                    style: const TextStyle(color: Colors.white),
                    children: [
                      TextSpan(
                          text: "Sign Up",
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = (){
                            _pageController.animateToPage(
                              1,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                      ),
                    ]
                )
            )
        )
      ],
    );
  }

  //signup page
  Widget _signUpPage() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Create your Habit..!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 25),
          _buildTextField(
            controller: nameController,
            hint: "Full Name",
            icon: Icons.person,
            isPassword: false,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: signUpEmailController,
            hint: "Email",
            icon: Icons.email,
            isPassword: false,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: signUpPasswordController,
            hint: "Password",
            icon: Icons.lock,
            isPassword: true,
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity , 55),
              backgroundColor: const Color(0xFF00D9FF),
            ),
            onPressed: () async{
              bool success =
                  await AuthService.registerUser(
                    name: nameController.text,
                    email: signUpEmailController.text,
                    password: signUpPasswordController.text,
                  );
              if (success){
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Register sucessfull"),
                  ),
                );
                //going back to login
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
              else{
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Register Failed"),
                  ),
                );
              }
            },
            child: const Text(
              "create habit",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 25),
          //back to login
          Center(
              child: GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text(
                    "Already have an Habit? Login",
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
              )
          )
        ]
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPassword,

  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F203A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),

        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1F203A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildButton(String text) {
    return Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00D9FF),
              Color(0xFF00D8FF),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
        )
    );
  }
}
