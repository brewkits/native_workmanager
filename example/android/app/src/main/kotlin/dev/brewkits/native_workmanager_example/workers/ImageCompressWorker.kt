package dev.brewkits.native_workmanager_example.workers

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult // Added import for WorkerResult
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.io.FileOutputStream

class ImageCompressWorker : AndroidWorker {
    override suspend fun doWork(input: String?): WorkerResult { // Changed return type to WorkerResult
        try {
            // Parse JSON input
            val json = Json.parseToJsonElement(input ?: "{}")
            val config = json.jsonObject

            val inputPath = config["inputPath"]?.jsonPrimitive?.content
                ?: return WorkerResult.Failure("Input path or output path missing")
            val outputPath = config["outputPath"]?.jsonPrimitive?.content
                ?: return WorkerResult.Failure("Input path or output path missing")
            val quality = config["quality"]?.jsonPrimitive?.content?.toIntOrNull()
                ?: 85

            // Load image
            val bitmap = BitmapFactory.decodeFile(inputPath)
                ?: return WorkerResult.Failure("Failed to load image from input path")

            // Compress and save
            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()

            FileOutputStream(outputFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
            }

            bitmap.recycle()
            return WorkerResult.Success()

        } catch (e: Exception) {
            println("ImageCompressWorker error: ${e.message}")
            return WorkerResult.Failure("Image compression failed: ${e.message}")
        }
    }
}
