// lib/features/cast/data/dlna_service.dart
// DLNA 投屏服务：设备发现 + 播放控制
// 基于 dlna_dart (BSD-3-Clause) 核心逻辑，内联以兼容当前 SDK 版本

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

// ──────────────────────────────────────────────
// 数据模型
// ──────────────────────────────────────────────

class DlnaDevice {
  final String urlBase;
  final String deviceType;
  final String friendlyName;
  final List<Map<String, String>> serviceList;
  DateTime activeTime;

  DlnaDevice({
    required this.urlBase,
    required this.deviceType,
    required this.friendlyName,
    required this.serviceList,
    DateTime? activeTime,
  }) : activeTime = activeTime ?? DateTime.now();

  /// 是否是 MediaRenderer（可以投屏的设备）
  bool get isRenderer => deviceType.contains('MediaRenderer');

  String get id => urlBase;

  @override
  bool operator ==(Object other) =>
      other is DlnaDevice && other.urlBase == urlBase;

  @override
  int get hashCode => urlBase.hashCode;
}

class DlnaPosition {
  final String trackDuration;
  final String relTime;
  final String trackUri;

  DlnaPosition({
    this.trackDuration = '00:00:00',
    this.relTime = '00:00:00',
    this.trackUri = '',
  });

  int get durationSeconds => _timeToSeconds(trackDuration);
  int get positionSeconds => _timeToSeconds(relTime);
  double get progress =>
      durationSeconds > 0 ? positionSeconds / durationSeconds : 0;

  static int _timeToSeconds(String str) {
    final parts = str.split(':');
    var sum = 0;
    for (var i = 0; i < parts.length; i++) {
      final n = int.tryParse(parts[i]);
      if (n == null) return 0;
      sum += n * (pow(60, parts.length - i - 1) as int);
    }
    return sum;
  }

  static String secondsToTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds - 3600 * h) ~/ 60;
    final s = seconds - 3600 * h - 60 * m;
    return '${_pad(h)}:${_pad(m)}:${_pad(s)}';
  }

  static String _pad(int n) => n > 9 ? '$n' : '0$n';
}

enum DlnaTransportState {
  playing,
  paused,
  stopped,
  transitioning,
  unknown,
}

// ──────────────────────────────────────────────
// DLNA 服务
// ──────────────────────────────────────────────

class DlnaService {
  DlnaService._();
  static final instance = DlnaService._();

  final _devices = <String, DlnaDevice>{};
  final _devicesController =
      StreamController<Map<String, DlnaDevice>>.broadcast();
  Stream<Map<String, DlnaDevice>> get devicesStream => _devicesController.stream;
  Map<String, DlnaDevice> get devices => Map.unmodifiable(_devices);

  DlnaDevice? _connectedDevice;
  DlnaDevice? get connectedDevice => _connectedDevice;

  Timer? _searchTimer;
  RawDatagramSocket? _serverSocket;
  StreamSubscription? _clientSub;
  StreamSubscription? _serverSub;
  int _searchCount = 0;

  // 进度轮询
  Timer? _positionTimer;
  final _positionController = StreamController<DlnaPosition>.broadcast();
  Stream<DlnaPosition> get positionStream => _positionController.stream;

  final _transportStateController =
      StreamController<DlnaTransportState>.broadcast();
  Stream<DlnaTransportState> get transportStateStream =>
      _transportStateController.stream;

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;
  bool get isConnected => _connectedDevice != null;

  // ── 设备发现 ──

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _devices.clear();
    _searchCount = 0;

    _serverSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      1900,
      reusePort: true,
    );
    _serverSocket!.joinMulticast(InternetAddress('239.255.255.250'));

    final clientSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );

    _clientSub = clientSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram? datagram;
        while ((datagram = clientSocket.receive()) != null) {
          _handleMessage(String.fromCharCodes(datagram!.data).trim());
        }
      }
    });

    _serverSub = _serverSocket?.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram? datagram;
        while ((datagram = _serverSocket?.receive()) != null) {
          _handleMessage(String.fromCharCodes(datagram!.data).trim());
        }
      }
    });

    _sendSearch(clientSocket);
    _searchTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _sendSearch(clientSocket),
    );
  }

  void stopDiscovery() {
    _isDiscovering = false;
    _searchTimer?.cancel();
    _clientSub?.cancel();
    _serverSub?.cancel();
    _serverSocket?.close();
    _serverSocket = null;
  }

  void _sendSearch(RawDatagramSocket socket) {
    final targets = _searchCount == 0
        ? ['ssdp:all', 'urn:schemas-upnp-org:device:MediaRenderer:1']
        : ['urn:schemas-upnp-org:device:MediaRenderer:1'];

    for (final st in targets) {
      final msg = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'ST: $st\r\n'
          'MX: ${_searchCount == 0 ? 1 : 3}\r\n'
          'MAN: "ssdp:discover"\r\n\r\n';
      socket.send(
        msg.codeUnits,
        InternetAddress('239.255.255.250'),
        1900,
      );
    }
    _searchCount++;
  }

  Future<void> _handleMessage(String message) async {
    final lines = message.split('\n');
    final first = lines.first.split(' ');
    if (first.isEmpty || first[0] == 'M-SEARCH') return;

    String? location;
    for (final line in lines) {
      if (line.toUpperCase().startsWith('LOCATION:')) {
        location = line.substring(9).trim();
        break;
      }
    }
    if (location == null || location.isEmpty) return;

    try {
      final info = await _fetchDeviceInfo(location);
      if (info == null || !info.isRenderer) return;

      final existing = _devices[info.urlBase];
      if (existing != null) {
        existing.activeTime = DateTime.now();
      } else {
        _devices[info.urlBase] = info;
      }

      // 清理超过 120 秒未活跃的设备
      final now = DateTime.now();
      _devices.removeWhere(
          (_, d) => now.difference(d.activeTime).inSeconds > 120);

      if (!_devicesController.isClosed) {
        _devicesController.add(_devices);
      }
    } catch (_) {}
  }

  Future<DlnaDevice?> _fetchDeviceInfo(String uri) async {
    try {
      final target = Uri.parse(uri);
      final body = await _httpGet(target);
      final doc = XmlDocument.parse(body);

      String urlBase;
      try {
        urlBase = doc.findAllElements('URLBase').first.innerText;
      } catch (_) {
        urlBase = target.origin;
      }

      final deviceType = doc.findAllElements('deviceType').first.innerText;
      final friendlyName = doc.findAllElements('friendlyName').first.innerText;

      final services = <Map<String, String>>[];
      for (final service
          in doc.findAllElements('serviceList').first.findAllElements('service')) {
        services.add({
          'serviceType': service.findAllElements('serviceType').first.innerText,
          'serviceId': service.findAllElements('serviceId').first.innerText,
          'controlURL': service.findAllElements('controlURL').first.innerText,
        });
      }

      return DlnaDevice(
        urlBase: urlBase,
        deviceType: deviceType,
        friendlyName: friendlyName,
        serviceList: services,
      );
    } catch (_) {
      return null;
    }
  }

  // ── 设备连接 ──

  void connect(DlnaDevice device) {
    _connectedDevice = device;
  }

  void disconnect() {
    stopPositionPolling();
    _connectedDevice = null;
  }

  // ── 播放控制 ──

  Future<void> setUrl(String url, {String title = ''}) async {
    if (_connectedDevice == null) return;
    final xml = _buildSetUrlXml(url, title: title);
    await _soapRequest(_connectedDevice!, 'SetAVTransportURI', xml);
  }

  Future<void> play() async {
    if (_connectedDevice == null) return;
    await _soapRequest(_connectedDevice!, 'Play', _playXml);
  }

  Future<void> pause() async {
    if (_connectedDevice == null) return;
    await _soapRequest(_connectedDevice!, 'Pause', _pauseXml);
  }

  Future<void> stop() async {
    if (_connectedDevice == null) return;
    await _soapRequest(_connectedDevice!, 'Stop', _stopXml);
  }

  Future<void> seek(int seconds) async {
    if (_connectedDevice == null) return;
    final timeStr = DlnaPosition.secondsToTime(seconds);
    final xml = _buildSeekXml(timeStr);
    await _soapRequest(_connectedDevice!, 'Seek', xml);
  }

  Future<void> setVolume(int volume) async {
    if (_connectedDevice == null) return;
    final xml = _buildVolumeXml(volume.clamp(0, 100));
    await _soapRequest(_connectedDevice!, 'SetVolume', xml,
        isRenderingControl: true);
  }

  Future<int> getVolume() async {
    if (_connectedDevice == null) return 0;
    final resp = await _soapRequest(
        _connectedDevice!, 'GetVolume', _getVolumeXml,
        isRenderingControl: true);
    final doc = XmlDocument.parse(resp);
    return int.parse(doc.findAllElements('CurrentVolume').first.innerText);
  }

  Future<DlnaPosition> getPosition() async {
    if (_connectedDevice == null) {
      return DlnaPosition();
    }
    final resp =
        await _soapRequest(_connectedDevice!, 'GetPositionInfo', _getPositionXml);
    final doc = XmlDocument.parse(resp);
    return DlnaPosition(
      trackDuration: doc.findAllElements('TrackDuration').first.innerText,
      relTime: doc.findAllElements('RelTime').first.innerText,
      trackUri: doc.findAllElements('TrackURI').first.innerText,
    );
  }

  Future<DlnaTransportState> getTransportState() async {
    if (_connectedDevice == null) return DlnaTransportState.unknown;
    final resp = await _soapRequest(
        _connectedDevice!, 'GetTransportInfo', _getTransportInfoXml);
    final doc = XmlDocument.parse(resp);
    final state =
        doc.findAllElements('CurrentTransportState').first.innerText;
    switch (state) {
      case 'PLAYING':
        return DlnaTransportState.playing;
      case 'PAUSED_PLAYBACK':
        return DlnaTransportState.paused;
      case 'STOPPED':
      case 'NO_MEDIA_PRESENT':
        return DlnaTransportState.stopped;
      case 'TRANSITIONING':
        return DlnaTransportState.transitioning;
      default:
        return DlnaTransportState.unknown;
    }
  }

  // ── 进度轮询 ──

  void startPositionPolling() {
    stopPositionPolling();
    _pollPosition();
  }

  void stopPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  Future<void> _pollPosition() async {
    if (_connectedDevice == null) return;
    try {
      final pos = await getPosition();
      debugPrint('[DLNA] poll position: ${pos.relTime} / ${pos.trackDuration}');
      if (!_positionController.isClosed) {
        _positionController.add(pos);
      }
      final state = await getTransportState();
      debugPrint('[DLNA] poll transport: $state');
      if (!_transportStateController.isClosed) {
        _transportStateController.add(state);
      }
    } catch (e) {
      debugPrint('[DLNA] poll error: $e');
    }
    _positionTimer = Timer(const Duration(seconds: 2), _pollPosition);
  }

  // ── SOAP 请求 ──

  String _controlUrl(DlnaDevice device, String type) {
    final base = device.urlBase.endsWith('/')
        ? device.urlBase.substring(0, device.urlBase.length - 1)
        : device.urlBase;
    final service = device.serviceList.firstWhere(
      (s) => s['serviceId']!.contains(type),
    );
    final controlUrl = service['controlURL']!;
    final path = controlUrl.startsWith('/') ? controlUrl : '/$controlUrl';
    return '$base$path';
  }

  Future<String> _soapRequest(
    DlnaDevice device,
    String action,
    String body, {
    bool isRenderingControl = false,
  }) async {
    final soapAction =
        isRenderingControl ? 'RenderingControl' : 'AVTransport';
    final url = _controlUrl(device, soapAction);
    final headers = {
      'SOAPAction':
          '"urn:schemas-upnp-org:service:$soapAction:1#$action"',
      'Content-Type': 'text/xml; charset="utf-8"',
      'Connection': 'close',
    };
    return _httpPost(Uri.parse(url), headers, utf8.encode(body));
  }

  // ── HTTP ──

  static Future<String> _httpGet(Uri uri) async {
    const timeout = Duration(seconds: 10);
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.persistentConnection = false;
      final res = await req.close().timeout(timeout);
      if (res.statusCode != HttpStatus.ok) {
        throw Exception('GET $uri failed: ${res.statusCode}');
      }
      return res.transform(utf8.decoder).join().timeout(timeout);
    } finally {
      client.close();
    }
  }

  static Future<String> _httpPost(
    Uri uri,
    Map<String, String> headers,
    List<int> data,
  ) async {
    const timeout = Duration(seconds: 10);
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.persistentConnection = false;
      headers.forEach((k, v) => req.headers.set(k, v));
      req.contentLength = data.length;
      req.add(data);
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      if (res.statusCode != HttpStatus.ok) {
        throw Exception('POST $uri failed: ${res.statusCode} $body');
      }
      return body;
    } finally {
      client.close();
    }
  }

  // ── SOAP XML 模板 ──

  static String _htmlEncode(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll("'", '&#39;')
        .replaceAll('"', '&quot;');
  }

  static String _buildSetUrlXml(String url, {String title = ''}) {
    final encodedUrl = _htmlEncode(url);
    final encodedTitle = _htmlEncode(title.isEmpty ? url : title);
    return '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>$encodedUrl</CurrentURI>
      <CurrentURIMetaData>
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
          <item id="0" parentID="0" restricted="0">
            <dc:title>$encodedTitle</dc:title>
            <upnp:class>object.item.videoItem</upnp:class>
            <res protocolInfo="http-get:*:video/mp4:*">$encodedUrl</res>
          </item>
        </DIDL-Lite>
      </CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>''';
  }

  static const _playXml = '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Speed>1</Speed>
    </u:Play>
  </s:Body>
</s:Envelope>''';

  static const _pauseXml = '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:Pause>
  </s:Body>
</s:Envelope>''';

  static const _stopXml = '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:Stop>
  </s:Body>
</s:Envelope>''';

  static const _getPositionXml = '''<?xml version="1.0" encoding="utf-8" standalone="no"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:GetPositionInfo>
  </s:Body>
</s:Envelope>''';

  static const _getTransportInfoXml = '''<?xml version="1.0" encoding="utf-8" standalone="no"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetTransportInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:GetTransportInfo>
  </s:Body>
</s:Envelope>''';

  static String _buildSeekXml(String target) {
    return '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Unit>REL_TIME</Unit>
      <Target>$target</Target>
    </u:Seek>
  </s:Body>
</s:Envelope>''';
  }

  static String _buildVolumeXml(int volume) {
    return '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
      <InstanceID>0</InstanceID>
      <Channel>Master</Channel>
      <DesiredVolume>$volume</DesiredVolume>
    </u:SetVolume>
  </s:Body>
</s:Envelope>''';
  }

  static const _getVolumeXml = '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
      <InstanceID>0</InstanceID>
      <Channel>Master</Channel>
    </u:GetVolume>
  </s:Body>
</s:Envelope>''';

  void dispose() {
    stopDiscovery();
    stopPositionPolling();
    _devicesController.close();
    _positionController.close();
    _transportStateController.close();
  }
}
