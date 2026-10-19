package id.ac.ub.gapura_ub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gapura_ub/demo_documents")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename")
                if (bytes == null || bytes.size > 1000000 || filename == null ||
                    !filename.matches(Regex("DEMO-Bukti-Potong-[0-9]{4}\\.pdf"))) {
                    result.error("invalid_document", "Dokumen demo tidak valid.", null)
                } else if (pendingSave != null) {
                    result.error("busy", "Penyimpanan sedang berlangsung.", null)
                } else {
                    pendingSave = result
                    pendingBytes = bytes
                    try {
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }, 4601)
                    } catch (error: Exception) {
                        pendingSave = null
                        pendingBytes = null
                        result.error("save_unavailable", "Pemilih penyimpanan tidak tersedia.", null)
                    }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4601) return
        val result = pendingSave ?: return
        val bytes = pendingBytes
        pendingSave = null
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            result.success(false)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(uri) ?: throw IllegalStateException()
            stream.use { it.write(bytes) }
            result.success(true)
        } catch (error: Exception) {
            result.error("save_failed", "PDF tidak dapat disimpan.", null)
        }
    }

    override fun onDestroy() {
        pendingSave?.error("closed", "Penyimpanan dokumen ditutup.", null)
        pendingSave = null
        pendingBytes = null
        super.onDestroy()
    }
}
