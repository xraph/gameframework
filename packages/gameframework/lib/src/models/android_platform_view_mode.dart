/// Android platform view rendering modes
///
/// Different modes have different performance characteristics and limitations.
/// See: https://docs.flutter.dev/platform-integration/android/platform-views
enum AndroidPlatformViewMode {
  /// Hybrid Composition (Recommended)
  ///
  /// Uses Android's platform view system to compose the view directly in the
  /// view hierarchy. This mode provides:
  /// - Better performance on Android 10+ (no extra texture copies)
  /// - More accurate touch input handling
  /// - Better accessibility support
  /// - Native scrolling and text field behavior
  ///
  /// **Minimum SDK:** Android 19 (API level 19)
  ///
  /// This is the default and recommended mode for most use cases.
  hybridComposition,

  /// Virtual Display (Texture Layer)
  ///
  /// Renders the Android view to a virtual display, which is then composed
  /// as a texture in Flutter's rendering pipeline. This mode:
  /// - Works on older Android versions
  /// - May have slightly higher memory usage
  /// - Requires additional texture buffer copies
  /// - Good for complex animations with platform views
  ///
  /// **Minimum SDK:** Android 20 (API level 20)
  ///
  /// Use this mode if you need better performance during animations or
  /// if hybrid composition causes issues with your specific view.
  virtualDisplay,
}

extension AndroidPlatformViewModeExtension on AndroidPlatformViewMode {
  /// Human-readable name for the mode
  String get displayName {
    switch (this) {
      case AndroidPlatformViewMode.hybridComposition:
        return 'Hybrid Composition';
      case AndroidPlatformViewMode.virtualDisplay:
        return 'Virtual Display (Texture Layer)';
    }
  }

  /// Minimum Android SDK version required for this mode
  int get minimumSdk {
    switch (this) {
      case AndroidPlatformViewMode.hybridComposition:
        return 19;
      case AndroidPlatformViewMode.virtualDisplay:
        return 20;
    }
  }

  /// Description of when to use this mode
  String get description {
    switch (this) {
      case AndroidPlatformViewMode.hybridComposition:
        return 'Best performance and compatibility. Recommended for most use cases.';
      case AndroidPlatformViewMode.virtualDisplay:
        return 'Better for complex animations. Use if hybrid composition causes issues.';
    }
  }
}

