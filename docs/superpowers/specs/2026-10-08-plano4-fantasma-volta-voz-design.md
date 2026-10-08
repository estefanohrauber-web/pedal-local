# Plano 4 — Fantasma, volta automática e voz — design

Data: 2026-10-08. Pedido: “executar as 3 primeiras sugestões” da comparação com os
concorrentes (Zwift HoloReplay, BKOOL fantasmas, Komoot/Strava gerador de voltas,
avisos falados).

## 1. Fantasma

- **O que é:** um pedal anterior refeito no tempo. No mapa, uma bolinha roxa; por cima do
  mapa, uma pílula “0:12 à frente do fantasma” (verde) ou “atrás” (laranja).
- **Contra quem** (escolha no Preparar, chips): na ida, “Seu recorde” (o pedal concluído
  mais rápido) e “Último pedal”; na volta fechada, “Sua melhor volta” (a volta completa
  mais rápida de qualquer pedal) e “Sua última volta” (a última volta completa do pedal
  mais novo). Na volta fechada o fantasma repete essa volta a cada volta. Só entram pedais
  do mesmo sentido. Se recorde e último são o mesmo, aparece só o recorde. Padrão: recorde.
- **Conta:** `vantagem (s) = tempoDoFantasma(minhaDistância) − meuTempo`;
  `fantasma à frente (m) = distânciaDoFantasma(meuTempo) − minhaDistância`. Tempo em
  movimento dos dois (pausar pausa o fantasma junto).
- **Volta de comprimento diferente** (o começo escolhido muda um pouco a volta): a volta
  gravada é esticada para o comprimento de hoje.
- **Fim:** o resumo recém-pedalado mostra “Você venceu o fantasma por 0:12!” (passado na
  URL `?fantasma=`, não fica no banco; o cartão de comparação do histórico já mostra o
  recorde).
- Arquivos: `domain/ghost.dart`, `features/pedal/ghost_options.dart`; `RideTarget.ghost`
  (`?fantasma=recorde|ultimo`); `RidesStore.forRoute(withSamples:)`.

## 2. Volta automática

- No editor, ferramenta “Gerar volta”: distância 3, 5, 10 ou 20 km e “Mais subida”.
  Partida: o primeiro ponto marcado ou, sem pontos, o centro do mapa.
- **Geometria** (`domain/loop_geometry.dart`): círculo que passa pela partida, centro no
  rumo θ, 3 pontos a 90°, 180° e 270°; raio inicial `D / 2π × 0,75`. 3 rumos (6 com mais
  subida).
- **Ajuste do tamanho:** até 3 tentativas por rumo. Regra de três e, depois de uma volta
  curta e uma longa, o meio entre os dois raios (testado em Herval d'Oeste: o rio faz o
  comprimento oscilar, 4,3 → 7,3 → 3,5 km com regra de três pura). Guarda sempre a
  tentativa mais perto do pedido.
- **Escolha:** mais perto do pedido primeiro; tira voltas repetidas (80 % sobrepostas) e,
  havendo outras, as que ficam a mais de 30 % do pedido. Com mais subida, mede a altitude
  de todas e ordena por subida por km. Mostra até 3, com desenho, km e subida.
- **Pontos na rua:** os pontos do círculo caem no mato ou no meio da quadra; cada um é
  levado para o ponto mais perto do caminho traçado, para arrastar no editor.
- Custo: cada tentativa é 1 pedido ao Valhalla (1 por segundo): ~15 s para 3 rumos,
  ~30 s com mais subida. Barra de progresso.
- Em área rural, com poucas estradas, o resultado costuma ser ida e volta pela mesma
  estrada (visto no celular). É limitação do lugar, não do gerador.

## 3. Voz

- Pacote `flutter_tts` (leitor de texto do Android, pt-BR, fila de frases, abaixa a música
  enquanto fala). `TtsVoice` nunca derruba o pedal se o celular não tiver voz.
- **O que fala** (`domain/ride_narrator.dart`): subida e descida que vêm pela frente;
  cada km com o tempo; volta concluída com o tempo; metade da rota e “Faltam 200 metros!”
  (ida); “Você passou o fantasma!” / “O fantasma passou você.” (com folga de 15 m para não
  repetir); queda da bike; frase do fim com o resultado contra o fantasma.
- Ligar e desligar: Ajustes → Voz (com “Ouvir um exemplo”) e o botão do alto-falante no
  pedal; a escolha fica guardada (`AppSettings.voz`, padrão ligado).
- Manifest: `queries` com `android.intent.action.TTS_SERVICE` (exigência do Android 11+).

## Correções que apareceram no caminho

- **Aviso de subida dizia a média, não a subida:** numa subida de 10 %, o aviso disparava
  com a média dos 200 m à frente em 4 % e dizia “4 %”. Agora diz a inclinação do trecho de
  100 m mais íngreme nos próximos 300 m (vale também para o aviso escrito).
- **Volta completa por um fio:** um pedal gravado terminou 0,1 mm antes do fim da volta e
  não contava como volta completa (o fantasma não aparecia). `lapSlices` agora aceita
  0,5 m de folga (`lapToleranceM`).
- **Mapa do Preparar cortado:** o painel cresce quando chegam os pedais do fantasma; o
  mapa agora se enquadra de novo quando muda de tamanho.

## Verificado no celular (SM-G780G)

- Preparar da “Entre pontes”: “Correr contra o fantasma · Sua melhor volta · 6:25”, mapa
  inteiro.
- Gerar volta de 5 km a partir da localização: opções de 5,08 e 5,35 km com subida;
  escolher uma leva para o editor com os pontos na estrada; nada salvo.
- Ajustes → Voz → Ouvir um exemplo: o leitor do Android falou a frase e devolveu o som.
- Não verificado no celular: o pedal inteiro contra o fantasma e as frases durante o pedal
  (precisam da bike; cobertos pelos testes automáticos).
