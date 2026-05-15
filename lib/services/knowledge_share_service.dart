import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/entities.dart';

class KnowledgeShareService {
  HttpServer? _server;
  final _info = NetworkInfo();
  
  // Storage for the current shared material
  GeneratedStudyMaterial? _activeMaterial;

  Future<String?> startBroadcasting(GeneratedStudyMaterial material) async {
    await stopBroadcasting();
    _activeMaterial = material;

    final router = Router();

    // The endpoint that the receiver will ping
    router.get('/share', (Request request) {
      if (_activeMaterial == null) return Response.notFound('No material shared');
      
      final data = {
        'type': _activeMaterial!.type,
        'title': _activeMaterial!.title ?? _activeMaterial!.type.toUpperCase(),
        'content': _activeMaterial!.contentJson,
        'origin': 'LocalGemma',
      };
      
      return Response.ok(
        jsonEncode(data),
        headers: {'content-type': 'application/json'},
      );
    });

    try {
      final ip = await _info.getWifiIP();
      if (ip == null) return null;

      _server = await io.serve(router, ip, 8080);
      print('Knowledge Server running on http://$ip:8080');
      
      // Return the URL that will be put in the QR code
      return 'lgshare://$ip:8080/share';
    } catch (e) {
      print('Error starting server: $e');
      return null;
    }
  }

  Future<void> stopBroadcasting() async {
    await _server?.close(force: true);
    _server = null;
    _activeMaterial = null;
  }
}
