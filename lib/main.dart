import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'mesh_service.dart';
import 'mesh_packet.dart';

void main() {
  runApp(const MaterialApp(home: MeshChatApp()));
}

class MeshChatApp extends StatefulWidget {
  const MeshChatApp({super.key});

  @override
  State<MeshChatApp> createState() => _MeshChatAppState();
}

class _MeshChatAppState extends State<MeshChatApp> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  MeshService? _meshService;
  bool _isServiceStarted = false;
  
  List<String> _messages = [];
  int _connectedPeersCount = 0;

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  void _startApp() async {
    if (_nameController.text.trim().isEmpty) return;
    
    await _requestPermissions();

    _meshService = MeshService(myUserName: _nameController.text.trim());
    
    _meshService!.onMessageReceived = (packet) {
      setState(() {
        _messages.add("${packet.senderId}: ${packet.payload}");
      });
    };

    _meshService!.onPeersChanged = (peers) {
      setState(() {
        _connectedPeersCount = peers.length;
      });
    };

    await _meshService!.startMesh();
    
    setState(() {
      _isServiceStarted = true;
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _meshService == null) return;
    
    String text = _messageController.text.trim();
    _meshService!.sendMessage(text);
    
    setState(() {
      _messages.add("Yo: $text");
    });
    
    _messageController.clear();
  }

  void _sendLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    String coords = "GPS: ${position.latitude}, ${position.longitude}";
    _meshService!.sendMessage(coords);
    
    setState(() {
      _messages.add("Yo: $coords");
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isServiceStarted) {
      return Scaffold(
        appBar: AppBar(title: const Text("Mesh Chat - Configuración")),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          style: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Ingresa tu Nombre de Usuario",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startApp,
                child: const Text("Iniciar Red Mesh"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Red Mesh (${_connectedPeersCount} vecinos directos)"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.location_on),
                  onPressed: _sendLocation,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Escribe un mensaje...",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
