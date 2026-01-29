import 'package:flutter/material.dart';

/// Run this file directly to see the app icon preview
/// Then take a screenshot at 512x512px
void main() {
  runApp(const AppIconPreview());
}

class AppIconPreview extends StatelessWidget {
  const AppIconPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey.shade800,
        body: const Center(
          child: SizedBox(width: 512, height: 512, child: AppIcon()),
        ),
      ),
    );
  }
}

/// The actual app icon widget - 512x512px
class AppIcon extends StatelessWidget {
  const AppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 512,
      height: 512,
      decoration: BoxDecoration(
        // Solid amber/yellow gradient background (no transparency)
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFCD34D), // Amber 300
            Color(0xFFF59E0B), // Amber 500
            Color(0xFFD97706), // Amber 600
          ],
        ),
        borderRadius: BorderRadius.circular(
          100,
        ), // Rounded corners for app icon
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle accent
          Positioned(
            top: 60,
            right: 60,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dumbbell/weight icon representation
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 140,
                  color: Color(0xFFD97706), // Amber 600
                ),
              ),
              const SizedBox(height: 30),
              // Resistance band indicator (yellow circle)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A), // Yellow 200
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    'WORKOUT',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
