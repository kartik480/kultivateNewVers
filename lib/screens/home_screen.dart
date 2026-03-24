import 'package:flutter/material.dart';
import 'dart:ui';
class HomeScreen extends StatelessWidget{
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context){
    return Scaffold(
        backgroundColor: const Color(0xFF0F1023),
     appBar: PreferredSize(
       preferredSize: const Size.fromHeight(100),
       child: AppBar(
         title: const Text("Home",
           style: TextStyle(
             fontSize: 22,
             fontWeight: FontWeight.bold,
           ),
         ),
         centerTitle: true,
         backgroundColor: const Color(0xFF1A1B3A),
         elevation: 0,
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(
             bottom: Radius.circular(30),
           ),
         ),
       ),
     ),

     body: Padding(
       padding: const EdgeInsets.all(16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             //glossy box efxt
             const  SizedBox(height: 22),
             Container(
               width: double.infinity,
               height: 200,
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.08),
                 borderRadius: const BorderRadius.only(
                     topLeft: Radius.circular(30),
                     topRight: Radius.circular(30),
                     bottomLeft: Radius.circular(30),
                     bottomRight: Radius.circular(30)
                 ),
                 border: Border.all(
                   color: Colors.white.withOpacity(0.2),
                 ),
               ),
               child: const Center(
                 child: Text(
                   "Welcome to Home Screen",
                   style: TextStyle(
                     fontSize: 22,
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                 ),
               ),
             ),
             const SizedBox(height: 22),
             const Text(
               "Today's Habit",
               style: TextStyle(
                 fontSize: 20,
                 fontWeight: FontWeight.bold,
                 color: Colors.white,
               ),
             ),
             const SizedBox(height: 16),
             _habitCard(),
             _habitCard(),
             _habitCard(),
           ],
       ),

     )
    );
  }
  Widget _habitCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),

      child: Stack(
        children: [

          /// BACK SHADOW CARD (this creates depth)
          Positioned(
            left: 4,
            right: 0,
            top: 4,

            child: Container(
              height: 80,

              decoration: BoxDecoration(
                color: const Color(0xFF15162B),

                borderRadius:
                BorderRadius.circular(22),
              ),
            ),
          ),

          /// FRONT MAIN CARD
          Container(
            height: 80,

            decoration: BoxDecoration(

              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2A2B4A),
                  Color(0xFF1F203A),
                ],
              ),

              borderRadius:
              BorderRadius.circular(22),
            ),

            child: Stack(
              children: [

                /// LEFT ACCENT LINE
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,

                  child: Container(
                    width: 4,

                    decoration:
                    const BoxDecoration(
                      color: Color(0xFF00D9FF),

                      borderRadius:
                      BorderRadius.only(
                        topLeft:
                        Radius.circular(22),
                        bottomLeft:
                        Radius.circular(22),
                      ),
                    ),
                  ),
                ),

                /// CONTENT
                Padding(
                  padding:
                  const EdgeInsets.all(16),

                  child: Row(
                    children: [

                      /// ICON BOX
                      Container(
                        padding:
                        const EdgeInsets.all(10),

                        decoration:
                        BoxDecoration(
                          color: const Color(
                              0xFF00D9FF)
                              .withOpacity(0.15),

                          borderRadius:
                          BorderRadius
                              .circular(12),
                        ),

                        child: const Icon(
                          Icons.menu_book,
                          color:
                          Color(0xFF00D9FF),
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 14),

                      /// TEXT
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                          children: [

                            const Text(
                              "Read 10 Pages",
                              style: TextStyle(
                                color:
                                Colors.white,
                                fontSize: 16,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                                height: 4),

                            const Text(
                              "Streak: 12 days",
                              style: TextStyle(
                                color:
                                Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// CHECK BUTTON
                      Container(
                        padding:
                        const EdgeInsets.all(8),

                        decoration:
                        const BoxDecoration(
                          color:
                          Color(0xFF00D9FF),
                          shape:
                          BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
