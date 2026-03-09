import 'package:flutter/material.dart';

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(color: const Color(0xBF0C2C96), borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/about.gif', width: 24, height: 24),
              const SizedBox(width: 8),
              const Text(
                'About',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Doodle Dash is a free online multiplayer drawing and guessing pictionary game.\n\n'
            'A normal game consists of a few rounds, where every round a player has to draw their chosen word and others have to guess it to gain points!\n\n'
            'The person with the most points at the end of the game, will then be crowned as the winner!\n'
            'Have fun!',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
