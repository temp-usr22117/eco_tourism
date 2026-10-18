import 'package:flutter/material.dart';
import 'package:eco_tourism/screens/how_it_works_screen.dart';
import 'package:eco_tourism/screens/my_activity_screen.dart';
import 'package:eco_tourism/screens/plan_trek_screen.dart';
import 'package:eco_tourism/screens/add_trail_screen.dart';

import 'package:eco_tourism/services/trail_seed_service.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  void _navigateFromDrawer(BuildContext context, Widget page) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();

    // Wait for drawer close animation to finish before pushing the next page.
    Future.delayed(const Duration(milliseconds: 220), () {
      rootNavigator.push(MaterialPageRoute(builder: (_) => page));
    });
  }

  void _showSeedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF101827),
        title: const Row(
          children: [
            Icon(Icons.terrain_rounded, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'Seed Curated Treks',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Load 8 iconic Indian treks (Triund, Kedarkantha, Hampta Pass, Kudremukh, Valley of Flowers, Har Ki Dun, Sandakphu, Chembra) and their safety tips into Firestore?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                final count = await TrailSeedService.seedCuratedTrails();
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('Successfully seeded $count curated Indian treks!'),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Failed to seed trails: $e'),
                  ),
                );
              }
            },
            child: const Text('Seed Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0A0F1E),
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'TrailSafe Menu',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text('My Activity', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Check-ins history and undo',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                _navigateFromDrawer(context, const MyActivityScreen(initialTab: 0));
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
              title: const Text('Wishlist / Saved Treks', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Saved bucket list trails',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                _navigateFromDrawer(context, const MyActivityScreen(initialTab: 1));
              },
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Colors.white),
              title: const Text('Plan My Trek', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Get suggested treks by inputs',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                _navigateFromDrawer(context, const PlanTrekScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('How It Works', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'See app features in an interactive guide',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                _navigateFromDrawer(context, const HowItWorksScreen());
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined, color: Colors.greenAccent),
              title: const Text('Add New Trail', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Create and publish a new trek',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                _navigateFromDrawer(context, const AddTrailScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined, color: Colors.greenAccent),
              title: const Text('Seed Curated Treks', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Load iconic Indian trekking routes',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showSeedDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
