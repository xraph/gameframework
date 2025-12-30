import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

/// Example demonstrating Android platform view mode switching
///
/// This example shows how to use both Hybrid Composition and Virtual Display
/// modes with the Game Framework.
class PlatformViewModesExample extends StatefulWidget {
  const PlatformViewModesExample({super.key});

  @override
  State<PlatformViewModesExample> createState() =>
      _PlatformViewModesExampleState();
}

class _PlatformViewModesExampleState extends State<PlatformViewModesExample> {
  AndroidPlatformViewMode _currentMode =
      AndroidPlatformViewMode.hybridComposition;
  GameEngineController? _controller;
  bool _isEngineReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android Platform View Modes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Mode selector card
          _buildModeSelector(),

          // Game view
          Expanded(
            child: _buildGameView(),
          ),

          // Status indicator
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform View Mode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<AndroidPlatformViewMode>(
              segments: [
                ButtonSegment(
                  value: AndroidPlatformViewMode.hybridComposition,
                  label: const Text('Hybrid'),
                  icon: const Icon(Icons.layers),
                  tooltip: AndroidPlatformViewMode
                      .hybridComposition.description,
                ),
                ButtonSegment(
                  value: AndroidPlatformViewMode.virtualDisplay,
                  label: const Text('Virtual Display'),
                  icon: const Icon(Icons.view_in_ar),
                  tooltip:
                      AndroidPlatformViewMode.virtualDisplay.description,
                ),
              ],
              selected: {_currentMode},
              onSelectionChanged: (Set<AndroidPlatformViewMode> modes) {
                setState(() {
                  _currentMode = modes.first;
                  _isEngineReady = false;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _currentMode.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Min SDK: ${_currentMode.minimumSdk}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GameWidget(
          key: ValueKey(_currentMode), // Force rebuild on mode change
          engineType: GameEngineType.unity,
          config: GameEngineConfig(
            androidPlatformViewMode: _currentMode,
            runImmediately: true,
            enableDebugLogs: true,
          ),
          onEngineCreated: (controller) {
            setState(() {
              _controller = controller;
              _isEngineReady = false;
            });
          },
          onEngineUnloaded: () {
            setState(() {
              _isEngineReady = false;
            });
          },
          enablePlaceholder: true,
          placeholder: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading Unity (${_currentMode.displayName})...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _isEngineReady ? Colors.green.shade100 : Colors.orange.shade100,
      child: Row(
        children: [
          Icon(
            _isEngineReady ? Icons.check_circle : Icons.pending,
            color: _isEngineReady ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isEngineReady
                  ? 'Engine Ready (${_currentMode.displayName})'
                  : 'Initializing engine...',
              style: TextStyle(
                color: _isEngineReady ? Colors.green.shade900 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
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

/// Information card explaining platform view modes
class PlatformViewModeInfoCard extends StatelessWidget {
  const PlatformViewModeInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Platform View Modes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildModeInfo(
              context,
              'Hybrid Composition',
              Icons.layers,
              Colors.blue,
              [
                'Best performance on Android 10+',
                'Accurate touch input',
                'Better accessibility',
                'Recommended for most use cases',
              ],
            ),
            const SizedBox(height: 16),
            _buildModeInfo(
              context,
              'Virtual Display',
              Icons.view_in_ar,
              Colors.purple,
              [
                'Better for complex animations',
                'Higher memory usage',
                'Good for page transitions',
                'Use when hybrid has issues',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeInfo(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<String> features,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature)),
                ],
              ),
            )),
      ],
    );
  }
}

