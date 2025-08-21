package com.captainvfr.captainvfr

import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Log device information for debugging
        Log.d(TAG, "CaptainVFR Starting - Android ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})")
        Log.d(TAG, "Device: ${Build.MANUFACTURER} ${Build.MODEL}")
        
        // Enable edge-to-edge mode for Android 15+
        if (Build.VERSION.SDK_INT >= 35) {
            // This is the new way to handle edge-to-edge in Android 15
            // Flutter will handle this internally in future versions
            window.setDecorFitsSystemWindows(false)
        }
        
        // NOTE: Permission requests are now handled by Flutter plugins (geolocator, permission_handler)
        // to avoid conflicts with request codes. Do not request permissions here.
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register plugins
        flutterEngine.plugins.add(AltitudePlugin())
        flutterEngine.plugins.add(NetworkPlugin())
        flutterEngine.plugins.add(VibrationPlugin())
        flutterEngine.plugins.add(WatchConnectivityPlugin())
        flutterEngine.plugins.add(LocalePlugin())
        
        Log.d(TAG, "Flutter plugins registered")
    }

    // Permission handling has been moved to Flutter plugins to avoid conflicts
}
