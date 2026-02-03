import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize engine plugins
  UnityEnginePlugin.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Framework Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Game Framework'),
        elevation: 2,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.games,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Flutter Game Framework',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Unified API for Unity, Unreal, and more',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UnityExampleScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Unity Example'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unreal Engine plugin coming soon!'),
                  ),
                );
              },
              icon: const Icon(Icons.code),
              label: const Text('Unreal Example (Coming Soon)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StreamingExampleScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_download),
              label: const Text('Streaming Example'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UnityExampleScreen extends StatefulWidget {
  const UnityExampleScreen({super.key});

  @override
  State<UnityExampleScreen> createState() => _UnityExampleScreenState();
}

class _UnityExampleScreenState extends State<UnityExampleScreen> {
  GameEngineController? _controller;
  double _rotationSpeed = 50.0;
  String _rotationAxis = 'Y';
  bool _isReady = false;
  String _lastMessage = 'Initializing...';
  String _direction = '---';
  double _currentSpeed = 0;
  double _currentRpm = 0;
  final List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.blueAccent,
          thumbColor: Colors.blue,
          overlayColor: Colors.blue.withValues(alpha: 0.2),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Unity game view (full screen)
            GameWidget(
              engineType: GameEngineType.unity,
              onEngineCreated: _onEngineCreated,
              onMessage: _onMessage,
              onSceneLoaded: _onSceneLoaded,
              config: const GameEngineConfig(
                androidPlatformViewMode: AndroidPlatformViewMode.virtualDisplay,
                runImmediately: true,
                enableDebugLogs: true,
              ),
            ),

            // Overlay UI - Top info card
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: _buildInfoCard(),
            ),

            // Overlay UI - Bottom controls
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildControlPanel(),
            ),

            // Back button
            Positioned(
              top: 40,
              left: 10,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),

            // Status indicator
            if (!_isReady)
              Container(
                color: Colors.black87,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading Unity...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.black.withValues(alpha: 0.85),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.speed,
              'Speed',
              '${_currentSpeed.toStringAsFixed(0)}°/s (${_currentRpm.toStringAsFixed(1)} RPM)',
              Colors.amber,
            ),
            const Divider(color: Colors.white24, height: 20),
            _buildInfoRow(
              Icons.message,
              'Message',
              _lastMessage,
              Colors.blue,
            ),
            const Divider(color: Colors.white24, height: 20),
            _buildInfoRow(
              _direction.contains('FROM')
                  ? Icons.arrow_back
                  : Icons.arrow_forward,
              'Direction',
              _direction,
              _direction.contains('FROM') ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Card(
      color: Colors.black.withValues(alpha: 0.9),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              '🎮 Cube Controls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Speed slider
            _buildSliderControl(
              'Rotation Speed',
              _rotationSpeed,
              -180,
              180,
              (value) {
                setState(() => _rotationSpeed = value);
                _sendSpeed(value);
              },
              Icons.threesixty,
            ),

            const SizedBox(height: 16),

            // Axis selector
            _buildAxisSelector(),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Reset',
                    Icons.refresh,
                    Colors.orange,
                    _reset,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Get State',
                    Icons.analytics,
                    Colors.blue,
                    _getState,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Random Color',
                    Icons.palette,
                    Colors.purple,
                    _randomColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderControl(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${value.toStringAsFixed(0)}°/s',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: _isReady ? onChanged : null,
        ),
      ],
    );
  }

  Widget _buildAxisSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.loop, color: Colors.greenAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Rotation Axis',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAxisButton('X', Colors.red),
            const SizedBox(width: 8),
            _buildAxisButton('Y', Colors.green),
            const SizedBox(width: 8),
            _buildAxisButton('Z', Colors.blue),
            const SizedBox(width: 8),
            _buildAxisButton('All', Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildAxisButton(String axis, Color color) {
    final isSelected = _rotationAxis == axis;
    return Expanded(
      child: Material(
        color: isSelected ? color : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isReady
              ? () {
                  setState(() => _rotationAxis = axis);
                  _setAxis(axis);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              axis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: _isReady ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _onEngineCreated(GameEngineController controller) {
    setState(() {
      _controller = controller;
    });
    _log('Engine created');
  }

  void _onMessage(GameEngineMessage message) {
    _log('Message received: ${message.method} - ${message.data}');

    final method = message.method;

    if (method == 'onReady') {
      setState(() {
        _isReady = true;
        _lastMessage = 'Unity cube demo ready!';
        _direction = '← FROM UNITY';
      });
    } else if (method == 'onSpeedChanged') {
      try {
        final data = message.asJson();
        if (data != null) {
          setState(() {
            _currentSpeed = (data['speed'] as num?)?.toDouble() ?? 0;
            _currentRpm = (data['rpm'] as num?)?.toDouble() ?? 0;
            _lastMessage = 'Speed updated';
            _direction = '← FROM UNITY';
          });
        }
      } catch (e) {
        _log('Error parsing speed data: $e');
      }
    } else if (method == 'onReset') {
      setState(() {
        _rotationSpeed = 50;
        _rotationAxis = 'Y';
        _lastMessage = 'Cube reset';
        _direction = '← FROM UNITY';
      });
    } else if (method == 'onState') {
      setState(() {
        _lastMessage = 'State received';
        _direction = '← FROM UNITY';
      });
    }
  }

  void _onSceneLoaded(GameSceneLoaded sceneInfo) {
    _log('Scene loaded: ${sceneInfo.name}');
  }

  void _sendSpeed(double speed) {
    _controller?.sendMessage('GameFrameworkDemo', 'setSpeed', speed.toString());
    setState(() {
      _lastMessage = 'Speed set to ${speed.toStringAsFixed(0)}°/s';
      _direction = '→ TO UNITY';
    });
  }

  void _setAxis(String axis) {
    Map<String, dynamic> axisData;
    switch (axis) {
      case 'X':
        axisData = {'x': 1.0, 'y': 0.0, 'z': 0.0};
        break;
      case 'Y':
        axisData = {'x': 0.0, 'y': 1.0, 'z': 0.0};
        break;
      case 'Z':
        axisData = {'x': 0.0, 'y': 0.0, 'z': 1.0};
        break;
      case 'All':
        axisData = {'x': 1.0, 'y': 1.0, 'z': 1.0};
        break;
      default:
        axisData = {'x': 0.0, 'y': 1.0, 'z': 0.0};
    }

    _controller?.sendJsonMessage('GameFrameworkDemo', 'setAxis', axisData);
    setState(() {
      _lastMessage = 'Axis set to $axis';
      _direction = '→ TO UNITY';
    });
  }

  void _reset() {
    _controller?.sendMessage('GameFrameworkDemo', 'reset', '');
    setState(() {
      _rotationSpeed = 50;
      _rotationAxis = 'Y';
      _lastMessage = 'Reset requested';
      _direction = '→ TO UNITY';
    });
  }

  void _getState() {
    _controller?.sendMessage('GameFrameworkDemo', 'getState', '');
    setState(() {
      _lastMessage = 'State requested';
      _direction = '→ TO UNITY';
    });
  }

  void _randomColor() {
    final random = math.Random();
    final colorData = {
      'r': random.nextDouble() * 0.5 + 0.3,
      'g': random.nextDouble() * 0.5 + 0.3,
      'b': random.nextDouble() * 0.5 + 0.3,
      'a': 1.0,
    };

    _controller?.sendJsonMessage('GameFrameworkDemo', 'setColor', colorData);
    setState(() {
      _lastMessage = 'Color changed';
      _direction = '→ TO UNITY';
    });
  }

  void _log(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toIso8601String()}] $message');
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });
    debugPrint(message);
  }
}

/// Example screen demonstrating streaming functionality
class StreamingExampleScreen extends StatefulWidget {
  const StreamingExampleScreen({super.key});

  @override
  State<StreamingExampleScreen> createState() => _StreamingExampleScreenState();
}

class _StreamingExampleScreenState extends State<StreamingExampleScreen> {
  double _downloadProgress = 0.0;
  String _statusMessage = 'Streaming not configured';
  final List<_BundleInfo> _bundles = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Simulate loading bundle info
    _loadBundleInfo();
  }

  void _loadBundleInfo() {
    // In a real app, this would come from GameStreamController.getManifest()
    setState(() {
      _bundles.addAll([
        _BundleInfo(
          name: 'Base Content',
          size: '15.2 MB',
          isBase: true,
          status: _BundleStatus.bundled,
        ),
        _BundleInfo(
          name: 'Level 1',
          size: '25.0 MB',
          isBase: false,
          status: _BundleStatus.notDownloaded,
        ),
        _BundleInfo(
          name: 'Level 2',
          size: '32.5 MB',
          isBase: false,
          status: _BundleStatus.notDownloaded,
        ),
        _BundleInfo(
          name: 'Characters Pack',
          size: '45.8 MB',
          isBase: false,
          status: _BundleStatus.notDownloaded,
        ),
      ]);
      _isInitialized = true;
      _statusMessage = 'Ready - Select content to download';
    });
  }

  Future<void> _downloadBundle(_BundleInfo bundle) async {
    if (bundle.isBase || bundle.status == _BundleStatus.downloaded) return;

    setState(() {
      bundle.status = _BundleStatus.downloading;
      _statusMessage = 'Downloading ${bundle.name}...';
    });

    // Simulate download progress
    for (var i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _downloadProgress = i / 100;
      });
    }

    setState(() {
      bundle.status = _BundleStatus.downloaded;
      _downloadProgress = 0;
      _statusMessage = '${bundle.name} downloaded successfully';
    });
  }

  Future<void> _downloadAll() async {
    for (final bundle in _bundles) {
      if (bundle.status == _BundleStatus.notDownloaded) {
        await _downloadBundle(bundle);
      }
    }
    setState(() {
      _statusMessage = 'All content downloaded';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadAll,
            tooltip: 'Download All',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_downloadProgress > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 4),
                  Text('${(_downloadProgress * 100).toInt()}%'),
                ],
              ],
            ),
          ),

          // Info card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal),
                      SizedBox(width: 8),
                      Text(
                        'Streaming Configuration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This example demonstrates the streaming API. '
                    'In a real app, you would:\n'
                    '1. Configure streaming in .game.yml\n'
                    '2. Build Unity with Addressables\n'
                    '3. Publish to GameFramework Cloud\n'
                    '4. Use GameStreamController to download',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),

          // Bundle list
          Expanded(
            child: _isInitialized
                ? ListView.builder(
                    itemCount: _bundles.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final bundle = _bundles[index];
                      return _BundleTile(
                        bundle: bundle,
                        onDownload: () => _downloadBundle(bundle),
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

enum _BundleStatus {
  bundled,
  notDownloaded,
  downloading,
  downloaded,
}

class _BundleInfo {
  final String name;
  final String size;
  final bool isBase;
  _BundleStatus status;

  _BundleInfo({
    required this.name,
    required this.size,
    required this.isBase,
    required this.status,
  });
}

class _BundleTile extends StatelessWidget {
  final _BundleInfo bundle;
  final VoidCallback onDownload;

  const _BundleTile({
    required this.bundle,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          _getIcon(),
          color: _getColor(),
        ),
        title: Text(bundle.name),
        subtitle: Text('${bundle.size} • ${_getStatusText()}'),
        trailing: _buildTrailing(),
      ),
    );
  }

  IconData _getIcon() {
    if (bundle.isBase) return Icons.folder;
    switch (bundle.status) {
      case _BundleStatus.bundled:
        return Icons.check_circle;
      case _BundleStatus.notDownloaded:
        return Icons.cloud_download;
      case _BundleStatus.downloading:
        return Icons.downloading;
      case _BundleStatus.downloaded:
        return Icons.check_circle;
    }
  }

  Color _getColor() {
    if (bundle.isBase) return Colors.blue;
    switch (bundle.status) {
      case _BundleStatus.bundled:
        return Colors.green;
      case _BundleStatus.notDownloaded:
        return Colors.grey;
      case _BundleStatus.downloading:
        return Colors.orange;
      case _BundleStatus.downloaded:
        return Colors.green;
    }
  }

  String _getStatusText() {
    if (bundle.isBase) return 'Bundled with app';
    switch (bundle.status) {
      case _BundleStatus.bundled:
        return 'Bundled';
      case _BundleStatus.notDownloaded:
        return 'Not downloaded';
      case _BundleStatus.downloading:
        return 'Downloading...';
      case _BundleStatus.downloaded:
        return 'Downloaded';
    }
  }

  Widget? _buildTrailing() {
    if (bundle.isBase) return null;
    if (bundle.status == _BundleStatus.downloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (bundle.status == _BundleStatus.notDownloaded) {
      return IconButton(
        icon: const Icon(Icons.download),
        onPressed: onDownload,
      );
    }
    return null;
  }
}
