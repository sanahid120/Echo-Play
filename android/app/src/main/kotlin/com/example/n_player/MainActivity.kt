package com.example.n_player

import android.content.ContentResolver
import android.content.ContentUris
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.provider.MediaStore
import android.database.Cursor
import android.Manifest
import androidx.core.content.ContextCompat
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val channelName = "echoplay/local_media"
    private val permissionRequestCode = 901
    private val scanner = Executors.newSingleThreadExecutor()
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                "requestMediaAccess" -> requestMediaAccess(result)
                "scanPage" -> scanner.execute {
                    try {
                        val kind = call.argument<String>("kind") ?: "all"
                        val offset = call.argument<Int>("offset") ?: 0
                        val limit = (call.argument<Int>("limit") ?: 200).coerceIn(1, 500)
                        val items = mutableListOf<Map<String, Any?>>()
                        if (kind == "all" || kind == "audio") items.addAll(queryAudio(offset, limit))
                        if (kind == "all" || kind == "video") items.addAll(queryVideo(offset, limit))
                        runOnUiThread { result.success(items) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("SCAN_FAILED", error.message, null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestMediaAccess(result: MethodChannel.Result) {
        val audioPermission = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE
        val videoPermission = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_VIDEO else Manifest.permission.READ_EXTERNAL_STORAGE
        val permissions = if (Build.VERSION.SDK_INT >= 33) arrayOf(audioPermission, videoPermission) else arrayOf(audioPermission)
        val current = permissions.associateWith { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }
        if (current.values.all { it }) {
            result.success(mapOf("audio" to true, "video" to true))
            return
        }
        permissionResult = result
        requestPermissions(permissions, permissionRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val grants = permissions.mapIndexed { index, permission ->
            permission to (grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED)
        }.toMap()
        val isAndroid13OrNewer = Build.VERSION.SDK_INT >= 33
        permissionResult?.success(
            mapOf(
                "audio" to if (isAndroid13OrNewer) grants[Manifest.permission.READ_MEDIA_AUDIO] == true else grants[Manifest.permission.READ_EXTERNAL_STORAGE] == true,
                "video" to if (isAndroid13OrNewer) grants[Manifest.permission.READ_MEDIA_VIDEO] == true else grants[Manifest.permission.READ_EXTERNAL_STORAGE] == true
            )
        )
        permissionResult = null
    }

    private fun queryAudio(offset: Int, limit: Int): List<Map<String, Any?>> {
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        else MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        return query(collection, arrayOf(
            MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST, MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION, MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED, MediaStore.Audio.Media.SIZE
        ), null, "${MediaStore.Audio.Media.DATE_ADDED} DESC", "audio", offset, limit)
    }

    private fun queryVideo(offset: Int, limit: Int): List<Map<String, Any?>> {
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        return query(collection, arrayOf(
            MediaStore.Video.Media._ID, MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.DURATION, MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DATE_ADDED, MediaStore.Video.Media.SIZE
        ), null, "${MediaStore.Video.Media.DATE_ADDED} DESC", "video", offset, limit)
    }

    private fun query(
        uri: android.net.Uri,
        projection: Array<String>,
        selection: String?,
        order: String,
        type: String,
        offset: Int,
        limit: Int,
    ): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        val cursor: Cursor? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val queryArgs = Bundle().apply {
                putInt(ContentResolver.QUERY_ARG_LIMIT, limit)
                putInt(ContentResolver.QUERY_ARG_OFFSET, offset)
                putStringArray(ContentResolver.QUERY_ARG_SORT_COLUMNS, arrayOf(MediaStore.MediaColumns.DATE_ADDED))
                putInt(ContentResolver.QUERY_ARG_SORT_DIRECTION, ContentResolver.QUERY_SORT_DIRECTION_DESCENDING)
            }
            contentResolver.query(uri, projection, queryArgs, null)
        } else {
            contentResolver.query(uri, projection, selection, null, order)
        }
        cursor?.use { c ->
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                repeat(offset) { if (!c.moveToNext()) return@use }
            }
            val idCol = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.MediaColumns.TITLE)
            val pathCol = c.getColumnIndex(MediaStore.MediaColumns.DATA)
            val durationCol = c.getColumnIndex(MediaStore.MediaColumns.DURATION)
            val sizeCol = c.getColumnIndex(MediaStore.MediaColumns.SIZE)
            val addedCol = c.getColumnIndex(MediaStore.MediaColumns.DATE_ADDED)
            val artistCol = c.getColumnIndex("artist")
            val albumCol = c.getColumnIndex("album")
            while (items.size < limit && c.moveToNext()) {
                val id = c.getLong(idCol)
                val path = if (pathCol >= 0) c.getString(pathCol) else null
                if (path.isNullOrBlank()) continue
                items.add(mapOf(
                    "id" to "$type:$id", "type" to type,
                    "title" to c.getString(titleCol).orEmpty().ifBlank { path.substringAfterLast('/') },
                    "artist" to if (artistCol >= 0) c.getString(artistCol) else null,
                    "album" to if (albumCol >= 0) c.getString(albumCol) else null,
                    "path" to path,
                    "uri" to ContentUris.withAppendedId(uri, id).toString(),
                    "durationMs" to if (durationCol >= 0) c.getLong(durationCol) else 0L,
                    "sizeBytes" to if (sizeCol >= 0) c.getLong(sizeCol) else 0L,
                    "dateAdded" to if (addedCol >= 0) c.getLong(addedCol) else 0L
                ))
            }
        }
        return items
    }

    override fun onDestroy() {
        scanner.shutdown()
        super.onDestroy()
    }
}
