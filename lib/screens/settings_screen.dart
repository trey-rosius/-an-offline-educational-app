import 'dart:ui';
import 'package:flutter/material.dart';
import '../model_selection_screen.dart';
import '../embedding_models_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AppBar(
                backgroundColor: Colors.white.withOpacity(0.06),
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'AI Configuration',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                centerTitle: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.18)),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF82B1FF).withOpacity(0.45),
                                const Color(0xFFB388FF).withOpacity(0.35),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    const Color(0xFF82B1FF).withOpacity(0.55)),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.all(4),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withOpacity(0.65),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          unselectedLabelStyle:
                              const TextStyle(fontSize: 13),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(
                              height: 40,
                              icon: Icon(Icons.psychology, size: 18),
                              iconMargin: EdgeInsets.only(bottom: 2),
                              text: 'Inference Model',
                            ),
                            Tab(
                              height: 40,
                              icon: Icon(Icons.storage, size: 18),
                              iconMargin: EdgeInsets.only(bottom: 2),
                              text: 'Embedding Model',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ModelSelectionScreen(),
            EmbeddingModelsScreen(),
          ],
        ),
      ),
    );
  }
}
