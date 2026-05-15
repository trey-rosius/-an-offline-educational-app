import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';
import '../models/entities.dart';
import '../objectbox.g.dart';

class UsageTrackingService with WidgetsBindingObserver {
  final Store _store;
  late final Box<AppUsage> _usageBox;
  
  DateTime? _sessionStartTime;
  Timer? _persistenceTimer;

  UsageTrackingService(this._store) {
    _usageBox = _store.box<AppUsage>();
    WidgetsBinding.instance.addObserver(this);
    _startSession();
  }

  void _startSession() {
    _sessionStartTime = DateTime.now();
    // Persist every minute to be safe
    _persistenceTimer = Timer.periodic(const Duration(minutes: 1), (_) => _persistUsage());
  }

  void _persistUsage() {
    if (_sessionStartTime == null) return;

    final now = DateTime.now();
    final duration = now.difference(_sessionStartTime!);
    _sessionStartTime = now; // Reset start time for the next slice

    final dateString = DateFormat('yyyy-MM-dd').format(now);
    
    final query = _usageBox.query(AppUsage_.dateString.equals(dateString)).build();
    final usage = query.findFirst() ?? AppUsage(dateString: dateString);
    query.close();

    usage.secondsSpent += duration.inSeconds;
    _usageBox.put(usage);
    
    debugPrint('Usage tracked: ${usage.secondsSpent}s today');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _persistUsage();
      _persistenceTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startSession();
    }
  }

  void dispose() {
    _persistUsage();
    _persistenceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  int getTodayUsageSeconds() {
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final usage = _usageBox.query(AppUsage_.dateString.equals(dateString)).build().findFirst();
    return usage?.secondsSpent ?? 0;
  }
}
