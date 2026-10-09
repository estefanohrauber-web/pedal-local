# Nome, logo e abertura — Pedalaqui

Data: 2026-10-09.

## Nome

- **Pesquisa:** o concorrente mais parecido é o LocalRide (iPhone, jan/2026: rotas tocando
  no mapa, relevo vira carga). No Brasil não há app de bike em casa com rotas reais. Nomes
  com “Pedal” e “Rota” se perdem na loja; “Magrela” é marca de bicicleta (INPI, classe 12);
  “Pedala” sozinho foi recusado pelo INPI (descritivo); “Pedalaí” e “Pedalando” já são marcas.
- **Escolha: Pedalaqui** (“pedala aqui”: as suas ruas, aqui em casa). Sem app igual na Google
  Play, sem marca no INPI (busca por radical PEDALA), `pedalaqui.com.br` e `.app` livres na
  data. Antes de publicar, fazer a busca completa no INPI (inclusive por figura).
- Só o nome visível muda (Android `android:label`, `MaterialApp.title`); pasta, pacote
  (`com.pedallocal.app`) e código continuam `pedal_local`, para não perder os dados.

## Logo (E3, “a rota vira o pino”)

- Ajuste do usuário (mesmo dia): o cruzamento embaixo do pino virou um X de linhas retas.
  Os lados do pino são as retas que saem da ponta e tocam a cabeça (35,4° com a vertical),
  continuadas 16 abaixo da ponta; o traço é contínuo: sobe reto pelo lado direito, contorna
  a cabeça e desce reto pelo esquerdo, sem trancos (é também a ordem da animação).
- Uma linha só: passa por uma colina, sobe a segunda e no alto se enrola e forma o pino
  (“aqui”), depois segue. Bolinha amarela `#F6C445` no pino; verde `#138A52`
  (`AppColors.destaque`); linha branca de 12 num quadro de 200.
- Escolhida entre 7 esboços e 3 refinamentos (página de esboços no claude.ai). Comparada
  com 43 ícones de apps de bike e trilha da Google Play: o mais parecido era o AllTrails
  (montanha de linha sobre verde); nenhum usa o relevo com o pino no traço.
- Nome escrito: Plus Jakarta Sans ExtraBold, “aqui” na cor de destaque, com o i normal (o
  pininho amarelo no pingo do i saiu em 09/10 para a logo ficar mais limpa).

## Onde está

- `lib/core/widgets/pedalaqui_logo.dart`: o caminho da logo, o desenho (inteiro ou até uma
  fração, para animar), o ícone, o símbolo e o nome escrito.
- Android: ícone adaptável em vetor (`mipmap-anydpi-v26`, fundo verde, frente e versão de
  uma cor para os ícones temáticos), PNG para o Android 7 (`mipmap-*`), gerados por
  `tool/gerar_icones_test.dart` (rodar de novo se a logo mudar).
- `docs/marca/`: ícone e símbolo em SVG (verde e branco), ícone da loja 512 e ícone 1024.

## Abertura

Uma linha do tempo só, em ms desde o começo da animação (o toque no ícone):

- **Começo (0–750):** a rota se desenha. **750–1270:** a bolinha amarela pinga (curva
  elástica). **A partir de 810:** um anel sai da bolinha (cresce e some em 700 ms) a cada
  1,2 s, enquanto o app carrega. Nada fica parado esperando.
- **Android 12+:** esse começo é o ícone animado da tela de carregamento do sistema
  (`splash_logo.xml`, mesmo tamanho e lugar do símbolo de 160 dp da abertura, mesmas curvas).
  Quando o app fica pronto, a MainActivity conta ao Dart, pelo canal `pedalaqui/abertura`,
  quando a animação começou (no relógio dos quadros, o mesmo do Flutter); o app desenha a
  logo nesse mesmo ponto e responde depois de dois quadros, e só então a tela de carregamento
  sai, sem a animação padrão. Se ela não tinha animação, o app desenha tudo; se o aviso não
  chega em 1 s (e 60 quadros), também. Antes do 12, o app desenha tudo.
- **Depois que o app assume (e não antes de 750), em ms:** o nome se revela da esquerda
  (0–380); o app é montado por baixo (600); a logo fica parada até 900; e a bolinha vira uma
  janela redonda que cresce e mostra o app, com a logo se aproximando e sumindo (900–1340). O anel que estiver saindo termina; outro não sai. Um
  toque pula para a janela.
- **Tempo total:** o app pronto em até 0,75 s dá 2,1 s do toque ao app. A versão de teste
  (debug) leva 2,3 a 3,2 s para ficar pronta, e esse tempo passa com a bolinha soltando
  anéis. A versão final (release) não dá para gerar neste computador: o Controle Inteligente
  de Aplicativos do Windows bloqueia o gen_snapshot.

## Verificação

308 testes automáticos (logo, abertura e o resto). No celular: ícone e nome novos nas
informações do app; abertura conferida em fotos da tela (a passagem da tela de carregamento
para o app sem pulo, com o app pronto em 2,6, 3,2 e 7,3 s).
