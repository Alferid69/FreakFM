package com.example.freak_shit_show

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.example.freak_shit_show/media_store"

    // MediaStore queries and artwork extraction can take hundreds of ms per
    // call; run them off the UI thread so the app never janks or ANRs.
    private val queryExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val artworkExecutor: ExecutorService = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    override fun onDestroy() {
        queryExecutor.shutdown()
        artworkExecutor.shutdown()
        super.onDestroy()
    }

    private fun runInBackground(
        executor: ExecutorService,
        result: MethodChannel.Result,
        errorCode: String,
        block: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error(errorCode, e.message, null) }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryAudioFiles" -> runInBackground(queryExecutor, result, "QUERY_ERROR") {
                    queryMediaStoreAudio()
                }
                "getArtwork" -> {
                    val targetPath = call.argument<String>("targetPath") ?: ""
                    val filePath = call.argument<String>("filePath") ?: ""
                    val contentUri = call.argument<String>("contentUri") ?: ""
                    val albumId = (call.argument<Any>("albumId") as? Number)?.toLong() ?: 0L
                    runInBackground(artworkExecutor, result, "ARTWORK_ERROR") {
                        getArtwork(targetPath, filePath, contentUri, albumId)
                    }
                }
                "saveImageToGallery" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val fileName = call.argument<String>("fileName") ?: File(filePath).name
                    runInBackground(queryExecutor, result, "SAVE_ERROR") {
                        saveImageToGallery(File(filePath), fileName)
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
                else -> result.notImplemented()
            }
        }
    }

    private fun getArtwork(targetPath: String, path: String, contentUriString: String, albumId: Long): String? {
        if (targetPath.isEmpty()) return null
        val cacheFile = File(targetPath)
        if (cacheFile.exists() && cacheFile.length() > 0) {
            return cacheFile.absolutePath
        }

        var imageBytes: ByteArray? = null

        // 1. Picture embedded in the audio file itself.
        val mmr = MediaMetadataRetriever()
        try {
            if (path.isNotEmpty() && File(path).exists()) {
                mmr.setDataSource(path)
            } else if (contentUriString.isNotEmpty()) {
                mmr.setDataSource(this, Uri.parse(contentUriString))
            }
            imageBytes = mmr.embeddedPicture
        } catch (_: Exception) {
        } finally {
            try {
                mmr.release()
            } catch (_: Exception) {
            }
        }

        // 2. MediaStore album art.
        if (imageBytes == null && albumId > 0) {
            try {
                val albumArtUri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)
                contentResolver.openInputStream(albumArtUri)?.use { input ->
                    imageBytes = input.readBytes()
                }
            } catch (_: Exception) {
            }
        }

        // 3. System thumbnail (Android 10+).
        if (imageBytes == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && contentUriString.isNotEmpty()) {
            try {
                val bitmap = contentResolver.loadThumbnail(Uri.parse(contentUriString), Size(512, 512), null)
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                imageBytes = out.toByteArray()
            } catch (_: Exception) {
            }
        }

        val bytes = imageBytes ?: return null
        if (bytes.isEmpty()) return null
        cacheFile.parentFile?.mkdirs()
        FileOutputStream(cacheFile).use { it.write(bytes) }
        return cacheFile.absolutePath
    }

    /** Inserts an image into Pictures/FreakFM so it shows up in the gallery. */
    private fun saveImageToGallery(source: File, fileName: String): String {
        if (!source.exists()) throw IllegalArgumentException("File not found: ${source.path}")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/FreakFM")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = contentResolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            contentResolver.openOutputStream(uri)?.use { out ->
                source.inputStream().use { it.copyTo(out) }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return "Pictures/FreakFM/$fileName"
        }

        // Android 9 and below: app-specific pictures folder (no extra permission).
        val dir = getExternalFilesDir(Environment.DIRECTORY_PICTURES) ?: filesDir
        val target = File(dir, fileName)
        source.copyTo(target, overwrite = true)
        return target.absolutePath
    }

    private fun queryMediaStoreAudio(): List<Map<String, Any?>> {
        val songList = mutableListOf<Map<String, Any?>>()
        val uri: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

        val baseProjection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.ALBUM_ID,
        )
        val hasGenreColumn = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        val extendedProjection = baseProjection + arrayOf(MediaStore.Audio.Media.YEAR) +
            (if (hasGenreColumn) arrayOf(MediaStore.Audio.Media.GENRE, MediaStore.Audio.Media.BITRATE) else emptyArray())

        // Every audio file the system indexed that is music or at least 3 s
        // long, anywhere on the device. Users hide unwanted folders in-app.
        val selection = buildString {
            append("(${MediaStore.Audio.Media.IS_MUSIC} != 0 OR ${MediaStore.Audio.Media.DURATION} >= 3000)")
            append(" AND ${MediaStore.Audio.Media.SIZE} > 10000")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Skip files that are still being downloaded/written.
                append(" AND ${MediaStore.Audio.Media.IS_PENDING} = 0")
            }
        }
        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        // Some OEM builds reject optional columns; fall back to the basics.
        val result = try {
            contentResolver.query(uri, extendedProjection, selection, null, sortOrder)
        } catch (_: Exception) {
            contentResolver.query(uri, baseProjection, selection, null, sortOrder)
        }

        result?.use { cursor ->
            val idCol = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durationCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
            val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
            val dateAddedCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val albumIdCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
            val yearCol = cursor.getColumnIndex(MediaStore.Audio.Media.YEAR)
            val genreCol = if (hasGenreColumn) cursor.getColumnIndex(MediaStore.Audio.Media.GENRE) else -1
            val bitrateCol = if (hasGenreColumn) cursor.getColumnIndex(MediaStore.Audio.Media.BITRATE) else -1

            while (cursor.moveToNext()) {
                val id = if (idCol >= 0) cursor.getLong(idCol) else continue
                val path = if (dataCol >= 0) cursor.getString(dataCol) ?: "" else ""
                if (path.isBlank()) continue

                val rawTitle = if (titleCol >= 0) cursor.getString(titleCol) ?: "" else ""
                val rawArtist = if (artistCol >= 0) cursor.getString(artistCol) ?: "" else ""
                val rawAlbum = if (albumCol >= 0) cursor.getString(albumCol) ?: "" else ""
                val rawGenre = if (genreCol >= 0) cursor.getString(genreCol) ?: "" else ""
                val year = if (yearCol >= 0) cursor.getInt(yearCol) else 0

                val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id).toString()
                val folder = File(path).parentFile?.name ?: "Internal"

                val title = rawTitle.ifBlank { File(path).nameWithoutExtension }
                val artist = if (rawArtist.isBlank() || rawArtist.equals("<unknown>", ignoreCase = true)) "Unknown Artist" else rawArtist
                val album = if (rawAlbum.isBlank() || rawAlbum.equals("<unknown>", ignoreCase = true)) folder else rawAlbum

                songList.add(
                    mapOf(
                        "id" to id.toString(),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "durationMs" to (if (durationCol >= 0) cursor.getLong(durationCol) else 0L),
                        "filePath" to path,
                        "contentUri" to contentUri,
                        "fileSize" to (if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L),
                        "folder" to folder,
                        "genre" to rawGenre,
                        "year" to (if (year > 0) year else null),
                        "bitrate" to (if (bitrateCol >= 0) cursor.getLong(bitrateCol) else 0L),
                        "dateAdded" to (if (dateAddedCol >= 0) cursor.getLong(dateAddedCol) * 1000L else System.currentTimeMillis()),
                        "albumId" to (if (albumIdCol >= 0) cursor.getLong(albumIdCol) else 0L),
                    )
                )
            }
        }
        return songList
    }
}
