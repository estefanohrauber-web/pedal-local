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

- **Android 12+:** a tela de carregamento do sistema já desenha a rota (ícone animado
  `splash_logo.xml`, 0,75 s, mesmo tamanho e lugar do símbolo de 160 dp da abertura). A
  MainActivity segura essa tela até o desenho terminar e a tira sem a animação padrão; avisa
  o Dart pelo argumento `linha-pronta`, e a abertura continua da linha pronta (conferido
  no celular: mesma caixa de pixels nas duas telas). Antes do 12, o app desenha a linha.
- **Depois da linha (ms):** a bolinha amarela pinga (elástica, 0–520) com um anel se
  espalhando (60–760); o nome se revela da esquerda (0–380); o pininho cai no i quicando
  (200–700); o app é montado por baixo (700); a logo fica parada até 1080; e a bolinha vira
  uma janela redonda que cresce e mostra o app, com a logo se aproximando e sumindo
  (1080–1520). Total ≈ 2,3 s do toque no ícone ao app. Um toque pula para a janela.
- **Os ~2 s parados:** a versão de teste (debug) leva 2,3 a 3,2 s até o primeiro quadro do
  app; com a tela de carregamento animada, esse tempo mostra a rota se desenhando e depois a
  linha pronta. Na versão final (release) o app fica pronto antes do fim do desenho. Ela não
  dá para gerar neste computador: o Controle Inteligente de Aplicativos do Windows bloqueia
  o gen_snapshot.

## Verificação

305 testes automáticos (logo, abertura e o resto). No celular: ícone e nome novos nas
informações do app; abertura conferida em fotos da tela.
