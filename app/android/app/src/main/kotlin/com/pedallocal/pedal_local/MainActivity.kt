package com.pedallocal.pedal_local

import android.annotation.TargetApi
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.window.SplashScreenView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant

/** Canal da abertura (igual ao `aberturaCanal` em Dart). */
private const val CANAL = "pedalaqui/abertura"

/** Prazo para a abertura em Dart responder; depois disso a tela de carregamento sai mesmo assim. */
private const val PRAZO_MS = 1000L

class MainActivity : FlutterActivity() {
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
