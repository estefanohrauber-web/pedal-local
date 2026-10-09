# Pedal Local

App para pedalar, numa bike ergométrica em casa, rotas reais do próprio bairro.
Protótipo web na raiz (GitHub Pages); app Flutter em `app/`.
Documentos de design e planos em `docs/superpowers/`.
O app se chama **Pedalaqui** (desde 2026-10-09); a pasta, o pacote e o código continuam
`pedal-local` / `pedal_local`. Logo e ícones em `docs/marca/` e `app/lib/core/widgets/pedalaqui_logo.dart`.

## Como responder

- Toda mensagem ao usuário termina com um **Resumo** curto (3 a 5 linhas), em
  português simples, para leigo: o que foi feito, o que significa e o próximo passo.
- O usuário não é programador: explique o porquê das escolhas sem jargão.

## Ambiente (Windows)

- O nome do usuário do Windows tem acento e espaço. O Android/Gradle não compila
  nesses caminhos: projetos Flutter ficam em `C:\dev`.
- Flutter em `C:\dev\flutter`, Android SDK em `C:\dev\android-sdk` (`ANDROID_HOME`).
- `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\dev\tmp` evita o erro do Gradle
  “Unable to establish loopback connection”.
- Testes do protótipo web: `node --test` na raiz. Testes do app: `flutter test` em `app/`.
