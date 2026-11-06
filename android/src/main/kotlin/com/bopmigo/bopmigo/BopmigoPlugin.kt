package com.bopmigo.bopmigo

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** The small native part of Bopmigo for Flutter: app and device details, and screenshot detection. */
class BopmigoPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var watching = false
    private var callback: Any? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "bopmigo")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> result.success(info())
            "watchScreenshots" -> {
                watching = call.arguments as? Boolean ?: false
                stopWatching()
                startWatching()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun info(): Map<String, Any> {
        val pm = context.packageManager
        val pkg = context.packageName
        val p = try { pm.getPackageInfo(pkg, 0) } catch (e: Exception) { null }
        val build = if (p == null) "?" else if (Build.VERSION.SDK_INT >= 28) p.longVersionCode.toString() else @Suppress("DEPRECATION") p.versionCode.toString()
        val name = try { pm.getApplicationLabel(context.applicationInfo).toString() } catch (e: Exception) { "App" }
        val emulator = Build.FINGERPRINT.contains("generic") || Build.MODEL.contains("sdk_gphone") || Build.MODEL.contains("Emulator")
        val model = "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}" + if (emulator) " (Emulator)" else ""
        return mapOf(
            "version" to (p?.versionName ?: "?"),
            "build" to build,
            "name" to name,
            "appId" to pkg,
            "device" to model,
            "os" to "Android ${Build.VERSION.RELEASE}",
            "tester" to isTester(),
            "language" to java.util.Locale.getDefault().toLanguageTag(),
            "timezone" to java.util.TimeZone.getDefault().id,
        )
    }

    /** Debug builds and anything not installed from Google Play (internal testing installs come from Play too, so testers there count as Play installs). */
    private fun isTester(): Boolean {
        if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) return true
        val installer = try {
            if (Build.VERSION.SDK_INT >= 30) context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
            else @Suppress("DEPRECATION") context.packageManager.getInstallerPackageName(context.packageName)
        } catch (e: PackageManager.NameNotFoundException) { null }
        return installer != "com.android.vending"
    }

    // Android 14 and later tell apps when a screenshot is taken. Older versions don't, so the button is the way in.
    private fun startWatching() {
        val a = activity ?: return
        if (!watching || Build.VERSION.SDK_INT < 34) return
        val cb = Activity.ScreenCaptureCallback { channel.invokeMethod("screenshot", null) }
        try { a.registerScreenCaptureCallback(a.mainExecutor, cb); callback = cb } catch (e: SecurityException) { callback = null }
    }

    private fun stopWatching() {
        val a = activity ?: return
        if (Build.VERSION.SDK_INT >= 34) (callback as? Activity.ScreenCaptureCallback)?.let { a.unregisterScreenCaptureCallback(it) }
        callback = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity; startWatching() }
    override fun onDetachedFromActivityForConfigChanges() { stopWatching(); activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity; startWatching() }
    override fun onDetachedFromActivity() { stopWatching(); activity = null }
}
