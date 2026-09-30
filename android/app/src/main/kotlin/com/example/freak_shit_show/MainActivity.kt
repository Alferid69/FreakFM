package com.example.freak_shit_show

import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Size
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.example.freak_shit_show/media_store"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryAudioFiles" -> {
                    try {
                        val songs = queryMediaStoreAudio()
                        result.success(songs)
                    } catch (e: Exception) {
                        result.error("QUERY_ERROR", e.message, null)
                    }
                }
                "getArtwork" -> {
                    try {
                        val songId = call.argument<String>("songId") ?: ""
                        val filePath = call.argument<String>("filePath") ?: ""
                        val contentUri = call.argument<String>("contentUri") ?: ""
                        val albumId = (call.argument<Any>("albumId") as? Number)?.toLong() ?: 0L
                        val artPath = getArtwork(songId, filePath, contentUri, albumId)
                        result.success(artPath)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "shareImage" -> {
                    try {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val title = call.argument<String>("title") ?: "Share Lyrics"
                        val file = File(filePath)
                        if (file.exists()) {
                            val uri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            val chooser = Intent.createChooser(shareIntent, title)
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(chooser)
                            result.success(true)
                        } else {
                            result.error("FILE_NOT_FOUND", "File not found: $filePath", null)
                        }
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "shareText" -> {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        val title = call.argument<String>("title") ?: "Share Lyrics"
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        val chooser = Intent.createChooser(shareIntent, title)
                        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getArtwork(songId: String, path: String, contentUriString: String, albumId: Long): String? {
        try {
            val safeId = if (songId.isNotBlank()) songId else path.hashCode().toString()
            val cacheFile = File(cacheDir, "art_${safeId.hashCode()}.jpg")
            if (cacheFile.exists() && cacheFile.length() > 0) {
                return cacheFile.absolutePath
            }

            var imageBytes: ByteArray? = null

            // 1. Try MediaMetadataRetriever (embedded picture in audio file - song's OWN logo/artwork)
            try {
                val mmr = MediaMetadataRetriever()
                if (path.isNotEmpty() && File(path).exists()) {
                    mmr.setDataSource(path)
                    imageBytes = mmr.embeddedPicture
                } else if (contentUriString.isNotEmpty()) {
                    mmr.setDataSource(this, Uri.parse(contentUriString))
                    imageBytes = mmr.embeddedPicture
                }
                mmr.release()
            } catch (_: Exception) {}

            // 2. Try MediaStore albumart URI
            if (imageBytes == null && albumId > 0) {
                try {
                    val albumArtUri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)
                    contentResolver.openInputStream(albumArtUri)?.use { input ->
                        imageBytes = input.readBytes()
                    }
                } catch (_: Exception) {}
            }

            // 3. Try ContentResolver.loadThumbnail for Android 10+ (API 29+)
            if (imageBytes == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && contentUriString.isNotEmpty()) {
                try {
                    val uri = Uri.parse(contentUriString)
                    val bitmap = contentResolver.loadThumbnail(uri, Size(512, 512), null)
                    val out = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                    imageBytes = out.toByteArray()
                } catch (_: Exception) {}
            }

            if (imageBytes != null && imageBytes.isNotEmpty()) {
                FileOutputStream(cacheFile).use { fos ->
                    fos.write(imageBytes)
                    fos.flush()
                }
                return cacheFile.absolutePath
            }
        } catch (_: Exception) {}
        return null
    }

    private fun queryMediaStoreAudio(): List<Map<String, Any?>> {
        val songList = mutableListOf<Map<String, Any?>>()
        val uri: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

        val projectionList = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.ALBUM_ID
        )

        val hasGenreColumn = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        if (hasGenreColumn) {
            try {
                projectionList.add(MediaStore.Audio.Media.GENRE)
            } catch (_: Exception) {}
        }

        val projection = projectionList.toTypedArray()

        // Filter out very short notification tones / sound effects (< 3 seconds or < 10KB)
        val selection = "(${MediaStore.Audio.Media.IS_MUSIC} != 0 OR ${MediaStore.Audio.Media.DURATION} >= 3000) AND ${MediaStore.Audio.Media.SIZE} > 10000"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        try {
            contentResolver.query(uri, projection, selection, null, sortOrder)?.use { cursor ->
                val idCol = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
                val durationCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
                val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
                val dateAddedCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
                val albumIdCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
                val genreCol = if (hasGenreColumn) cursor.getColumnIndex(MediaStore.Audio.Media.GENRE) else -1

                while (cursor.moveToNext()) {
                    val id = if (idCol >= 0) cursor.getLong(idCol) else 0L
                    val rawTitle = if (titleCol >= 0) cursor.getString(titleCol) ?: "" else ""
                    val rawArtist = if (artistCol >= 0) cursor.getString(artistCol) ?: "" else ""
                    val rawAlbum = if (albumCol >= 0) cursor.getString(albumCol) ?: "" else ""
                    val duration = if (durationCol >= 0) cursor.getLong(durationCol) else 0L
                    val path = if (dataCol >= 0) cursor.getString(dataCol) ?: "" else ""
                    val size = if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L
                    val dateAdded = if (dateAddedCol >= 0) cursor.getLong(dateAddedCol) * 1000L else System.currentTimeMillis()
                    val albumId = if (albumIdCol >= 0) cursor.getLong(albumIdCol) else 0L
                    val rawGenre = if (genreCol >= 0) cursor.getString(genreCol) ?: "" else ""

                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id).toString()

                    val folder = if (path.isNotEmpty()) {
                        val parts = path.split("/")
                        if (parts.size >= 2) parts[parts.size - 2] else "Internal"
                    } else "Internal"

                    val title = if (rawTitle.isBlank()) {
                        if (path.isNotEmpty()) {
                            val fileName = path.substringAfterLast("/")
                            fileName.substringBeforeLast(".")
                        } else "Track $id"
                    } else rawTitle

                    val artist = if (rawArtist.isBlank() || rawArtist.equals("<unknown>", ignoreCase = true)) {
                        "Unknown Artist"
                    } else rawArtist

                    val album = if (rawAlbum.isBlank() || rawAlbum.equals("<unknown>", ignoreCase = true)) {
                        folder
                    } else rawAlbum

                    val songMap = mapOf<String, Any?>(
                        "id" to id.toString(),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "durationMs" to duration,
                        "filePath" to if (path.isNotBlank()) path else contentUri,
                        "contentUri" to contentUri,
                        "fileSize" to size,
                        "folder" to folder,
                        "genre" to if (rawGenre.isNotBlank()) rawGenre else "Music",
                        "dateAdded" to dateAdded,
                        "albumId" to albumId
                    )
                    songList.add(songMap)
                }
            }
        } catch (_: Exception) {}

        return songList
    }
}
