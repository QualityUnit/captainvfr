package com.captainvfr.captainvfr

import android.content.Context
import android.util.Log
import java.util.Locale
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class LocalePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val TAG = "LocalePlugin"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "captainvfr/locale")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        Log.d(TAG, "LocalePlugin attached to engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getSystemLanguage" -> {
                val systemLanguage = getSystemLanguage()
                Log.d(TAG, "System language detected: $systemLanguage")
                result.success(systemLanguage)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun getSystemLanguage(): String {
        return try {
            val locale = Locale.getDefault()
            val languageCode = locale.language
            
            Log.d(TAG, "System locale: $locale, Language code: $languageCode")
            
            // Return the language code (e.g., "en", "de", "fr")
            languageCode
        } catch (e: Exception) {
            Log.e(TAG, "Error getting system language", e)
            // Fall back to English if detection fails
            "en"
        }
    }
}