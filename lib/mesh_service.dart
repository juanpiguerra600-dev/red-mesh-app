import 'dart:collection';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'mesh_packet.dart';

class MeshService {
  final String myUserName;
  final Strategy strategy = Strategy.P2P_CLUSTER;
  
  final Set<String> _connectedEndpoints = HashSet<String>();
  final Set<String> _seenPacketIds = HashSet<String>();
  
  Function(MeshPacket packet)? onMessageReceived;
  Function(Set<String> connectedUsers)? onPeersChanged;

  MeshService({required this.myUserName});

  Future<void> startMesh() async {
    await Nearby().startAdvertising(
      myUserName,
      strategy,
      onConnectionInitiated: _onConnectionInit,
      onConnectionResult: (endpointId, status) {
        if (status == Status.CONNECTED) {
          _connectedEndpoints.add(endpointId);
          onPeersChanged?.call(_connectedEndpoints);
        }
      },
      onDisconnected: (endpointId) {
        _connectedEndpoints.remove(endpointId);
        onPeersChanged?.call(_connectedEndpoints);
      },
    );

    await Nearby().startDiscovery(
      myUserName,
      strategy,
      onEndpointFound: (endpointId, name, serviceId) {
        Nearby().requestConnection(
          myUserName,
          endpointId,
          onConnectionInitiated: _onConnectionInit,
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) {
              _connectedEndpoints.add(id);
              onPeersChanged?.call(_connectedEndpoints);
            }
          },
          onDisconnected: (id) {
            _connectedEndpoints.remove(id);
            onPeersChanged?.call(_connectedEndpoints);
          },
        );
      },
      onEndpointLost: (endpointId) {},
    );
  }

  void _onConnectionInit(String endpointId, ConnectionInfo info) {
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          String rawData = String.fromCharCodes(payload.bytes!);
          _handleIncomingPacket(rawData, endpointId);
        }
      },
    );
  }

  void _handleIncomingPacket(String rawData, String fromEndpointId) {
    try {
      final packet = MeshPacket.deserialize(rawData);

      if (_seenPacketIds.contains(packet.id)) return;
      _seenPacketIds.add(packet.id);

      if (packet.recipientId == myUserName || packet.recipientId == "ALL") {
        onMessageReceived?.call(packet);
      }

      if (packet.ttl > 1) {
        packet.ttl -= 1;
        packet.routeHistory.add(myUserName);
        _relayPacket(packet, excludeEndpointId: fromEndpointId);
      }
    } catch (e) {
      print("Error procesando paquete: $e");
    }
  }

  void sendMessage(String payload, {String recipientId = "ALL"}) {
    final packet = MeshPacket(
      id: "${myUserName}_${DateTime.now().millisecondsSinceEpoch}",
      senderId: myUserName,
      recipientId: recipientId,
      payload: payload,
      routeHistory: [myUserName],
    );

    _seenPacketIds.add(packet.id);
    _relayPacket(packet);
  }

  void _relayPacket(MeshPacket packet, {String? excludeEndpointId}) {
    String data = packet.serialize();
    Uint8List bytes = Uint8List.fromList(data.codeUnits);

    for (String endpointId in _connectedEndpoints) {
      if (endpointId != excludeEndpointId) {
        Nearby().sendBytesPayload(endpointId, bytes);
      }
    }
  }
}
