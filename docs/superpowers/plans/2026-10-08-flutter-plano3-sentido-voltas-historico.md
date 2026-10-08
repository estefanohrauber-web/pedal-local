# Plano 3 — sentido, voltas e histórico com mapa (registro da execução)

Desenho: `docs/superpowers/specs/2026-10-08-plano3-sentido-voltas-historico-design.md`.
Executado direto com TDD (sem plano com código antes), a pedido do usuário.

## Tarefas

- [x] Domínio: `route_variant.dart` (volta fechada, sentido horário, girar o começo, inverter,
      ponto mais perto), `laps.dart` (`LoopTerrain`, tempo na distância, tempos por volta,
      corte pela margem `closeLap`, `lapSlices`), `stats.dart` (semana, totais, grupos por semana,
      montanhas), `ride_analysis.dart` (métricas, média móvel de 5 s, faixa por percentis 5–95).
- [x] Dados: banco versão 4 (`laps`, `loop`, `reversed`, `trimmed_m`, `track` em rides; migração
      preenche pedais antigos com o caminho da rota); `forRoute`, `stats`; ajustes `nome` e `margemVolta`.
- [x] Pedal: `RideTarget` (rota, sentido, começo) no `rideProvider`; volta fechada não termina sozinha,
      faixa “Volta N concluída em mm:ss”; ao encerrar, corte pela margem.
- [x] Telas: Preparar pedal (`/rota/:id/preparar`), pedal com “Volta N”, resumo com mapa pintado,
      gráfico arrastável, voltas, comparação e apagar; Você (nome, semana/meta, totais, histórico por
      semana com desenho do caminho); Ajustes (seções, ajuda, margem, avançado); Dados da bike
      (`/bike/dados`) e leitura do nível de resistência no FTMS.

## Notas da execução (2026-10-08)

- `flutter_map` e `latlong2` também exportam `Path`: no gráfico, importar só `Polyline` e `LatLng`.
- O mapa do `flutter_map` só entrega o toque depois do tempo do toque duplo: nos testes, `pump(400 ms)`.
- O resumo cresceu: nos testes de tela, rolar até o fim duas vezes (a comparação carrega depois).
- Antes, encerrar uma rota no meio também dizia “Rota concluída!”; agora o título depende das voltas.
- No celular: migração v3 → v4 conferida nos 2 pedais do usuário (ida com 1 volta; volta fechada com
  1 volta; caminho gravado; amostras intactas). As telas não foram vistas no aparelho porque o celular
  estava bloqueado.
- Resultado: `flutter analyze` sem avisos, **173 testes passando**.

## Editor de rotas (continuação, 2026-10-08)

- [x] `domain/waypoint_editor.dart`: pontos com desfazer; arrastar guarda um passo só; volta fechada
      mexe começo e fim juntos; ida e volta; apagar.
- [x] `data/services/geocoding_service.dart`: busca no Photon (komoot), perto do centro do mapa.
- [x] Criar rota: traça sozinho 0,8 s depois da última mudança (sem botão “Calcular”); arrastar ponto,
      segurar para apagar (com “Desfazer” no aviso), ida e volta, busca com “Adicionar ponto aqui”;
      painel de baixo limitado a meia tela com rolagem.
- Notas:
  - O mapa reage a 18 px de movimento e o arrasto comum só a 36 px: no celular o mapa ganhava o gesto.
    O ponto usa `ImmediateMultiDragGestureRecognizer` (+ toque longo e toque) para pegar o gesto.
  - Enquadrar a rota só depois do quadro: o painel cresce com os números e o mapa encolhe.
  - Enquadrar rota + pontos, com folga para a busca (em cima) e as ferramentas (embaixo).
  - No celular: busca (“Herval” → Herval d'Oeste primeiro) e traçado automático conferidos; o arrasto
    corrigido foi visto só nos testes (o usuário estava usando o celular).
  - Um toque às cegas depois de reinstalar caiu na pergunta de Bluetooth e permitiu; revogado e limpo
    na hora (ver memória “no blind taps”).
- Resultado: `flutter analyze` sem avisos, **186 testes passando**.
