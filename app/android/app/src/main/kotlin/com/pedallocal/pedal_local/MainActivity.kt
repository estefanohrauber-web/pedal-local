package com.pedallocal.pedal_local

import android.os.Build
import android.os.Bundle
import android.os.Process
import android.os.SystemClock
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterActivity

/** Duração do desenho da rota na tela de carregamento (igual a `splash_logo.xml` e à abertura em Dart). */
private const val DESENHO_MS = 750L

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: a tela de carregamento desenha a rota da logo. Ela fica até o desenho
            // terminar, mesmo se o app carregar antes, e sai sem a animação padrão: a abertura do
            // app mostra a mesma logo no mesmo lugar e continua dali.
            val fim = Process.getStartUptimeMillis() + DESENHO_MS
            val conteudo = findViewById<View>(android.R.id.content)
            conteudo.viewTreeObserver.addOnPreDrawListener(object : ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    if (SystemClock.uptimeMillis() < fim) return false
                    conteudo.viewTreeObserver.removeOnPreDrawListener(this)
                    return true
                }
            })
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
    }

    /** Avisa a abertura em Dart que a linha já foi desenhada pela tela de carregamento. */
    override fun getDartEntrypointArgs(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) listOf("linha-pronta") else emptyList()
}
