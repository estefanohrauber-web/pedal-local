---
name: Pedalaqui
description: Pedalar em casa, numa bike ergométrica, as rotas reais do próprio bairro.
colors:
  destaque: "#138A52"
  destaque-texto: "#0E6B3F"
  destaque-suave: "#E3F4EA"
  aqui-amarelo: "#F6C445"
  fundo: "#F4F6F5"
  superficie: "#FFFFFF"
  borda: "#E1E6E3"
  borda-botao: "#D5DCD8"
  divisoria: "#EEF1EF"
  neutro: "#F1F4F2"
  texto: "#14201A"
  texto-suave: "#5A6660"
  escuro: "#14201A"
  posicao: "#2F6FE4"
  fantasma: "#6D28D9"
  aviso-fundo: "#FFF1E0"
  aviso-texto: "#8A3C00"
  calendario-tom-1: "#B9E3CB"
  calendario-tom-2: "#7CCB9E"
typography:
  numero-pedal:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "40px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "-0.5px"
    fontFeature: "tnum"
  titulo:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "26px"
    fontWeight: 800
    letterSpacing: "-0.4px"
  numero-medio:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "26px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "-0.5px"
    fontFeature: "tnum"
  secao:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "16px"
    fontWeight: 800
  corpo-forte:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "15px"
    fontWeight: 700
  subtitulo:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "15px"
    fontWeight: 400
  suave:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  rotulo:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "12px"
    fontWeight: 700
  botao:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "16px"
    fontWeight: 700
  aba:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "11px"
    fontWeight: 600
rounded:
  barra: "6px"
  icone: "12px"
  campo: "14px"
  faixa: "16px"
  cartao-mapa: "18px"
  cartao: "20px"
  folha: "24px"
  pilula: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  card: "16px"
  tela: "20px"
  folha-base: "24px"
components:
  button-primary:
    backgroundColor: "{colors.destaque}"
    textColor: "{colors.superficie}"
    typography: "{typography.botao}"
    rounded: "{rounded.pilula}"
    height: "52px"
  button-dark:
    backgroundColor: "{colors.escuro}"
    textColor: "{colors.superficie}"
    typography: "{typography.botao}"
    rounded: "{rounded.pilula}"
    height: "52px"
  button-outlined:
    backgroundColor: "{colors.superficie}"
    textColor: "{colors.texto}"
    typography: "{typography.corpo-forte}"
    rounded: "{rounded.pilula}"
    height: "52px"
  card:
    backgroundColor: "{colors.superficie}"
    rounded: "{rounded.cartao}"
    padding: "16px"
  card-map-overlay:
    backgroundColor: "{colors.superficie}"
    rounded: "{rounded.cartao-mapa}"
    padding: "16px"
  sheet:
    backgroundColor: "{colors.superficie}"
    rounded: "{rounded.folha}"
    padding: "20px 20px 24px"
  banner-aviso:
    backgroundColor: "{colors.aviso-fundo}"
    textColor: "{colors.aviso-texto}"
    rounded: "{rounded.faixa}"
    padding: "10px 8px 10px 14px"
  banner-sucesso:
    backgroundColor: "{colors.destaque-suave}"
    textColor: "{colors.destaque-texto}"
    rounded: "{rounded.faixa}"
  icon-tile:
    backgroundColor: "{colors.destaque-suave}"
    textColor: "{colors.destaque-texto}"
    rounded: "{rounded.icone}"
  icon-tile-muted:
    backgroundColor: "{colors.neutro}"
    textColor: "{colors.texto-suave}"
    rounded: "{rounded.icone}"
  chip-escuro:
    backgroundColor: "{colors.escuro}"
    textColor: "{colors.superficie}"
    rounded: "{rounded.pilula}"
    padding: "7px 12px"
  input:
    backgroundColor: "{colors.superficie}"
    textColor: "{colors.texto}"
    rounded: "{rounded.campo}"
  tab-bar:
    backgroundColor: "{colors.superficie}"
    textColor: "{colors.texto-suave}"
    typography: "{typography.aba}"
    height: "56px"
  tab-bar-selected:
    textColor: "{colors.destaque}"
  ride-button:
    backgroundColor: "{colors.destaque}"
    textColor: "{colors.superficie}"
    rounded: "{rounded.pilula}"
    size: "62px"
---

# Design System: Pedalaqui

## Overview

**Creative North Star: "O bairro no guidão"**

Pedalaqui é um app claro e amigável para ser lido de relance, com o celular no suporte do guidão a uns 50 cm do rosto, à noite, por alguém suando. Tudo serve a essa leitura: um fundo verde-acinzentado muito claro, cartões brancos de borda fina, um único verde que carrega progresso, ação e "está funcionando", e números grandes em Plus Jakarta Sans ExtraBold com algarismos de largura fixa. O mapa do bairro é o protagonista sempre que há um; os cartões flutuam por cima dele em vez de espremê-lo.

A densidade é baixa e os toques são grandes: botões de pílula com 52 dp de altura, alvos de 44 a 62 dp, um medidor de giro de 220 dp quando a tela é uma calibração. Texto é português do Brasil simples; os rótulos dizem o valor atual ("Ligada · voz automática") em vez de pedir que a pessoa abra para descobrir.

A marca é uma rota que vira um pino de mapa: um traço verde contínuo com uma bolinha amarela no lugar do "aqui". Esse vocabulário (linha de rota, ponto de saída, pino, bandeira de chegada) é o desenho próprio do app e reaparece no mapa, no resumo e no histórico.

**Key Characteristics:**
- Um só verde de ação (destaque) sobre neutros verdes-acinzentados; amarelo só na marca.
- Números do pedal em ExtraBold tabular, o maior elemento da tela.
- Cartões brancos planos com borda fina; sem sombras, exceto o botão de pedalar e o que flutua sobre o mapa.
- Pílulas para tudo que se toca; cantos generosos (20 nos cartões, 24 nas folhas).
- Desenhos próprios do mundo da rota: traço da logo, ponto de saída, bandeira quadriculada.

## Colors

Neutros frios levemente esverdeados, um verde de ação com três intensidades e cores semânticas pontuais para aviso, posição e o fantasma.

### Primary
- **Verde Pedalaqui** (destaque): botões principais, barra de progresso, velocidade no pedal, aba ativa, botão de pedalar, checks concluídos, linha da rota no mapa e fundo do ícone do app.
- **Verde Fundo de Mata** (destaque-texto): texto verde sobre fundos claros ("faltam 1,07 km", "ao vivo", faixa de sucesso, ícones dos quadrados de Ajustes). É o verde que passa contraste em texto pequeno.
- **Verde Orvalho** (destaque-suave): faixa de sucesso, quadrados de ícone, trilho da barra de progresso, faixa da voz na calibração.

### Secondary
- **Amarelo do Aqui** (aqui-amarelo): exclusivo da marca, a bolinha do pino na logo e o anel que se espalha dela. Não é cor de interface.

### Tertiary
- **Azul Você Está Aqui** (posicao): o ponto da posição atual no mapa durante o pedal.
- **Roxo Fantasma** (fantasma): o pedal anterior que corre junto, no mapa e no cartão de recorde do fantasma.
- **Âmbar de Aviso** (aviso-fundo com aviso-texto): faixas de aviso (subida chegando, bike parada, pausa), ações destrutivas leves ("Apagar este pedal").

### Neutral
- **Névoa Verde** (fundo): fundo de toda tela e da barra fixa do topo.
- **Branco** (superficie): cartões, folhas, barra de abas.
- **Borda Liquen** (borda): borda de 1 px dos cartões, da barra de abas, da base da barra do topo, dos campos e do controle de carga.
- **Borda do Botão** (borda-botao): contorno dos botões contornados e do selo da bike no topo, um tom mais escuro que a borda de cartão.
- **Divisória** (divisoria): linhas entre itens dentro de um mesmo cartão (etapas de conexão, assuntos de Ajustes, linhas de recorde, rodapé do calendário).
- **Cinza Neutro** (neutro): quadrados de ícone de coisas secundárias (Avançado, "em breve"), selo "em breve", blocos de número em "Mais dados".
- **Tinta** (texto) e **Grafite Suave** (texto-suave): texto principal e secundário, rótulos de números, abas inativas.
- **Escuro** (escuro): o botão que conclui dentro de uma tarefa (Pausar, "O botão não gira mais", "Salvar"), selos por cima do mapa e da miniatura, selo do dia filtrado no histórico, anel do dia escolhido, bandeira de chegada.

### Escalas de dados (fora da paleta de interface)
Cores de rota (seis, uma por rota salva, escuras o bastante para aparecer sobre o mapa), zonas de esforço 1 a 7 (cinza, azul, verde, amarelo, laranja, vermelho, roxo) e a escala de calor azul-ciano-verde-amarelo-vermelho do mapa e dos gráficos vivem em `app_theme.dart` (`AppColors.rotas`, `zoneColors`, `heatStops`) e só pintam dados. O calendário usa três tons de verde crescentes (calendario-tom-1, calendario-tom-2, destaque) para "mais km".

### Named Rules
**The Um Verde Rule.** Só existe um verde de ação. Tudo que é tocável e principal, tudo que mostra progresso e tudo que diz "está certo" é destaque; texto verde pequeno usa destaque-texto.

**The Amarelo é Marca Rule.** O amarelo do "aqui" aparece só na logo e no ícone. Avisos são âmbar (aviso-fundo/aviso-texto), nunca o amarelo da marca.

**The Escuro Confirma Rule.** Dentro de uma tarefa em andamento, o botão que conclui ou pausa é escuro ("Pausar", "O botão não gira mais", "Salvar"); o verde fica para começar e seguir ("Pronto, pedalar", "Fazer a volta", "Começar").

## Typography

**Display Font:** Plus Jakarta Sans (via Google Fonts; na falta, a fonte do sistema)
**Body Font:** Plus Jakarta Sans
**Label/Mono Font:** monoespaçada do sistema, só no diário técnico de pacotes da bike

**Character:** Uma família só, geométrica e cordial. O peso faz a hierarquia: ExtraBold (800) para números, títulos e o nome Pedalaqui; Bold (700) para rótulos e corpo forte; Regular para explicações.

### Hierarchy
- **Número do pedal** (800, 40 px, 1.05, -0.5 px, tabular): TEMPO e km/h no cartão de baixo do pedal. Variantes da mesma regra: 64 (voltas do botão no resultado da calibração), 56 (giro no medidor da calibração), 34 (volta atual da calibração), 30 (tempo e distância na chegada), 26 (km feitos no topo do pedal, MetricTile), 24 (números ao vivo da conexão), 22 (média e potência na chegada, blocos de "Mais dados"), 17 (linha rpm · watts · inclinação), 14 (velocidade no selo da miniatura). Todos via `estiloNumero`.
- **Título** (800, 26 px, -0.4 px): título de página no conteúdo ("Bora pedalar?"; "Ensine o botão ao app" e "Pedal concluído" a 24).
- **Seção** (800, 16 px): títulos de seção ("Seus recordes", "Outras bikes por perto"). Títulos de dia na lista de pedais vão a 13 em ExtraBold texto-suave.
- **Corpo forte** (700, 15 px): nome de item em lista, título de assunto em Ajustes, rótulo do controle de carga.
- **Subtítulo** (400, 15 px) e **Suave** (400, 13 px): explicações e resumos de linha, em texto-suave.
- **Rótulo** (700, 12 px): rótulos ao lado ou acima dos números ("TEMPO", "km/h", "rpm"), selo ao vivo (800).
- **Botão** (700, 16 px; 15 no contornado): herda a família do tema via labelLarge.
- **Aba** (600, 700 ativa, 11 px): rótulos da barra de abas.

O nome **Pedalaqui** é sempre ExtraBold real (não negrito sintético), letterSpacing -0.02 em, com "aqui" em destaque.

### Named Rules
**The Número Tabular Rule.** Todo número que muda durante o pedal é ExtraBold com algarismos tabulares e encolhe (FittedBox) em vez de quebrar linha. Unidade e rótulo vão menores e em texto-suave ao lado.

**The Peso Antes do Tamanho Rule.** Hierarquia vem primeiro do peso (800/700/400) e da cor (texto/texto-suave), depois do tamanho. Não há caixa-alta decorativa nem espaçamento largo de letras; o único rótulo em caixa-alta é "TEMPO", um rótulo de dado sobre o número, não um título.

## Layout

Coluna única em retrato, pensada para 360 dp de largura. Margem lateral de tela de 20 dp (folhas: 20, 20, 20, 24 na base); cartões com 16 dp de padding interno; espaços de 8, 10 e 12 dp entre elementos e 4 dp entre título e resumo. Itens de lista ficam juntos num mesmo cartão, separados por divisórias de 1 px, em vez de um cartão por item; grupos de natureza diferente (Avançado) vão num cartão à parte.

Toda aba tem a mesma barra fixa no topo (nome Pedalaqui, selo da bike, engrenagem de Ajustes); telas abertas por cima trazem a própria barra com fechar ou voltar.

Quando há mapa, ele ocupa a tela inteira (pedal; na miniatura do Android, uma janela 16:9 só com o mapa) ou a metade de cima (chegada), e o conteúdo flutua: cartões a 18 dp de canto no topo e na base do pedal, folha branca de canto 24 subindo sobre o mapa na chegada. Ações principais ficam embaixo, ao alcance do polegar, em largura total. Linhas de toque crescem com a fonte do sistema (alturas mínimas, não fixas).

## Elevation & Depth

O sistema é plano: cartões, folhas e a barra de abas usam elevação 0 e se separam do fundo pela cor branca e pela borda fina. Profundidade aparece só em dois casos: o botão de pedalar, que sobe 14 dp acima da barra de abas com elevação 6 e uma sombra verde translúcida, e os controles que flutuam sobre o mapa (botões e marcadores na criação de rota e na preparação), com sombras curtas e neutras.

### Shadow Vocabulary
- **Brilho do Pedalar** (Material elevation 6, shadowColor destaque a 40 %): só o botão central da barra de abas.
- **Sobre o mapa** (elevation 2 a 8; marcadores com `0 0 3-4px rgba(0,0,0,0.2)`): controles e marcadores flutuando sobre o mapa, para não se perderem nas cores do OpenStreetMap.

### Named Rules
**The Plano Por Padrão Rule.** Superfície sobre o fundo do app não tem sombra; usa branco e borda. Sombra é para o botão de pedalar e para o que precisa se destacar do mapa.

## Shapes

Formas arredondadas e macias. Tudo que se toca é pílula (999); cartões têm 20 dp de canto, cartões sobre o mapa 18, folhas 24 só no topo, faixas de aviso e sucesso 16, campos, blocos de número e quadrados de ícone de 44 dp 14, quadrados de ícone de 40 dp (recordes, passos da calibração) e de Ajustes 12, barra de progresso 6, barras de giro da calibração 3. Círculos marcam estado e lugar: checks verdes das etapas, dias pedalados no calendário, ponto de saída (branco com borda verde de 4 dp), posição azul, fantasma roxo com borda branca, a bolinha do selo da bike e o botão de pedalar.

A forma assinatura é o traço da rota: linha grossa de pontas redondas que passa por colinas e vira o pino. O ícone do app é esse traço branco num quadrado verde com cantos de 22,7 % do lado.

## Components

### Buttons
Grandes, em pílula, sem sombra; diz o que acontece ("Fazer a volta · 2,91 km", "Pronto, pedalar").
- **Shape:** pílula (999), altura mínima 52 dp; Pausar no pedal 116 × 52.
- **Primary:** fundo destaque, texto branco Bold 16. Começar ou seguir.
- **Escuro:** fundo escuro, texto branco. Concluir ou pausar dentro de uma tarefa ("Salvar", "O botão não gira mais").
- **Contornado:** fundo transparente, borda borda-botao, texto tinta Bold 15. Alternativa ("Concluir", "Mais dados", "Usar bike simulada", Encerrar a 44 dp no topo do pedal).
- **Texto:** TextButton verde para ações leves ("Desconectar", "Procurar de novo", "Desfazer uma volta", "Calibrar de novo").
- **Ícone tonal:** IconButton.filledTonal para − / + (controle de carga, ajuste do número na calibração).
- **States:** ripple padrão do Material 3; desabilitado pelo tema.

### Chips
- **Selo escuro sobre o mapa:** pílula escuro a 85 a 100 %, texto branco ExtraBold 13 a 14, ícone à esquerda ("Chegada · Entre pontes", diferença para o fantasma).
- **Selo ao vivo:** bolinha de 8 dp mais texto ExtraBold 12 na cor do estado (verde ao vivo, âmbar parada ou sem dados, cinza reconectando).
- **Selo da bike (topo):** pílula branca com borda borda-botao, 44 dp de altura mínima; bolinha de 8 dp (verde vivo ao vivo, âmbar ou cinza nos outros estados) e o nome da bike em ExtraBold 13 tinta. Sem bike: ícone de bluetooth e "Conectar" em destaque-texto. Tocar abre a conexão.
- **Filtro de dia (histórico):** pílula escura com o nome do dia em ExtraBold 13 branco e um X; tocar no X ou fora limpa o filtro.
- **Em breve:** pílula neutro, texto-suave ExtraBold 12.
- **Escolha de métrica (gráficos):** ChoiceChip do Material, selecionado em verde claro.

### Cards / Containers
- **Corner Style:** 20 dp (theme), 18 sobre o mapa, 24 folha.
- **Background:** superficie.
- **Shadow Strategy:** nenhuma (ver Elevation & Depth).
- **Border:** 1 px borda; cartão escolhido ou de conquista com borda de 2 px na cor do assunto (destaque, fantasma).
- **Internal Padding:** 16 dp.

### Inputs / Fields
- **Style:** preenchido em branco, borda 1 px borda, canto 14.
- **Focus / Error:** padrão do Material 3 com a cor primária do tema.

### Navigation
- **Barra de abas:** cinco posições de largura igual (Início, Explorar, botão de pedalar, Treinos, Você), fundo branco com borda de cima, itens de 56 dp mínimos com ícone contornado e rótulo 11. Ativa em destaque e Bold; inativa em texto-suave.
- **Botão de pedalar:** círculo verde de 62 dp com play branco, subindo 14 dp acima da barra.
- **Barra do topo (fixa nas abas):** cor do fundo, sem elevação, borda de 1 px borda embaixo; PedalaquiWordmark 22 à esquerda, selo da bike e engrenagem de Ajustes à direita. A engrenagem não se repete dentro das abas.

### Faixas (AvisoFaixa e sucesso)
Faixa de largura total, canto 16, ícone à esquerda e texto Bold. Aviso em âmbar (aviso-fundo/aviso-texto), com ação opcional à direita; sucesso em destaque-suave/destaque-texto ("Tudo certo: giro, potência e velocidade estão vindo da bike.").

### Linha de assunto (Ajustes)
Quadrado de ícone de 44 dp (canto 12, destaque-suave com ícone destaque-texto; neutro e cinza para Avançado), título Corpo forte, resumo Suave com o valor atual em até duas linhas, chevron à direita. Linhas agrupadas num cartão, separadas por divisória.

### Lista de verificação (Conectar bike)
Etapas num cartão, cada uma com círculo verde e check branco quando feita; a última mostra os números ao vivo em verde ExtraBold 24 com unidade Rótulo. Embaixo, a faixa de sucesso e o botão principal.

### Cartões do pedal (sobre o mapa)
Topo: nome da rota, selo ao vivo, voz, Encerrar, "1,84 de 2,91 km" (26 e texto-suave), "faltam" em destaque-texto e barra de progresso de 6 dp verde sobre destaque-suave. Base: perfil de relevo preenchido em verde até a posição, TEMPO e km/h a 40 (velocidade em verde), linha rpm · watts · inclinação, "Mais dados" contornado e Pausar escuro. Controle de carga: pílula com borda e botões − / + tonais.

### Calendário do histórico
Grade do mês num cartão; dias pedalados em círculos de 34 dp em três tons de verde (mais escuro = mais km), dia escolhido com anel escuro de 2 dp, dias futuros esmaecidos; rodapé com três MetricTile (pedais, km, dias seguidos).

### Cartões do Início
"Hoje": cartão de canto 20 com o mapa da rota em 150 dp (traço com contorno branco e ponto de saída), nome e km, linha do fantasma (bolinha roxa e "Seu recorde: m:ss. Bora bater?") e "Pedalar de novo" verde. Meta da semana com barra de 8 dp. "Pedal livre" é uma linha clara com quadrado de ícone neutro. Sem rota: quadrado de ícone 44 destaque-suave e "Crie sua primeira rota".

### Seus recordes (Você)
Um cartão: quatro MetricTile de totais (km, pedais, tempo como "1h23", m de subida), depois linhas de recorde com quadrado de ícone de 40 dp destaque-suave, título, de onde veio e o número tabular à direita, separadas por divisória. Abaixo do calendário, "Todos os pedais" agrupado por dia; só dias pedalados são tocáveis e filtram a lista.

### Calibração guiada do botão
Introdução com quatro passos em quadrados de ícone e faixa âmbar se não há bike. Durante: faixa da voz (destaque-suave, fala entre aspas em destaque-texto ExtraBold 15), medidor em arco de 0 a 100 rpm com a faixa de 55 a 65 em calendario-tom-1 e o arco vivo em destaque (aviso-texto abaixo de 50 rpm), giro a 56, "Volta N · próxima em X s" com barra de 6 dp, cartão "Giro em cada volta" com uma barra por volta (destaque = manteve, aviso-texto = caiu, verde claro = atual, neutro = por vir), "Desfazer uma volta" em texto e "O botão não gira mais" escuro. Resultado: número a 64 entre botões − / + tonais, achados em linhas com ícone e "Salvar" escuro.

### Miniatura do pedal (picture-in-picture)
Janela 16:9 só com o mapa: selo escuro de velocidade no canto de cima (número a 14 branco e "km/h"), crédito do OpenStreetMap e barra de progresso de 4 dp colada embaixo.

### Marcas do mapa
Ponto de saída (bolinha branca de 18 dp com borda verde de 4), bandeira quadriculada desenhada (mastro e pano 4 × 3 em escuro e branco), posição azul e fantasma roxo. São desenhos próprios, não ícones de fonte.

### Logo
`PedalaquiMark` (traço da rota, branco ou verde, bolinha amarela), `PedalaquiIcon` (traço no quadrado verde) e `PedalaquiWordmark` ("Pedal" em tinta, "aqui" em destaque).

## Do's and Don'ts

### Do:
- **Do** usar `estiloNumero` (ExtraBold, tabular, -0.5) para todo número do pedal e `estiloRotulo` para o rótulo dele.
- **Do** usar o verde destaque para começar e seguir, e o escuro para pausar ou concluir dentro de uma tarefa.
- **Do** agrupar itens de lista num cartão branco de canto 20 com divisórias, e mostrar o valor atual em cada linha.
- **Do** deixar o mapa ocupar a tela e flutuar cartões de canto 18 por cima dele.
- **Do** usar faixas âmbar para aviso e verde-claro para sucesso, com texto Bold.
- **Do** desenhar marcas de mapa e de chegada com os desenhos próprios (ponto de saída, bandeira, traço da logo).
- **Do** manter alvos de toque de 44 dp ou mais e botões de 52 dp, com alturas que crescem com a fonte do sistema.

### Don't:
- **Don't** usar o amarelo da marca em interface ou aviso.
- **Don't** pôr sombra em cartões e folhas sobre o fundo do app; só o botão de pedalar e o que flutua sobre o mapa têm sombra.
- **Don't** introduzir um segundo verde de ação, nem cores de dados (rotas, zonas, calor) como cor de interface.
- **Don't** escrever setas, símbolos ou caracteres como ícone (por exemplo "↑" para subida); use ícones do Material ou desenhos próprios.
- **Don't** pôr textos-rótulo em caixa-alta acima de títulos; a hierarquia vem do peso.
- **Don't** usar negrito sintético para o nome Pedalaqui; use Plus Jakarta Sans ExtraBold real.

## Known gaps (not decisions)

- Não existe tema escuro ainda; o pedal noturno roda no tema claro.
- O caractere "↑" ainda aparece como ícone em `route_tile.dart`, `criar_rota_screen.dart`, `gerar_volta_sheet.dart` e `preparar_pedal_screen.dart`. É um defeito a corrigir, não um padrão.
- O texto dos botões herda a fonte do tema por `labelLarge` (em `buildAppTheme`); sem esse vínculo os botões saem na fonte padrão do Android.
- Nas telas abertas por cima das abas (Calibrar, Ajustes, Conectar, Treino…), o título da barra sai no titleLarge do Material (Regular 22), enquanto os títulos dentro do conteúdo são ExtraBold; as abas já usam o nome Pedalaqui. Ainda não há uma regra única.
- Divisória (divisoria), borda do botão (borda-botao, também no selo da bike), os tons do calendário (calendario-tom-1 também no medidor e nas barras da calibração) e o verde vivo do selo ao vivo e do selo da bike (#1FB866) estão escritos direto no código, fora de `AppColors`.
