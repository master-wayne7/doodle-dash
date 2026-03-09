import 'package:flutter/material.dart';
import 'dart:async';

class HowToPlayCard extends StatefulWidget {
  const HowToPlayCard({super.key});

  @override
  State<HowToPlayCard> createState() => _HowToPlayCardState();
}

class _HowToPlayCardState extends State<HowToPlayCard> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  Timer? _timer;

  final List<String> _steps = [
    "When it's your turn, choose a word you want to draw!",
    "Try to draw your choosen word! No spelling!",
    "Let other players try to guess your drawn word!",
    "When it's not your turn, try to guess what other players are drawing!",
    "Score the most points and be crowned the winner at the end!",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      int nextPage = _currentPageNotifier.value + 1;
      if (nextPage > 4) {
        nextPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 350), curve: Curves.easeIn);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 350,
      decoration: BoxDecoration(color: const Color(0xBF0C2C96), borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/how.gif', width: 24, height: 24),
              const SizedBox(width: 8),
              const Text(
                'How to play',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                _currentPageNotifier.value = page;
              },
              itemCount: 5,
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/tutorial/step${index + 1}.gif', height: 150),
                    const SizedBox(height: 16),
                    Text(
                      _steps[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<int>(
            valueListenable: _currentPageNotifier,
            builder: (context, currentPage, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(5, (int index) {
                  return GestureDetector(
                    onTap: () {
                      if (_pageController.hasClients) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: 10.0,
                      height: 10.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentPage == index ? Colors.white : Colors.white24,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
