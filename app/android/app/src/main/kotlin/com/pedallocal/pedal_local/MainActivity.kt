package com.pedallocal.pedal_local

import android.annotation.TargetApi
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Rational
import android.window.SplashScreenView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant

/** Canal da abertura (igual ao `aberturaCanal` em Dart). */
private const val CANAL = "pedalaqui/abertura"

/** Prazo para a abertura em Dart responder; depois disso a tela de carregamento sai mesmo assim. */
private const val PRAZO_MS = 1000L

/** Canal da miniatura do pedal (igual ao de `Miniatura` em Dart). */
private const val CANAL_MINIATURA = "pedalaqui/miniatura"

class MainActivity : FlutterActivity() {
    /** Durante o pedal na rota: sair do app vira a janela flutuante com o mapa. */
    private var miniaturaPermitida = false
    private var canalMiniatura: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canalMiniatura = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_MINIATURA).also {
            it.setMethodCallHandler { chamada, resultado ->
                if (chamada.method == "permitir") {
                    permitirMiniatura(chamada.arguments == true)
                    resultado.success(null)
                } else {
                    resultado.notImplemented()
                }
            }
        }
    }

    private fun temMiniatura() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    /** Janela deitada, do jeito de um vídeo; no Android 12+ entra sozinha ao sair do app. */
    @TargetApi(Build.VERSION_CODES.O)
    private fun parametros(): PictureInPictureParams {
        val p = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) p.setAutoEnterEnabled(miniaturaPermitida)
        return p.build()
    }

    private fun permitirMiniatura(sim: Boolean) {
        miniaturaPermitida = sim
        if (temMiniatura()) setPictureInPictureParams(parametros())
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 8 a 11 (no 12+ o autoEnter já faz isso, com a animação do sistema).
        if (miniaturaPermitida && temMiniatura() && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPictureInPictureMode(parametros())
        }
    }

    override fun onPictureInPictureModeChanged(naMiniatura: Boolean, novaConfig: Configuration) {
        super.onPictureInPictureModeChanged(naMiniatura, novaConfig)
        canalMiniatura?.invokeMethod("mudou", naMiniatura)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: a tela de carregamento desenha o começo da abertura (splash_logo.xml)
            // enquanto o app carrega. Quando ele fica pronto, ela sai sem a animação padrão, e a
            // abertura do app continua do mesmo ponto.
            splashScreen.setOnExitAnimationListener { passarParaOApp(it) }
        }
    }

    /**
     * Conta à abertura em Dart quando a animação da tela de carregamento começou (no relógio dos
     * quadros, o mesmo do Flutter) e tira a tela de carregamento quando ela responde: a essa altura
     * o app já desenha a logo no mesmo ponto da animação.
     */
    @TargetApi(Build.VERSION_CODES.S)
    private fun passarParaOApp(tela: SplashScreenView) {
        var saiu = false
        val sair = {
            if (!saiu) {
                saiu = true
                tela.remove()
            }
        }
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger == null) {
            sair()
            return
        }
        val comeco = tela.iconAnimationStart
        val decorrido = if (comeco == null) -1L else Duration.between(comeco, Instant.now()).toMillis()
        val dados = mapOf(
            "decorrido" to decorrido,
            "inicio" to if (comeco == null) -1L else SystemClock.uptimeMillis() - decorrido,
        )
        MethodChannel(messenger, CANAL).invokeMethod("abrir", dados, object : MethodChannel.Result {
            override fun success(result: Any?) = sair()
            override fun error(code: String, message: String?, details: Any?) = sair()
            override fun notImplemented() = sair()
        })
        Handler(Looper.getMainLooper()).postDelayed({ sair() }, PRAZO_MS)
    }

    /** Avisa a abertura em Dart que a tela de carregamento do Android vai passar a animação para ela. */
    override fun getDartEntrypointArgs(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) listOf("abertura-android") else emptyList()
}
