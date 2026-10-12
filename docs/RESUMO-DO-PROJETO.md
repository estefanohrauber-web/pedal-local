# Pedalaqui — resumo do projeto

Atualizado em 11/10/2026. Este documento serve para continuar o projeto em outro computador
(ou numa conversa nova com o Claude) sem perder nada: o que é o app, o que já foi feito, como
montar o computador, o jeito de trabalhar combinado e os próximos passos.

> **Para o Claude numa conversa nova:** leia este arquivo inteiro antes de começar. As regras da
> seção 6 valem sempre. O próximo trabalho combinado é a **parte dos servidores** (seção 7.1),
> começando pelo desenho (brainstorming), não pelo código.

---

## 1. O que é

**Pedalaqui** é um app Android para pedalar, numa bike ergométrica em casa, rotas reais do próprio
bairro. Ele lê a bike pelo Bluetooth (padrão FTMS), traça a rota pelas ruas com o relevo de
verdade e faz a velocidade cair nas subidas e subir nas descidas. Tem também treinos com metas de
potência, planos de várias semanas, teste de FTP e um editor para o usuário montar os próprios
treinos.

- O nome visível é **Pedalaqui** (desde 9/10/2026). A pasta, o pacote e o código continuam
  `pedal-local` / `pedal_local`; o id do app no Android é `com.pedallocal.app`.
- O dono do projeto (usuário) **não é programador**: fala português, quer explicações simples e
  decide o que o app faz. O Claude programa, testa e explica.

## 2. Onde está cada coisa

| O quê | Onde |
|---|---|
| Código (tudo) | GitHub: `https://github.com/estefanohrauber-web/pedal-local` (ramo `main`) |
| App Flutter | pasta `app/` |
| Protótipo web antigo (GitHub Pages) | raiz do repositório (`index.html`, `src/`, `tests/`) |
| Desenhos (specs) e planos | `docs/superpowers/specs/` e `docs/superpowers/plans/` |
| Logo, ícones, símbolo | `docs/marca/` e `app/lib/core/widgets/pedalaqui_logo.dart` |
| Esboços da logo (canvas) | `https://claude.ai/artifact/1Ld2e9MeFqrWLThNtaP39v` (conta do Claude) |
| Instruções do projeto para o Claude | `CLAUDE.md` (raiz) |
| Memória do Claude sobre o projeto | `%USERPROFILE%\.claude\projects\C--dev-pedal-local\memory\` (fora do GitHub; vai no .zip) |
| Chave que assina o app de teste | `%USERPROFILE%\.android\debug.keystore` (fora do GitHub; vai no .zip) |
| Dados do usuário (rotas, pedais, treinos) | **só no celular**, no banco do app; cópias no .zip |

**Celular de testes:** Samsung Galaxy S20 FE, Android 13, número no `adb`: `RQ8R905CDWJ`.
Abrir o app pelo cabo: `adb -s RQ8R905CDWJ shell am start -n com.pedallocal.app/com.pedallocal.pedal_local.MainActivity`.
No celular estão as rotas **“Entre pontes”** (3,2 km) e **“Casa trabalho”** (9,6 km) e 2 pedais
simulados de 08/10 (13:46 e 14:07).

**Bike:** Winnek SYNC 2151 (FitShow), aparece como **“WINNEK BT-151”** (MAC `CA:AC:0D:0B:A3:26`).
Ela **não controla resistência** (sem modo ERG); o app orienta pela voz.

## 3. Montar o computador de casa (passo a passo)

Faça na ordem. Tudo o que não está no GitHub vem no arquivo `.zip` da transferência (seção 9).

1. **Programas:**
   - **Git** e, se quiser, o **GitHub CLI** (`gh`); faça login no GitHub.
   - **Node.js 24** (testes do protótipo e scripts de apoio; o `node:sqlite` precisa do 22 ou mais).
   - **Android Studio** (traz o Java que o Flutter usa).
   - **Flutter 3.47.6** (canal stable), na pasta `C:\dev\flutter`. Use essa versão: uma mais nova
     pode mudar coisas.
   - **Android SDK** na pasta `C:\dev\android-sdk`, com platform-tools, build-tools 36.0.0 e as
     plataformas 36 e 37. Depois rode `flutter config --android-sdk C:\dev\android-sdk`, crie a
     variável `ANDROID_HOME=C:\dev\android-sdk` e ponha `C:\dev\android-sdk\platform-tools` no
     PATH (para o `adb`).
   - **Claude Code** (app do Claude, aba Code).
2. **Caminhos sem acento.** Se o nome do usuário do Windows tiver acento ou espaço, o Gradle não
   compila nesses caminhos. Por isso tudo fica em `C:\dev`. Crie a pasta `C:\dev\tmp` e a variável
   de ambiente **`JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\dev\tmp`** (evita o erro do
   Gradle “Unable to establish loopback connection”). Coloque `C:\dev\flutter\bin` no PATH.
3. **Pegar o projeto** na **mesma pasta** daqui, `C:\dev\pedal-local`. É ela que liga o projeto à
   memória do Claude.
   - Pelo GitHub: `git clone https://github.com/estefanohrauber-web/pedal-local.git C:\dev\pedal-local`
   - Sem internet para o GitHub: `git clone pedal-local.bundle C:\dev\pedal-local` (o bundle vai no .zip).
     Depois, aponte de volta para o GitHub:
     `git remote set-url origin https://github.com/estefanohrauber-web/pedal-local.git`.
4. **A chave do app (o passo mais importante para não perder dados).** Copie o `debug.keystore`
   do .zip para `%USERPROFILE%\.android\debug.keystore`, **antes do primeiro build**.
   - O Android só instala uma atualização por cima se ela vier assinada com a **mesma chave**.
   - Sem essa chave, o PC de casa cria uma chave nova, e o celular recusa a instalação. A única saída
     seria desinstalar o app, o que **apaga as rotas e os pedais**.
5. **Memória e habilidades do Claude:** copie do .zip:
   - `claude/memory/*` para `%USERPROFILE%\.claude\projects\C--dev-pedal-local\memory\`
   - `claude/skills/*` para `%USERPROFILE%\.claude\skills\`
   - `claude/agents/*` para `%USERPROFILE%\.claude\agents\`
   O `claude/settings.local.json` liga os avisos de design do Impeccable. Ele aponta para a pasta
   do usuário deste PC; se o nome do usuário em casa for outro, corrija os caminhos dentro dele.
6. **Ferramentas de apoio:** copie `ferramentas/*` para `C:\dev\tmp\`. São scripts para fotos da tela
   e análise do banco (seção 8).
7. **Conferir:**
   - `cd C:\dev\pedal-local\app` → `flutter pub get` → `flutter analyze` (sem avisos) →
     `flutter test` (**392 testes** passando em 11/10).
   - Celular no cabo: ative a depuração USB e toque em **Permitir** na pergunta do computador novo.
     `adb devices` deve mostrar `RQ8R905CDWJ`.
   - `flutter build apk --debug` e depois
     `adb -s RQ8R905CDWJ install -r build\app\outputs\flutter-apk\app-debug.apk`. O `-r` atualiza
     **por cima, sem apagar nada**. Se der “INSTALL_FAILED_UPDATE_INCOMPATIBLE”, a chave não é a
     mesma: **não desinstale**; volte ao passo 4.
8. **A versão final (release) pode funcionar em casa.** Aqui o Controle Inteligente de Aplicativos
   do Windows bloqueia o `gen_snapshot.exe`, e só sai a versão de teste. Em casa, tente
   `flutter build apk --release`. Se funcionar, ela também é assinada com a chave de teste
   (`android/app/build.gradle.kts`) e instala por cima sem perder nada: o app abre bem mais rápido.
   Para a Play Store, a assinatura é outra (seção 7.6).

**Começar no Claude em casa:** abra o Claude Code na pasta `C:\dev\pedal-local` e diga algo como:
“leia o `docs/RESUMO-DO-PROJETO.md` e vamos começar a parte dos servidores”.

## 4. O que já foi feito

**6/10 — protótipo web** (raiz do repositório, GitHub Pages). Bike pelo Web Bluetooth, rota pelo
OSRM, altimetria do Open-Meteo e física da velocidade virtual. Serviu para validar a ideia; o app de
verdade é o Flutter.

**7/10 — app Flutter, base:**
- domínio: física, potência estimada (quando a bike não manda watts) e leitura do FTMS;
- dados: banco SQLite;
- bike: conexão FTMS com reconexão automática, mais uma bike simulada;
- telas: 5 abas (Início, Explorar, botão de pedalar, Treinos, Você), pedal livre e resumo.

**8/10 — rotas e pedal na rota:**
- mapa (OpenStreetMap); criar rota tocando no mapa, com traçado e altitude pelo **Valhalla**
  (servidores da FOSSGIS); busca de endereço pelo Photon;
- editor de rota: arrastar, apagar, ida e volta; **gerar volta** automática por distância;
  cada rota com sua cor;
- pedal na rota: sentido, ponto de começo, voltas na rota fechada, aviso de subida;
- histórico com o mapa pintado, resumo com gráficos, voltas e comparação;
- **fantasma** (corrida contra o melhor pedal), volta automática e **voz** (TTS);
- **treinos:** 7 zonas de potência, **teste de rampa** (dá o FTP), 11 treinos prontos, 3 planos de
  semanas, pergunta “como foi?” que ajusta os próximos, e **modo ERG** (a bike segura a meta) para
  bikes que aceitam comando.

**9/10:**
- **Pontes e túneis em reta no relevo.** Antes, uma ponte dava −18 % de inclinação.
- **Leitura da bike em pedaços.** A Winnek manda os dados divididos em pacotes (FTMS “More Data”);
  o app junta tudo. O app também grava um **diário da bike** (`files/bike_log.txt`).
- **Voz mais natural**, com escolha da voz e pronúncia certa (“bike” = “baique”).
- **Nome, logo e ícone Pedalaqui**: uma rota que vira um pino de mapa, verde `#138A52` com a bolinha
  amarela `#F6C445`. O nome usa Plus Jakarta Sans ExtraBold, com o “i” normal.
- **Abertura animada.** A tela de carregamento do Android desenha a rota, a bolinha pinga e solta
  anéis enquanto o app carrega; o app continua do mesmo ponto, escreve o nome e se abre pela bolinha.
  Fica em cerca de 2,1 s na versão final.
- **Editor de treinos:**
  - “Meus treinos” na aba Treinos, com 7 blocos prontos (Aquecer, Ritmo constante, Série de tiros,
    Rampa, Subida simulada, Pedal livre e Soltar);
  - intensidade em palavras com os watts do FTP, giro, frase falada pela voz;
  - copiar e editar treinos prontos;
  - em qualquer treino: pular bloco, +1 min e ±5 %.

**10–11/10 (PC de casa):** Winnek funcionando (seção 7.2) e as 7 ideias do usuário (7.3), cada
tela escolhida entre 3 versões desenhadas com a skill Impeccable:
- **pedal na rota** com o mapa na tela inteira, o caminho em cima e o esforço embaixo (tempo e
  km/h grandes, relevo pintado até onde já foi), “Mais dados” e o selo “ao vivo”;
- **conectar a bike** como lista de verificação, com os números chegando ao vivo;
- **calibrar o botão de peso** tocando a cada volta; no pedal, a voz diz “gire o botão mais 5
  voltas” e os watts passam a contar o botão; nos treinos, a bike de botão manual é guiada pela voz;
- **chegada** de uma ida com o mapa até a bandeira e “Fazer a volta”;
- **histórico** em calendário do mês; **Ajustes** por assunto, salvando sozinhos, e a engrenagem
  em todas as abas.

**11/10 à noite (seção 7.4):** depois do primeiro pedal com o botão calibrado, de novo com 3 versões
de cada tela escolhidas pelo usuário:
- **barra fixa no topo** de todas as abas (marca, selo da bike e engrenagem) e o **Início “Hoje”**:
  a última rota pedalada com o mapa e o recorde para bater, a meta da semana e o pedal livre;
- **aba Você** com **Seus recordes** (totais, mais longe, mais subida, mais tempo, melhor semana),
  o calendário e **todos os pedais** embaixo; tocar num dia filtra a lista;
- **calibração do botão guiada pela voz**: a pessoa pedala perto de 60 rpm e a cada 10 s a voz pede
  mais uma volta; o app conta, anota o giro e descobre até que volta dá para pedalar e se a bike
  sente o botão nos watts;
- **conta nova das voltas** nas subidas: usa a média da subida (não o pedaço mais íngreme) e só a
  parte do botão que dá para pedalar (na ponte do Entre pontes, 4 voltas em vez de 8);
- **miniatura do pedal**: ao sair do app pedalando, o mapa vira uma janela flutuante por cima dos
  outros apps (picture-in-picture do Android).

**Design e testes:** cada parte tem um documento de desenho em `docs/superpowers/specs/` (as de
10–11/10, em `.impeccable/surfaces/`, com o contexto do produto em `PRODUCT.md`) e foi conferida
com fotos da tela. São 392 testes automáticos (11/10).

## 5. Como o app é por dentro (para o Claude)

- **Flutter 3.47 / Dart 3.13.** Pacotes principais: Riverpod 3, go_router, sqflite, universal_ble
  (Bluetooth), flutter_map, geolocator, flutter_tts, google_fonts, wakelock_plus.
- **`app/lib/`:**
  - `domain/`: regras sem tela, com testes: física, FTMS, rotas, relevo, voltas, fantasma, narrador
    da voz, treinos, blocos do editor (`workout_blocks.dart`) e o condutor do treino
    (`workout_runner.dart`);
  - `data/`: banco e serviços (Valhalla, Photon, elevação), lojas de ajustes, pedais, rotas e
    treinos do usuário;
  - `bike/`: Bluetooth, FTMS, controle da bike e o diário;
  - `features/`: as telas;
  - `core/`: tema, formatos, voz, mapa, logo.
- **Banco SQLite, versão 7.** Tabelas `settings`, `rides` (com `workout_id` e `workout_name`),
  `routes` (com a versão do relevo) e `custom_workouts` (os blocos em JSON). A migração é
  incremental em `data/db/app_database.dart`: **nunca apaga dados**.
- **Android:**
  - `MainActivity.kt`: passa a abertura da tela de carregamento para o Dart pelo canal
    `pedalaqui/abertura`; e a miniatura do pedal (picture-in-picture) pelo canal
    `pedalaqui/miniatura` (`core/miniatura.dart`): o pedal na rota liga ao abrir e desliga ao sair;
  - `res/drawable/splash_logo.xml`: a animação da tela de carregamento;
  - o app fica só em pé (retrato).
- **Testes:** `flutter test` em `app/`; `node --test` na raiz (protótipo). Os testes de tela usam
  as lojas em memória (`Memory…Store`).

## 6. Jeito de trabalhar (combinado com o usuário)

- **Toda resposta termina com “Resumo:”** de 3 a 5 linhas, em português simples (está no `CLAUDE.md`).
- **Antes de criar algo novo:** desenho primeiro (habilidade *brainstorming*: perguntas, opções,
  esboço, documento em `docs/superpowers/specs/`). Só programa depois do “ok” do usuário.
- **O plano** (`docs/superpowers/plans/`) é uma lista curta de tarefas, executada direto com testes
  primeiro (TDD), sem escrever o código no plano. No fim, entram notas e o número de testes.
- **Git:**
  - commits com `git -c user.email=304986910+estefanohrauber-web@users.noreply.github.com`
    (nunca o Gmail), terminando com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - `git push` liberado para commits normais no `main`;
  - **perguntar antes** de force-push, repositório novo ou mudar a visibilidade;
  - adicionar só caminhos de `app/` e `docs/`. **Nunca** commitar os arquivos do protótipo na raiz
    nem o README (estão “modificados” só por quebra de linha CRLF).
- **Celular:**
  - pedidos de permissão do Android são do usuário: **nunca tocar neles**;
  - **nunca** `pm clear` nem desinstalar o app (apaga as rotas reais);
  - não desbloquear o celular; isso é o usuário quem faz;
  - tirar foto da tela (ou conferir o foco) **antes de cada toque** pelo `adb`; nunca tocar às cegas;
  - ler só os registros do próprio app; não ler nem contar notificações particulares;
  - antes de instalar uma versão que muda o banco, fazer uma cópia do banco (seção 8).
- **Código:**
  - `dart format` só em arquivos novos; nos existentes, formatar à mão (largura 120);
  - explicar as escolhas sem jargão.
- **Windows:** não desligar o Controle Inteligente de Aplicativos (só volta reinstalando o Windows).
- Ações destrutivas ou irreversíveis: **pedir confirmação** antes.

## 7. Próximos passos (em ordem)

### 7.1 Servidores com Supabase (o próximo trabalho)
O usuário já tem conta no Supabase e conta de desenvolvedor no Google Play.

**Proposta, ainda para desenhar e aprovar:**
1. **Conta e backup automático.** Login com Google; rotas, pedais (com amostras), treinos do usuário
   e ajustes sincronizados no Supabase (Postgres, com segurança por linha, RLS).
   - O usuário nunca perde nada e pode trocar de celular.
   - Isso também resolve a troca da versão de teste pela da Play Store (7.6).
2. **Compartilhar** rotas e treinos com amigos por link.
3. **Strava**: enviar o pedal. A chave secreta do Strava fica numa função do Supabase (Edge Function).
4. Depois: ranking do bairro e desafio do mês (o cartão “Comunidade — em breve” saiu do Início em
   11/10; volta quando existir), fantasma de amigos.

**Cuidados:**
- no app vai só a chave pública (*anon*); a *service_role* **nunca** vai no app nem no chat;
- a Play Store exige **política de privacidade** quando há conta e dados guardados (LGPD);
  o Claude redige;
- o plano grátis do Supabase pausa o projeto depois de uma semana sem uso.

### 7.2 Winnek: dados chegando (10/10)
- **Funcionou em 10/10:** o app agora pede o controle e manda a bike começar ao conectar (FTMS 0x00
  e depois 0x07). Sem isso, ela mandava tudo zerado e derrubava a conexão a cada 60 s. Vieram ao vivo
  47–87 rpm e 100–264 W. Recém-acordada, ela diz “ok” mas não começa: o app insiste a cada 5 s até
  o aviso “começou” ou os dados chegarem (falta confirmar isso num pedal).
- **O que ela manda:** velocidade, giro, distância, watts, calorias e tempo (FC vem 0, sem cinta).
  O nível de resistência vem sempre 0: ela **não sabe a posição do botão de peso**.
- **Os watts são uma tabela fixa pelo giro** (70 rpm = 190 W, 80 rpm = 233 W, sempre) e a
  velocidade é giro × 0,375. O botão de peso não entra na conta. Ela também diz que aceita
  potência alvo (ERG), mas o botão é manual. **Resolvido em 11/10:** com o botão calibrado
  (Ajustes › Sua bike), o app estima os watts pelo botão e guia pela voz, sem mandar meta para a
  bike. Falta testar num pedal de verdade.
- Diário da bike: Ajustes › Avançado › Ver o que a bike envia › Copiar o diário, ou pelo cabo, com
  `adb -s RQ8R905CDWJ exec-out run-as com.pedallocal.app cat files/bike_log.txt`.

### 7.3 Ideias do usuário depois do pedal de 10/10 (feitas em 11/10)
Todas no app (seção 4); falta conferir no celular, com a bike, a tela nova do pedal, a conexão e a
calibração do botão.
1. **Chegada:** símbolo de chegada no fim do trajeto; numa rota só de ida, o resumo oferece fazer a
   volta.
2. **Tempo e distância** maiores e visíveis na tela do pedal.
3. **Conexão da bike:** mostrar claramente se os dados estão chegando (“hoje é um parto”).
4. **Ajustes** a partir de qualquer aba, e reorganizar a tela (está confusa).
5. **Histórico:** melhorar o design.
6. **Calibrar o botão de peso:** do mais leve ao mais pesado, contando as voltas do botão; depois o
   app guia (“gire 3 voltas”) e sabe a carga para estimar os watts.
7. **Bikes sem controle de resistência:** guiar pela voz, pelos watts (“suba para 180 W”).

### 7.4 Pedido de 11/10 à noite (feito)
Depois de pedalar o Entre pontes com o botão calibrado (13 voltas), o usuário contou:
- **A voz pedia +8 e −8 voltas nas pontes.** A conta usava o pedaço de 100 m mais íngreme (6,4 %) e
  supunha que as 13 voltas equivaliam a 10 %. Agora usa os 200 m mais fortes (a média da subida) e
  o **limite pedalável** (`limiteBotao`, medido na calibração; sem medida, 70 % das voltas).
- **A bike devolve mais watts com o botão mais pesado?** Não: no pedal de 11/10 foram 994 pacotes de
  32 a 68 rpm e cada giro deu sempre os mesmos watts (60 rpm = 149 W), mesmo girando 8 voltas.
- Ideias: aba Você mais forte com todos os pedais, linha fixa no topo, repensar o Início, miniatura
  do mapa por cima de outros apps, calibração guiada pedalando a 60 rpm. Tudo feito (seção 4).
- **Falta conferir no celular:** o Início com o mapa (a foto do PC trava na captura), a miniatura e
  a calibração guiada com a bike.
- Os recordes da aba Você contam os 2 pedais simulados de 08/10 (item abaixo).

### 7.5 Melhorias já combinadas
- O pedal começa no primeiro giro, e pedais vazios ou de teste não são salvos.
- Conferir no celular, com a bike, o pedal do treino com os botões novos (pular, +1 min, ±5 %),
  que só foi testado por testes automáticos.
- Oferecer apagar os 2 pedais simulados de 08/10 (perguntar antes).

### 7.6 Versão final e Play Store
- A versão final é mais rápida, menor e é a única aceita na Play Store.
- Gerar no PC de casa (se o Windows deixar) ou nos servidores do GitHub (GitHub Actions).
- **Assinatura da loja:** criar uma chave de envio (upload key) e usar a Assinatura de apps do
  Google Play. Guardar a chave e as senhas fora do GitHub.
- **Trocar a versão de teste pela da loja** exige desinstalar uma vez, porque as chaves são
  diferentes. Antes, os dados precisam estar no backup (7.1).
- Teste interno da Play Store para o usuário receber as atualizações pela loja. Se a conta de
  desenvolvedor for de depois de nov/2023, o Google exige um **teste fechado com 12 pessoas por
  14 dias** antes de liberar para todos.
- Atualizações: aumentar `version` no `app/pubspec.yaml`, gerar e enviar; os celulares atualizam
  sozinhos sem perder dados.
- Dá para ter as duas versões no celular, a da loja e uma “Pedalaqui Dev” para testes (outro
  `applicationId`).

### 7.7 Extras (depois)
- Importar treinos do Zwift (`.zwo`); escrever o treino numa frase; usar os treinos do usuário nos
  planos; meta por frequência cardíaca.
- Tema escuro; exportar para o Strava.
- A resistência automática **já existe** (modo ERG) para bikes que aceitam comando.

## 8. Dicas e ferramentas

- **Cópia do banco do celular:**
  `adb -s RQ8R905CDWJ exec-out run-as com.pedallocal.app cat databases/pedal_local.db > C:\dev\tmp\backup.db`
  e depois `node C:\dev\tmp\db_resumo.js C:\dev\tmp\backup.db` para ver versão, rotas e pedais.
- **Foto da tela:** `bash C:\dev\tmp\tela.sh nome` → `C:\dev\tmp\nome.png`.
- **Fotos das telas sem celular:** em `app/`, `flutter test tool/fotos_test.dart --update-goldens`
  → `app/tool/fotos/*.png`, com a fonte de verdade. Precisa das fontes Plus Jakarta Sans em
  `C:\dev\tmp\fontes` (baixadas do fonts.gstatic.com, os mesmos arquivos do app).
- **Fotos da abertura em sequência:** `bash C:\dev\tmp\abertura_cap.sh 30`, depois
  `node C:\dev\tmp\raw2png.js C:\dev\tmp\cap` e `quadros.ps1`, `recorte.ps1` ou `juntar.ps1` para
  montar as tiras.
- No Git Bash, comandos do `adb` com caminhos do celular precisam de `MSYS_NO_PATHCONV=1` (senão
  `/data/...` vira `C:/Program Files/Git/data/...`). Do lado do computador, use caminhos `C:/...`.
- A versão de teste demora de 2,5 a 3 s para abrir, e a primeira abertura depois de instalar leva
  uns 7 s. É normal; a versão final é bem mais rápida.

## 9. O arquivo da transferência (.zip)

| Pasta no .zip | O que é | Para onde vai no PC de casa |
|---|---|---|
| `LEIA-ME-PRIMEIRO.md` | este documento | só ler |
| `projeto/pedal-local.bundle` | o repositório inteiro, com todo o histórico | `git clone` (passo 3) |
| `android/debug.keystore` | a chave que assina o app no celular | `%USERPROFILE%\.android\` (passo 4) |
| `claude/memory/` | a memória do Claude sobre o projeto | `%USERPROFILE%\.claude\projects\C--dev-pedal-local\memory\` |
| `claude/skills/`, `claude/agents/` | as habilidades (brainstorming, planos, TDD, Impeccable…) | `%USERPROFILE%\.claude\skills\` e `\agents\` |
| `claude/settings.local.json` | os avisos de design do Impeccable | `%USERPROFILE%\.claude\` (corrigir caminhos se o usuário mudar) |
| `backups-do-celular/` | cópias do banco do app (versões 6 e 7) | guardar; os dados de verdade estão no celular |
| `ferramentas/` | scripts de fotos da tela e do banco | `C:\dev\tmp\` |

**Guarde o .zip só para você.** Ele tem a chave do app e as suas rotas, que mostram onde fica a sua
casa e o seu trabalho.
