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
- Nome escrito: Plus Jakarta Sans ExtraBold, “aqui” na cor de destaque e um pininho amarelo
  no lugar do pingo do i (`ı` + desenho).

## Onde está

- `lib/core/widgets/pedalaqui_logo.dart`: o caminho da logo, o desenho (inteiro ou até uma
  fração, para animar), o ícone, o símbolo e o nome escrito.
- Android: ícone adaptável em vetor (`mipmap-anydpi-v26`, fundo verde, frente e versão de
  uma cor para os ícones temáticos), PNG para o Android 7 (`mipmap-*`), gerados por
  `tool/gerar_icones_test.dart` (rodar de novo se a logo mudar).
- `docs/marca/`: ícone e símbolo em SVG (verde e branco), ícone da loja 512 e ícone 1024.

## Abertura

- Tela de carregamento do Android só verde (Android 12+: sem ícone, `values-v31`; antes:
  `launch_background`). Atividade travada em pé (o app já era só em pé).
- `features/abertura/abertura.dart`, por cima do app (2,1 s; um toque pula): a rota se
  desenha da esquerda para a direita e dá a volta no pino (0,08 s a 1,13 s), com o nome se
  revelando junto (borda esfumada que acompanha o ponto mais à direita da linha; no laço
  do pino o nome espera). Com o caminho pronto, a bolinha amarela aparece e o pininho cai
  no i; tudo inteiro até 1,83 s; some até 2,1 s. O app por baixo só é montado com o
  caminho pronto (montar as telas na versão de teste fazia a linha andar aos trancos).
- Os ~2 s de verde antes da animação são da versão de teste (debug: 2,3 a 3,2 s até o
  primeiro quadro). A versão final (release) não deu para gerar neste computador: o
  Controle Inteligente de Aplicativos do Windows bloqueia o gen_snapshot.

## Verificação

304 testes automáticos (logo, abertura e o resto). No celular: ícone e nome novos nas
informações do app; abertura conferida em fotos da tela.
