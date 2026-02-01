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
  String _statusMessage = 'Initializing...';
  int _score = 0;
  bool _isEngineReady = false;
  final List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unity Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color:
                _isEngineReady ? Colors.green.shade100 : Colors.orange.shade100,
            child: Row(
              children: [
                Icon(
                  _isEngineReady ? Icons.check_circle : Icons.pending,
                  color: _isEngineReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Game view
          Expanded(
            child: GameWidget(
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
          ),

          // Control panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.play_arrow,
                      label: 'Start',
                      onPressed: _isEngineReady ? _startGame : null,
                      color: Colors.green,
                    ),
                    _buildControlButton(
                      icon: Icons.pause,
                      label: 'Pause',
                      onPressed: _isEngineReady ? _pauseGame : null,
                      color: Colors.orange,
                    ),
                    _buildControlButton(
                      icon: Icons.stop,
                      label: 'Stop',
                      onPressed: _isEngineReady ? _stopGame : null,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.message,
                      label: 'Send Message',
                      onPressed: _isEngineReady ? _sendTestMessage : null,
                      color: Colors.blue,
                    ),
                    _buildControlButton(
                      icon: Icons.refresh,
                      label: 'Reset',
                      onPressed: _resetScore,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Event log
          if (_logs.isNotEmpty)
            Container(
              height: 150,
              color: Colors.black87,
              child: ListView.builder(
                reverse: true,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final logIndex = _logs.length - 1 - index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      _logs[logIndex],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontFamily: 'Courier',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _onEngineCreated(GameEngineController controller) {
    setState(() {
      _controller = controller;
      _isEngineReady = true;
      _statusMessage = 'Engine ready!';
    });
    _addLog(
        'Engine created: ${controller.engineType.engineName} v${controller.engineVersion}');

    // Listen to engine events
    controller.eventStream.listen((event) {
      _addLog('Event: ${event.type.name}');
      if (event.type == GameEngineEventType.error) {
        _addLog('Error: ${event.message}');
      }
    });
  }

  void _onMessage(GameEngineMessage message) {
    _addLog('Message: ${message.data}');

    // Try to parse as JSON and handle game messages
    final json = message.asJson();
    if (json != null && json['type'] == 'onScoreUpdate') {
      setState(() {
        _score = json['score'] as int? ?? _score;
      });
    }
  }

  void _onSceneLoaded(GameSceneLoaded scene) {
    _addLog('Scene loaded: ${scene.name} (Index: ${scene.buildIndex})');
    setState(() {
      _statusMessage = 'Scene: ${scene.name}';
    });
  }

  void _startGame() async {
    _addLog('Starting game...');
    await _controller?.sendMessage('GameManager', 'StartGame', 'level1');
  }

  void _pauseGame() async {
    _addLog('Pausing game...');
    await _controller?.pause();
  }

  void _stopGame() async {
    _addLog('Stopping game...');
    await _controller?.sendMessage('GameManager', 'StopGame', '');
  }

  void _sendTestMessage() async {
    _addLog('Sending test message...');
    await _controller?.sendJsonMessage('GameManager', 'UpdateScore', {
      'score': 100,
      'stars': 3,
    });
  }

  void _resetScore() {
    setState(() {
      _score = 0;
    });
    _addLog('Score reset');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(
          '[${DateTime.now().toIso8601String().split('T')[1].substring(0, 8)}] $message');
      if (_logs.length > 50) {
        _logs.removeAt(0);
      }
    });
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unity Integration'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Setup Instructions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                  '1. Export your Unity project using Flutter > Export for Flutter'),
              SizedBox(height: 4),
              Text('2. Copy the exported files to your Flutter project'),
              SizedBox(height: 4),
              Text('3. Add gameframework_unity dependency'),
              SizedBox(height: 4),
              Text('4. Uncomment the GameWidget in this example'),
              SizedBox(height: 16),
              Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Bidirectional communication'),
              SizedBox(height: 4),
              Text('• Lifecycle management'),
              SizedBox(height: 4),
              Text('• Scene load events'),
              SizedBox(height: 4),
              Text('• JSON message support'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
