package fr.cybertrist.aesthetic

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Une vidéo MP4 (H.264) écrite image par image : l'appli dessine chaque image de l'animation et
 * l'envoie en RGBA, dans l'ordre. Canal partagé avec
 * `lib/features/profil/photos/transformation_page.dart`.
 */
class EncodeurVideo(chemin: String, private val largeur: Int, private val hauteur: Int, private val ips: Int) {
  private val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
  private val muxer = MediaMuxer(chemin, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
  private val info = MediaCodec.BufferInfo()
  private val ligne = ByteArray(largeur)
  private var piste = -1
  private var images = 0

  init {
    val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, largeur, hauteur)
    format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
    format.setInteger(MediaFormat.KEY_BIT_RATE, 8_000_000)
    format.setInteger(MediaFormat.KEY_FRAME_RATE, ips)
    format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    codec.start()
  }

  private fun entree(): Int {
    repeat(500) {
      val index = codec.dequeueInputBuffer(10_000)
      if (index >= 0) return index
      vider(false)
    }
    error("L'encodeur ne prend plus d'image")
  }

  fun ajouter(rgba: ByteArray) {
    require(rgba.size == largeur * hauteur * 4) { "Image de ${rgba.size} octets" }
    val index = entree()
    remplir(codec.getInputImage(index) ?: error("Pas d'image d'entrée"), rgba)
    codec.queueInputBuffer(index, 0, largeur * hauteur * 3 / 2, images * 1_000_000L / ips, 0)
    images++
    vider(false)
  }

  /** RGBA vers YUV 4:2:0 (BT.601), en suivant la disposition des plans de l'encodeur. */
  private fun remplir(image: Image, rgba: ByteArray) {
    val y = image.planes[0]
    val u = image.planes[1]
    val v = image.planes[2]
    for (j in 0 until hauteur) {
      var p = j * largeur * 4
      val chroma = j % 2 == 0
      for (i in 0 until largeur) {
        val r = rgba[p].toInt() and 0xFF
        val g = rgba[p + 1].toInt() and 0xFF
        val b = rgba[p + 2].toInt() and 0xFF
        p += 4
        ligne[i] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte()
        if (chroma && i % 2 == 0) {
          u.buffer.put((j / 2) * u.rowStride + (i / 2) * u.pixelStride, (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte())
          v.buffer.put((j / 2) * v.rowStride + (i / 2) * v.pixelStride, (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte())
        }
      }
      if (y.pixelStride == 1) {
        y.buffer.position(j * y.rowStride)
        y.buffer.put(ligne, 0, largeur)
      } else {
        for (i in 0 until largeur) y.buffer.put(j * y.rowStride + i * y.pixelStride, ligne[i])
      }
    }
  }

  /** Passe au fichier ce que l'encodeur a déjà produit ; jusqu'au bout quand [fin]. */
  private fun vider(fin: Boolean) {
    var attentes = 0
    while (true) {
      val index = codec.dequeueOutputBuffer(info, if (fin) 10_000 else 0)
      when {
        index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
          if (!fin) return
          if (++attentes > 500) error("L'encodeur ne rend pas la fin de la vidéo")
        }
        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
          piste = muxer.addTrack(codec.outputFormat)
          muxer.start()
        }
        index >= 0 -> {
          val donnees = codec.getOutputBuffer(index)
          val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
          if (donnees != null && !config && info.size > 0 && piste >= 0) {
            donnees.position(info.offset)
            donnees.limit(info.offset + info.size)
            muxer.writeSampleData(piste, donnees, info)
          }
          codec.releaseOutputBuffer(index, false)
          if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
        }
      }
    }
  }

  fun fermer() {
    codec.queueInputBuffer(entree(), 0, 0, images * 1_000_000L / ips, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
    vider(true)
    liberer(true)
  }

  /** Rend l'encodeur et le fichier, sans exiger une vidéo valide quand [propre] est faux. */
  fun liberer(propre: Boolean = false) {
    runCatching { codec.stop() }
    runCatching { codec.release() }
    val arret = runCatching { if (piste >= 0) muxer.stop() }
    runCatching { muxer.release() }
    if (propre) arret.getOrThrow()
  }

  /** Le canal `aesthetics/video` : `ouvrir`, `image` autant de fois qu'il faut, `fermer` ou `annuler`. */
  class Canal : MethodChannel.MethodCallHandler {
    private var encodeur: EncodeurVideo? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
      try {
        when (call.method) {
          "ouvrir" -> {
            encodeur?.liberer()
            encodeur = EncodeurVideo(call.argument("chemin")!!, call.argument("largeur")!!, call.argument("hauteur")!!, call.argument("ips")!!)
          }
          "image" -> (encodeur ?: error("Aucune vidéo ouverte")).ajouter(call.arguments as ByteArray)
          "fermer" -> {
            val e = encodeur ?: error("Aucune vidéo ouverte")
            encodeur = null
            e.fermer()
          }
          "annuler" -> {
            encodeur?.liberer()
            encodeur = null
          }
          else -> return result.notImplemented()
        }
        result.success(null)
      } catch (e: Throwable) {
        encodeur?.liberer()
        encodeur = null
        result.error("video", e.message, null)
      }
    }
  }
}
