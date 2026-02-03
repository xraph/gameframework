import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unreal/gameframework_unreal.dart';

/// Example screen demonstrating Unreal Engine integration with Flutter.
/// Features the same rotating cube demo as the Unity example for comparison.
class UnrealExampleScreen extends StatefulWidget {
  const UnrealExampleScreen({super.key});

  @override
  State<UnrealExampleScreen> createState() => _UnrealExampleScreenState();
}

class _UnrealExampleScreenState extends State<UnrealExampleScreen> {
  UnrealController? _controller;
  double _rotationSpeed = 50.0;
  String _rotationAxis = 'Y';
  bool _isReady = false;
  String _lastMessage = 'Initializing...';
  String _direction = '---';
  double _currentSpeed = 0;
  double _currentRpm = 0;
  final List<String> _logs = [];

  // Unreal-specific state
  String _qualityLevel = 'High';
  bool _showFps = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.deepPurple,
          thumbColor: Colors.purple,
          overlayColor: Colors.purple.withValues(alpha: 0.2),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Unreal game view (full screen)
            GameWidget(
              engineType: GameEngineType.unreal,
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

            // Quality settings button
            Positioned(
              top: 40,
              right: 10,
              child: SafeArea(
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onSelected: _setQuality,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Low', child: Text('Low')),
                    const PopupMenuItem(value: 'Medium', child: Text('Medium')),
                    const PopupMenuItem(value: 'High', child: Text('High')),
                    const PopupMenuItem(value: 'Epic', child: Text('Epic')),
                    const PopupMenuItem(
                        value: 'Cinematic', child: Text('Cinematic')),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'fps',
                      child: Row(
                        children: [
                          Icon(_showFps
                              ? Icons.visibility
                              : Icons.visibility_off),
                          const SizedBox(width: 8),
                          const Text('Show FPS'),
                        ],
                      ),
                    ),
                  ],
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
                      CircularProgressIndicator(
                        color: Colors.purple,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading Unreal Engine...',
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
              Colors.purple,
            ),
            const Divider(color: Colors.white24, height: 20),
            _buildInfoRow(
              Icons.message,
              'Message',
              _lastMessage,
              Colors.deepPurple,
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
            const Divider(color: Colors.white24, height: 20),
            _buildInfoRow(
              Icons.high_quality,
              'Quality',
              _qualityLevel,
              Colors.cyan,
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
            // Title with Unreal branding
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videogame_asset, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Unreal Cube Controls',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
                    Colors.purple,
                    _getState,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Random Color',
                    Icons.palette,
                    Colors.deepPurple,
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
            Icon(icon, color: Colors.purpleAccent, size: 20),
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
                color: Colors.purpleAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${value.toStringAsFixed(0)}°/s',
                style: const TextStyle(
                  color: Colors.purpleAccent,
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
      _controller = controller as UnrealController;
    });
    _log('Unreal Engine created');
  }

  void _onMessage(GameEngineMessage message) {
    _log('Message received: ${message.method} - ${message.data}');

    final method = message.method;

    if (method == 'onReady') {
      setState(() {
        _isReady = true;
        _lastMessage = 'Unreal cube demo ready!';
        _direction = '← FROM UNREAL';
      });
    } else if (method == 'onSpeedChanged') {
      try {
        final data = message.asJson();
        if (data != null) {
          setState(() {
            _currentSpeed = (data['speed'] as num?)?.toDouble() ?? 0;
            _currentRpm = (data['rpm'] as num?)?.toDouble() ?? 0;
            _lastMessage = 'Speed updated';
            _direction = '← FROM UNREAL';
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
        _direction = '← FROM UNREAL';
      });
    } else if (method == 'onState') {
      setState(() {
        _lastMessage = 'State received';
        _direction = '← FROM UNREAL';
      });
    } else if (method == 'onQualityChanged') {
      setState(() {
        _lastMessage = 'Quality changed';
        _direction = '← FROM UNREAL';
      });
    }
  }

  void _onSceneLoaded(GameSceneLoaded sceneInfo) {
    _log('Level loaded: ${sceneInfo.name}');
  }

  void _sendSpeed(double speed) {
    _controller?.sendMessage('GameFrameworkDemo', 'setSpeed', speed.toString());
    setState(() {
      _lastMessage = 'Speed set to ${speed.toStringAsFixed(0)}°/s';
      _direction = '→ TO UNREAL';
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
      _direction = '→ TO UNREAL';
    });
  }

  void _reset() {
    _controller?.sendMessage('GameFrameworkDemo', 'reset', '');
    setState(() {
      _rotationSpeed = 50;
      _rotationAxis = 'Y';
      _lastMessage = 'Reset requested';
      _direction = '→ TO UNREAL';
    });
  }

  void _getState() {
    _controller?.sendMessage('GameFrameworkDemo', 'getState', '');
    setState(() {
      _lastMessage = 'State requested';
      _direction = '→ TO UNREAL';
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
      _direction = '→ TO UNREAL';
    });
  }

  void _setQuality(String quality) {
    if (quality == 'fps') {
      setState(() => _showFps = !_showFps);
      _controller?.executeConsoleCommand(_showFps ? 'stat fps' : 'stat none');
      return;
    }

    setState(() => _qualityLevel = quality);

    // Apply quality settings
    UnrealQualitySettings settings;
    switch (quality) {
      case 'Low':
        settings = UnrealQualitySettings.low();
        break;
      case 'Medium':
        settings = UnrealQualitySettings.medium();
        break;
      case 'High':
        settings = UnrealQualitySettings.high();
        break;
      case 'Epic':
        settings = UnrealQualitySettings.epic();
        break;
      case 'Cinematic':
        settings = UnrealQualitySettings.cinematic();
        break;
      default:
        settings = UnrealQualitySettings.high();
    }

    _controller?.applyQualitySettings(settings);
    setState(() {
      _lastMessage = 'Quality set to $quality';
      _direction = '→ TO UNREAL';
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
