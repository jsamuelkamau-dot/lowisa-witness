package com.lowisamobile

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.Executors

/**
 * WITNESS CAMERA (2026-10-28 re-audit; the plan's "Witness this paper" screen, owner approved CameraX): a top-down camera
 * with a guide frame that locks onto the page, then records in the background with the screen dimmed.
 *
 *  - The guide turns green once a page fills it: each preview frame's brightness is read on the phone (ImageAnalysis,
 *    luminance only, nothing leaves the phone) and a page is "in view" when most of the guide is bright paper and the
 *    border around it is not (a wall or a white desk is not a page).
 *  - Recording goes to the app's own cache (shots/clip-*.mp4), never the gallery, at 720p (the marking reads 720p);
 *    the screen dims to almost black and stays awake; one tap anywhere stops. It stops by itself at the limit.
 *  - Back while recording stops and keeps what was recorded (a paper is never lost to a stray press).
 *
 * Started by DocumentModule.witnessCamera with EXTRA_OUT (the file) and EXTRA_MAX (seconds); answers RESULT_OK when the
 * file has a recording.
 */
class WitnessCameraActivity : ComponentActivity() {
  companion object {
    const val EXTRA_OUT = "out"
    const val EXTRA_MAX = "max"
    /** The guide frame, as a share of the screen: the page is held upright under the phone. */
    const val GUIDE_W = 0.84f
    const val GUIDE_H = 0.70f
    /** A page fills the guide when this share of it is bright paper, with less than RIM_MAX of the rim bright. */
    const val PAGE_MIN = 0.55f
    const val RIM_MAX = 0.85f
  }

  private lateinit var preview: PreviewView
  private lateinit var guide: GuideView
  private lateinit var hint: TextView
  private lateinit var go: Button
  private lateinit var dim: FrameLayout
  private lateinit var clock: TextView
  private var recording: Recording? = null
  private var capture: VideoCapture<Recorder>? = null
  private val analyser = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())
  private var startedAt = 0L
  private var maxSeconds = 600
  private lateinit var out: File
  private var inView = 0

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    out = File(intent.getStringExtra(EXTRA_OUT) ?: File(File(cacheDir, "shots").apply { mkdirs() }, "clip-" + System.currentTimeMillis() + ".mp4").absolutePath)
    maxSeconds = intent.getIntExtra(EXTRA_MAX, 600).coerceIn(10, 3600)
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

    val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
    preview = PreviewView(this).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }
    guide = GuideView(this)
    hint = TextView(this).apply {
      setTextColor(Color.WHITE); textSize = 17f; gravity = Gravity.CENTER; setPadding(36, 48, 36, 12)
      setShadowLayer(6f, 0f, 0f, Color.BLACK)
      text = "Hold the phone above the desk. Fit the whole page inside the frame."
    }
    go = Button(this).apply { text = "Start recording"; textSize = 17f; isEnabled = true; setOnClickListener { start() } }
    val bottom = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL; setPadding(36, 12, 36, 56)
      addView(TextView(context).apply {
        setTextColor(Color.WHITE); textSize = 13f; gravity = Gravity.CENTER; setShadowLayer(6f, 0f, 0f, Color.BLACK)
        text = "Keep faces out of view. The screen goes dark while it records; tap it to stop."
      })
      addView(go)
    }
    clock = TextView(this).apply { setTextColor(Color.rgb(120, 120, 120)); textSize = 15f; gravity = Gravity.CENTER }
    dim = FrameLayout(this).apply {
      setBackgroundColor(Color.argb(242, 0, 0, 0)); visibility = View.GONE; isClickable = true
      setOnClickListener { stop() }
      addView(clock, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
    }
    root.addView(preview, FrameLayout.LayoutParams(-1, -1))
    root.addView(guide, FrameLayout.LayoutParams(-1, -1))
    root.addView(hint, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))
    root.addView(bottom, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
    root.addView(dim, FrameLayout.LayoutParams(-1, -1))
    setContentView(root)

    onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
      override fun handleOnBackPressed() { if (recording != null) stop() else { setResult(Activity.RESULT_CANCELED); finish() } }
    })
    bind()
  }

  private fun bind() {
    val future = ProcessCameraProvider.getInstance(this)
    future.addListener({
      try {
        val provider = future.get()
        val p = Preview.Builder().build().also { it.setSurfaceProvider(preview.surfaceProvider) }
        val recorder = Recorder.Builder().setQualitySelector(QualitySelector.from(Quality.HD, androidx.camera.video.FallbackStrategy.lowerQualityOrHigherThan(Quality.SD))).build()
        val vc = VideoCapture.withOutput(recorder)
        capture = vc
        val look = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
        look.setAnalyzer(analyser) { img ->
          val page = try { pageInView(img) } catch (e: Exception) { false } finally { img.close() }
          main.post { onLook(page) }
        }
        provider.unbindAll()
        // a camera that cannot run the preview, the recording and the page look together records without the look
        try { provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, p, vc, look) }
        catch (e: Exception) { provider.unbindAll(); provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, p, vc); onLook(false) }
      } catch (e: Exception) {
        hint.text = "The camera could not start here."
        setResult(Activity.RESULT_CANCELED); main.postDelayed({ finish() }, 1500)
      }
    }, ContextCompat.getMainExecutor(this))
  }

  /** Luminance only: the guide's share of bright paper, and the rim's (the frame's centre GUIDE_W x GUIDE_H, as on screen). */
  private fun pageInView(img: androidx.camera.core.ImageProxy): Boolean {
    val plane = img.planes[0]; val buf = plane.buffer; val stride = plane.rowStride
    val w = img.width; val h = img.height
    val upright = img.imageInfo.rotationDegrees % 180 != 0
    val gw = if (upright) GUIDE_H else GUIDE_W; val gh = if (upright) GUIDE_W else GUIDE_H
    var inBright = 0; var inAll = 0; var rimBright = 0; var rimAll = 0
    val n = 48
    for (j in 0 until n) for (i in 0 until n) {
      val fx = (i + 0.5f) / n; val fy = (j + 0.5f) / n
      val y = buf.get(minOf(h - 1, (fy * h).toInt()) * stride + minOf(w - 1, (fx * w).toInt())).toInt() and 255
      val inside = kotlin.math.abs(fx - 0.5f) < gw / 2 && kotlin.math.abs(fy - 0.5f) < gh / 2
      if (inside) { inAll++; if (y > 150) inBright++ } else { rimAll++; if (y > 150) rimBright++ }
    }
    return inAll > 0 && inBright.toFloat() / inAll >= PAGE_MIN && (rimAll == 0 || rimBright.toFloat() / rimAll < RIM_MAX)
  }

  private fun onLook(page: Boolean) {
    if (recording != null) return
    inView = if (page) minOf(inView + 1, 6) else maxOf(inView - 1, 0)
    val locked = inView >= 4
    guide.locked = locked; guide.invalidate()
    hint.text = if (locked) "Page in view. Start when you are ready." else "Hold the phone above the desk. Fit the whole page inside the frame."
    go.text = if (locked) "Start recording" else "Start anyway"
  }

  private fun start() {
    val vc = capture ?: return
    if (recording != null) return
    out.parentFile?.mkdirs()
    val opts = FileOutputOptions.Builder(out).build()
    val pending = vc.output.prepareRecording(this, opts)
    val withSound = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    recording = (if (withSound) pending.withAudioEnabled() else pending).start(ContextCompat.getMainExecutor(this)) { ev ->
      if (ev is VideoRecordEvent.Finalize) {
        recording = null
        val ok = !ev.hasError() || ev.error == VideoRecordEvent.Finalize.ERROR_DURATION_LIMIT_REACHED || ev.error == VideoRecordEvent.Finalize.ERROR_SOURCE_INACTIVE
        if (ok && out.exists() && out.length() > 0) setResult(Activity.RESULT_OK, Intent().putExtra(EXTRA_OUT, out.absolutePath))
        else { out.delete(); setResult(Activity.RESULT_CANCELED) }
        finish()
      }
    }
    startedAt = System.currentTimeMillis()
    // the screen goes almost dark while it records, and stays awake
    dim.visibility = View.VISIBLE
    window.attributes = window.attributes.apply { screenBrightness = 0.02f }
    tick()
  }

  private fun tick() {
    if (recording == null) return
    val s = ((System.currentTimeMillis() - startedAt) / 1000).toInt()
    clock.text = "Recording " + (s / 60) + ":" + String.format("%02d", s % 60) + "\nTap to stop"
    if (s >= maxSeconds) { stop(); return }
    main.postDelayed({ tick() }, 1000)
  }

  private fun stop() {
    val r = recording ?: return
    clock.text = "Saving…"
    r.stop()
  }

  override fun onDestroy() {
    try { recording?.stop() } catch (e: Exception) { /* stopped */ }
    analyser.shutdown()
    super.onDestroy()
  }

  /** The guide frame: the page's place, the screen around it shaded; green once a page fills it. */
  class GuideView(ctx: Context) : View(ctx) {
    var locked = false
    private val shade = Paint().apply { color = Color.argb(120, 0, 0, 0) }
    private val line = Paint().apply { style = Paint.Style.STROKE; strokeWidth = 8f; isAntiAlias = true }
    override fun onDraw(c: Canvas) {
      val w = width.toFloat(); val h = height.toFloat()
      val r = RectF(w * (1 - GUIDE_W) / 2, h * (1 - GUIDE_H) / 2, w * (1 + GUIDE_W) / 2, h * (1 + GUIDE_H) / 2)
      val hole = Path().apply { fillType = Path.FillType.EVEN_ODD; addRect(0f, 0f, w, h, Path.Direction.CW); addRoundRect(r, 28f, 28f, Path.Direction.CW) }
      c.drawPath(hole, shade)
      line.color = if (locked) Color.rgb(34, 197, 94) else Color.WHITE
      c.drawRoundRect(r, 28f, 28f, line)
    }
  }
}
