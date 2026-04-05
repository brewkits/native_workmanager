package dev.brewkits.native_workmanager.workers

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.put
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * Native PDF worker for Android.
 *
 * Supports three operations:
 * - **merge**: Merge multiple PDFs into one (PdfRenderer → PdfDocument).
 * - **compress**: Re-render a PDF at lower DPI to reduce file size.
 * - **imagesToPdf**: Combine image files into a PDF (one image per page).
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "operation": "merge",
 *   "inputPaths": ["/path/a.pdf", "/path/b.pdf"],
 *   "outputPath": "/path/out.pdf"
 * }
 * ```
 * ```json
 * {
 *   "operation": "compress",
 *   "inputPath": "/path/in.pdf",
 *   "outputPath": "/path/out.pdf",
 *   "quality": 80
 * }
 * ```
 * ```json
 * {
 *   "operation": "imagesToPdf",
 *   "imagePaths": ["/path/img1.jpg", "/path/img2.png"],
 *   "outputPath": "/path/out.pdf",
 *   "pageSize": "A4",
 *   "margin": 0
 * }
 * ```
 *
 * **Result data:**
 * ```json
 * { "outputPath": "...", "outputSize": 102400, "pageCount": 5 }
 * ```
 */
class PdfWorker : AndroidWorker {

    companion object {
        private const val TAG = "PdfWorker"

        // Page size constants in PDF points (1 pt = 1/72 inch).
        // Android PdfDocument uses pixels; we render at 72 DPI so 1 pt == 1 px here.
        private const val A4_WIDTH = 595
        private const val A4_HEIGHT = 842
        private const val LETTER_WIDTH = 612
        private const val LETTER_HEIGHT = 792

        /** Map quality (1–100) to render DPI for compress / merge operations. */
        private fun qualityToDpi(quality: Int): Int = when {
            quality >= 100 -> 300
            quality >= 80  -> 150
            quality >= 50  -> 96
            else           -> 72
        }
    }

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            return@withContext WorkerResult.Failure("Input JSON is required")
        }

        val j = try {
            JSONObject(input)
        } catch (e: Exception) {
            return@withContext WorkerResult.Failure("Invalid config JSON: ${e.message}")
        }

        return@withContext when (val operation = j.optString("operation", "")) {
            "merge"      -> merge(j)
            "compress"   -> compress(j)
            "imagesToPdf" -> imagesToPdf(j)
            else          -> WorkerResult.Failure("Unknown PDF operation: '$operation'")
        }
    }

    // ── merge ─────────────────────────────────────────────────────────────────

    private fun merge(j: JSONObject): WorkerResult {
        val inputPathsArray = j.optJSONArray("inputPaths")
            ?: return WorkerResult.Failure("'inputPaths' array is required for merge")
        val outputPath = j.optString("outputPath", "")
        if (outputPath.isEmpty()) return WorkerResult.Failure("'outputPath' is required")

        val inputPaths = (0 until inputPathsArray.length()).map { inputPathsArray.getString(it) }
        if (inputPaths.isEmpty()) return WorkerResult.Failure("'inputPaths' must not be empty")

        if (!SecurityValidator.validateFilePathSafe(outputPath)) {
            return WorkerResult.Failure("Invalid or unsafe output path")
        }
        for (inputPath in inputPaths) {
            if (!SecurityValidator.validateFilePathSafe(inputPath)) {
                return WorkerResult.Failure("Invalid or unsafe input path: $inputPath")
            }
        }

        val outputFile = File(outputPath)
        // MEDIA-009: surface mkdirs failure explicitly.
        val mergePdfParentDir = outputFile.parentFile
        if (mergePdfParentDir != null && !mergePdfParentDir.exists() && !mergePdfParentDir.mkdirs()) {
            return WorkerResult.Failure("Failed to create output directory: ${mergePdfParentDir.path}")
        }

        val outputDoc = PdfDocument()
        var totalPages = 0

        try {
            for (inputPath in inputPaths) {
                val inputFile = File(inputPath)
                if (!inputFile.exists()) {
                    outputDoc.close()
                    return WorkerResult.Failure("Input file not found: $inputPath")
                }

                val pfd = ParcelFileDescriptor.open(inputFile, ParcelFileDescriptor.MODE_READ_ONLY)
                val renderer = PdfRenderer(pfd)

                try {
                    for (pageIndex in 0 until renderer.pageCount) {
                        val page = renderer.openPage(pageIndex)
                        val width = page.width.takeIf { it > 0 } ?: A4_WIDTH
                        val height = page.height.takeIf { it > 0 } ?: A4_HEIGHT

                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        page.close()

                        val pageInfo = PdfDocument.PageInfo.Builder(width, height, totalPages + 1).create()
                        val outPage = outputDoc.startPage(pageInfo)
                        outPage.canvas.drawBitmap(bitmap, 0f, 0f, null)
                        outputDoc.finishPage(outPage)
                        bitmap.recycle()
                        totalPages++
                    }
                } finally {
                    renderer.close()
                    pfd.close()
                }
            }

            FileOutputStream(outputFile).use { fos -> outputDoc.writeTo(fos) }
            Log.d(TAG, "Merge complete: $totalPages pages → $outputPath")

            return WorkerResult.Success(
                message = "PDF merge complete",
                data = kotlinx.serialization.json.buildJsonObject {
                    put("outputPath", outputPath)
                    put("outputSize", outputFile.length())
                    put("pageCount", totalPages)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Merge failed: ${e.message}", e)
            return WorkerResult.Failure("PDF merge failed: ${e.message}")
        } finally {
            outputDoc.close()
        }
    }

    // ── compress ──────────────────────────────────────────────────────────────

    private fun compress(j: JSONObject): WorkerResult {
        val inputPath = j.optString("inputPath", "")
        if (inputPath.isEmpty()) return WorkerResult.Failure("'inputPath' is required for compress")
        val outputPath = j.optString("outputPath", "")
        if (outputPath.isEmpty()) return WorkerResult.Failure("'outputPath' is required")
        val quality = j.optInt("quality", 80).coerceIn(1, 100)
        val dpi = qualityToDpi(quality)

        if (!SecurityValidator.validateFilePathSafe(inputPath)) {
            return WorkerResult.Failure("Invalid or unsafe input path")
        }
        if (!SecurityValidator.validateFilePathSafe(outputPath)) {
            return WorkerResult.Failure("Invalid or unsafe output path")
        }

        val inputFile = File(inputPath)
        if (!inputFile.exists()) return WorkerResult.Failure("Input file not found: $inputPath")

        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()

        val scale = dpi / 72f   // 72 DPI is the PDF base unit
        val outputDoc = PdfDocument()

        try {
            val pfd = ParcelFileDescriptor.open(inputFile, ParcelFileDescriptor.MODE_READ_ONLY)
            val renderer = PdfRenderer(pfd)

            try {
                for (pageIndex in 0 until renderer.pageCount) {
                    val page = renderer.openPage(pageIndex)
                    val srcW = page.width.takeIf { it > 0 } ?: A4_WIDTH
                    val srcH = page.height.takeIf { it > 0 } ?: A4_HEIGHT
                    val renderW = (srcW * scale).toInt().coerceAtLeast(1)
                    val renderH = (srcH * scale).toInt().coerceAtLeast(1)

                    val bitmap = Bitmap.createBitmap(renderW, renderH, Bitmap.Config.RGB_565)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                    page.close()

                    // Write at original page dimensions (page size doesn't change, just image quality)
                    val pageInfo = PdfDocument.PageInfo.Builder(srcW, srcH, pageIndex + 1).create()
                    val outPage = outputDoc.startPage(pageInfo)
                    val dst = RectF(0f, 0f, srcW.toFloat(), srcH.toFloat())
                    outPage.canvas.drawBitmap(bitmap, null, dst, Paint(Paint.FILTER_BITMAP_FLAG))
                    outputDoc.finishPage(outPage)
                    bitmap.recycle()
                }

                FileOutputStream(outputFile).use { fos -> outputDoc.writeTo(fos) }
                val pageCount = renderer.pageCount
                Log.d(TAG, "Compress complete: quality=$quality dpi=$dpi pages=$pageCount → $outputPath")

                return WorkerResult.Success(
                    message = "PDF compress complete",
                    data = kotlinx.serialization.json.buildJsonObject {
                        put("outputPath", outputPath)
                        put("outputSize", outputFile.length())
                        put("pageCount", pageCount)
                    }
                )
            } finally {
                renderer.close()
                pfd.close()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Compress failed: ${e.message}", e)
            return WorkerResult.Failure("PDF compress failed: ${e.message}")
        } finally {
            outputDoc.close()
        }
    }

    // ── imagesToPdf ───────────────────────────────────────────────────────────

    private fun imagesToPdf(j: JSONObject): WorkerResult {
        val imagePathsArray = j.optJSONArray("imagePaths")
            ?: return WorkerResult.Failure("'imagePaths' array is required for imagesToPdf")
        val outputPath = j.optString("outputPath", "")
        if (outputPath.isEmpty()) return WorkerResult.Failure("'outputPath' is required")
        val pageSize = j.optString("pageSize", "A4")
        val margin = j.optInt("margin", 0)

        val imagePaths = (0 until imagePathsArray.length()).map { imagePathsArray.getString(it) }
        if (imagePaths.isEmpty()) return WorkerResult.Failure("'imagePaths' must not be empty")

        if (!SecurityValidator.validateFilePathSafe(outputPath)) {
            return WorkerResult.Failure("Invalid or unsafe output path")
        }
        for (imagePath in imagePaths) {
            if (!SecurityValidator.validateFilePathSafe(imagePath)) {
                return WorkerResult.Failure("Invalid or unsafe image path: $imagePath")
            }
        }

        val outputFile = File(outputPath)
        // MEDIA-009: surface mkdirs failure explicitly.
        val img2pdfParentDir = outputFile.parentFile
        if (img2pdfParentDir != null && !img2pdfParentDir.exists() && !img2pdfParentDir.mkdirs()) {
            return WorkerResult.Failure("Failed to create output directory: ${img2pdfParentDir.path}")
        }

        val outputDoc = PdfDocument()

        try {
            for ((index, imagePath) in imagePaths.withIndex()) {
                val imageFile = File(imagePath)
                if (!imageFile.exists()) {
                    outputDoc.close()
                    return WorkerResult.Failure("Image not found: $imagePath")
                }

                val opts = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
                val bitmap = BitmapFactory.decodeFile(imagePath, opts)
                    ?: run {
                        outputDoc.close()
                        return WorkerResult.Failure("Cannot decode image: $imagePath")
                    }

                val (pageW, pageH) = pageDimensions(pageSize, bitmap.width, bitmap.height)

                val pageInfo = PdfDocument.PageInfo.Builder(pageW, pageH, index + 1).create()
                val page = outputDoc.startPage(pageInfo)
                val canvas: Canvas = page.canvas

                // Fill background white
                canvas.drawARGB(255, 255, 255, 255)

                // Compute drawable area respecting margin
                val drawW = (pageW - 2 * margin).coerceAtLeast(1)
                val drawH = (pageH - 2 * margin).coerceAtLeast(1)

                // MEDIA-003: guard against corrupt bitmaps with zero dimensions.
                if (bitmap.width == 0 || bitmap.height == 0) {
                    bitmap.recycle()
                    outputDoc.finishPage(page)
                    continue
                }

                // Scale image to fit page while preserving aspect ratio
                val scaleX = drawW.toFloat() / bitmap.width
                val scaleY = drawH.toFloat() / bitmap.height
                val scale = minOf(scaleX, scaleY)
                val scaledW = bitmap.width * scale
                val scaledH = bitmap.height * scale
                val left = margin + (drawW - scaledW) / 2f
                val top = margin + (drawH - scaledH) / 2f

                val dst = RectF(left, top, left + scaledW, top + scaledH)
                canvas.drawBitmap(bitmap, null, dst, Paint(Paint.FILTER_BITMAP_FLAG))
                outputDoc.finishPage(page)
                bitmap.recycle()
            }

            FileOutputStream(outputFile).use { fos -> outputDoc.writeTo(fos) }
            Log.d(TAG, "imagesToPdf complete: ${imagePaths.size} pages → $outputPath")

            return WorkerResult.Success(
                message = "imagesToPdf complete",
                data = kotlinx.serialization.json.buildJsonObject {
                    put("outputPath", outputPath)
                    put("outputSize", outputFile.length())
                    put("pageCount", imagePaths.size)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "imagesToPdf failed: ${e.message}", e)
            // MEDIA-004: delete partial output so caller never sees a corrupt file.
            if (outputFile.exists()) outputFile.delete()
            return WorkerResult.Failure("imagesToPdf failed: ${e.message}")
        } finally {
            outputDoc.close()
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    /**
     * Returns (width, height) in PDF points for the chosen page size.
     * "auto" returns the native image dimensions.
     */
    private fun pageDimensions(pageSize: String, imageWidth: Int, imageHeight: Int): Pair<Int, Int> =
        when (pageSize.uppercase()) {
            "A4"     -> Pair(A4_WIDTH, A4_HEIGHT)
            "LETTER" -> Pair(LETTER_WIDTH, LETTER_HEIGHT)
            else     -> Pair(imageWidth, imageHeight)   // "auto" or unknown
        }
}
