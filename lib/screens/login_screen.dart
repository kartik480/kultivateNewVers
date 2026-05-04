import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kultivate_new_ver/services/auth_service.dart';
import 'package:kultivate_new_ver/services/habit_store.dart';
import 'package:kultivate_new_ver/services/todo_store.dart';
import '../screens/home_screen.dart';

TextStyle _loginGeo({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color = Colors.white,
  double height = 1.35,
}) =>
    GoogleFonts.geologica(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );

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
    return SingleChildScrollView(
    child:  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    SizedBox(height: 50),
    _buildStartPanel(),
    const SizedBox(height: 40),
    Center(
    child: Text(
    'Welcome Back',
    textAlign: TextAlign.center,
    style: GoogleFonts.clickerScript(
    fontSize: 36,
    color: Colors.white,
    height: 1.05,
    ),
    ),
    ),
    const SizedBox(height: 6),
    Center(
    child: Text(
    'Sign in to continue your journey',
    textAlign: TextAlign.center,
    style: _loginGeo(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.white70),
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
    Text(
    'Remember my Habit!',
    style: _loginGeo(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    ],
    ),
    ],
    ),
    TextButton(
    onPressed: () {},
    child: Text(
    'Forgot Your Habit??',
    style: _loginGeo(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.lightBlueAccent),
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
    final err = await AuthService.loginUser(
    email: emailController.text,
    password: passwordController.text,
    );
    if (err == null){
    await HabitStore.instance.applyLogin(email: emailController.text.trim());
    await TodoStore.instance.resyncAfterAuth();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
    content: Text('Login Successful', style: _loginGeo(fontWeight: FontWeight.w500)),
    ),
    );
    Navigator.pushReplacement(
    context,
    MaterialPageRoute(
    builder: (context) => const HomeScreen(),
    ),
    );
    }
    else{
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
    content: Text(err, style: _loginGeo(fontWeight: FontWeight.w500)),
    ),
    );
    }
    },
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    ),
    child: Text(
    'Login on-Habit on',
    style: _loginGeo(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
    ),
    ),
    ),
    const SizedBox(height: 25),
    Row(
    children: [
    const Expanded(
    child: Divider(
    color: Colors.white24,
    ),
    ),
    Padding(
    padding:
    const EdgeInsets.symmetric(horizontal: 10),
    child: Text(
    'or continue with',
    style: _loginGeo(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white70),
    ),
    ),
    const Expanded(
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
    style: _loginGeo(fontSize: 14, fontWeight: FontWeight.w400),
    children: [
    TextSpan(
    text: 'Sign Up',
    style: _loginGeo(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.lightBlueAccent),
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
    )
    );
  }

  Widget _buildStartPanel() {
    const cyan = Color(0xFF00D9FF);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cyan, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: cyan.withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF9BEFFF), Color(0xFF00D9FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'Kultivate',
              style: GoogleFonts.clickerScript(
                fontSize: 36,
                color: Colors.white,
                height: 1.05,
              ),
            ),
          ),
          Text(
            'Build Better Habits',
            style: _loginGeo(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  //signup page
  Widget _signUpPage() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create your Habit..!',
            style: _loginGeo(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
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
            onPressed: () async {
              final err = await AuthService.registerUser(
                name: nameController.text,
                email: signUpEmailController.text,
                password: signUpPasswordController.text,
              );
              if (!context.mounted) return;
              if (err == null) {
                await HabitStore.instance.registerProfile(
                  displayName: nameController.text.trim(),
                  email: signUpEmailController.text.trim(),
                );
                await TodoStore.instance.resyncAfterAuth();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Register successful', style: _loginGeo(fontWeight: FontWeight.w500)),
                  ),
                );
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err, style: _loginGeo(fontWeight: FontWeight.w500))),
                );
              }
            },
            child: Text(
              'create habit',
              style: _loginGeo(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
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
                  child: Text(
                    'Already have an Habit? Login',
                    style: _loginGeo(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.lightBlueAccent),
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
        style: _loginGeo(fontSize: 16, fontWeight: FontWeight.w400),

        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _loginGeo(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white54),
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
}

