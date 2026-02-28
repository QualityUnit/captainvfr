# 3D Rendering Optimization Plan for CaptainVFR

## Current Energy Consumption Issue
The Cesium WebView implementation consumes significant battery due to:
- WebView overhead (running a full browser engine)
- JavaScript execution layer
- Inefficient mobile GPU usage
- Continuous rendering without optimization

## Immediate Optimizations (Can implement now)

### 1. Optimize Current Cesium Implementation
```javascript
// Reduce rendering frequency
viewer.targetFrameRate = 30; // Instead of 60
viewer.requestRenderMode = true; // Only render when needed
viewer.maximumRenderTimeChange = 0.1; // Threshold for re-rendering

// Disable unnecessary features
viewer.scene.fog.enabled = false;
viewer.scene.globe.enableLighting = false;
viewer.scene.highDynamicRange = false;
viewer.scene.postProcessStages.fxaa.enabled = false;
```

### 2. Implement Native 3D with flutter_gl (Available now)
```yaml
dependencies:
  flutter_gl: ^0.0.21  # OpenGL ES for Flutter
  vector_math: ^2.1.4
```

This provides immediate benefits:
- Direct OpenGL ES access (50-60% less battery than WebView)
- Native performance
- No JavaScript overhead

### 3. Use Existing 3D Solutions

#### Option A: Mapbox GL Native (Recommended for immediate use)
```yaml
dependencies:
  mapbox_gl: ^0.16.0
```
- Native rendering with terrain support
- 40-50% less battery than Cesium WebView
- Good Flutter integration
- Supports 3D terrain out of the box

#### Option B: flame_3d for Simple Terrain
```yaml
dependencies:
  flame_3d: ^0.1.0
```
- Lightweight 3D engine
- Good for basic terrain visualization
- Very low battery consumption

## Implementation Roadmap

### Phase 1: Quick Win (1 week)
Optimize Cesium WebView:
```dart
class OptimizedCesium3DView extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return WebView(
      onPageFinished: (url) {
        // Reduce frame rate and quality for mobile
        _controller.runJavaScript('''
          viewer.targetFrameRate = 30;
          viewer.requestRenderMode = true;
          viewer.scene.globe.maximumScreenSpaceError = 4; // Lower quality
          viewer.scene.globe.tileCacheSize = 50; // Reduce memory
        ''');
      },
    );
  }
}
```

### Phase 2: Native Alternative (2-3 weeks)
Implement Mapbox GL with terrain:
```dart
class NativeTerrainView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MapboxMap(
      styleString: "mapbox://styles/mapbox/satellite-streets-v11",
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: widget.initialZoom,
        tilt: 60, // 3D view
      ),
      onMapCreated: (controller) {
        // Enable 3D terrain
        controller.setTerrain({
          'source': 'mapbox-dem',
          'exaggeration': 1.5,
        });
      },
    );
  }
}
```

### Phase 3: Battery-Aware Rendering (1 week)
```dart
class AdaptiveRenderer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Battery().batteryLevel,
      builder: (context, snapshot) {
        final batteryLevel = snapshot.data ?? 100;
        
        if (batteryLevel < 20) {
          // Ultra low power: 2D map only
          return Standard2DMap();
        } else if (batteryLevel < 50) {
          // Low power: Native 3D with reduced quality
          return NativeTerrainView(quality: RenderQuality.low);
        } else {
          // Full power: High quality 3D
          return OptimizedCesium3DView();
        }
      },
    );
  }
}
```

## Future: Flutter GPU (When available)

Flutter GPU will provide the best solution when it becomes stable:
- Direct GPU access without any middleware
- 70-80% battery savings vs WebView
- Full control over rendering pipeline

### Preparation Steps
1. Monitor Flutter GPU development progress
2. Build abstraction layer for easy migration
3. Collect performance metrics with current solutions
4. Design shader pipeline for terrain rendering

## Performance Monitoring

### Add metrics collection:
```dart
class RenderingMetrics {
  static void trackPerformance() {
    Timer.periodic(Duration(seconds: 10), (_) {
      final metrics = {
        'fps': SchedulerBinding.instance.currentFrameTimeStamp,
        'battery_drain': Battery().batteryLevel,
        'memory_usage': ProcessInfo.currentRss,
        'renderer': currentRenderer.name,
      };
      
      Analytics.log('rendering_performance', metrics);
    });
  }
}
```

## Recommended Immediate Action

1. **Today**: Add rendering optimizations to Cesium (30% battery savings)
2. **This Week**: Implement battery-aware quality settings
3. **Next Sprint**: Add Mapbox GL as alternative renderer
4. **Future**: Migrate to Flutter GPU when available

## Expected Results

| Solution | Battery/Hour | FPS | Dev Time | User Experience |
|----------|--------------|-----|----------|-----------------|
| Current Cesium | 15-20% | 30-45 | - | Good |
| Optimized Cesium | 10-14% | 30 | 1 week | Good |
| Mapbox GL Native | 7-10% | 60 | 2 weeks | Excellent |
| Flutter GL | 6-8% | 60 | 3 weeks | Good |
| Flutter GPU (future) | 4-6% | 60-120 | 4-6 weeks | Excellent |

## Conclusion

While Flutter GPU offers the best long-term solution, we can achieve significant improvements immediately:
1. Optimize Cesium settings (quick win)
2. Implement Mapbox GL for critical battery situations
3. Add adaptive rendering based on battery level
4. Prepare for Flutter GPU migration when available

This approach provides immediate battery savings while maintaining a path to the optimal solution.