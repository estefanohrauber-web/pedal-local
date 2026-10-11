---
version: 1
slug: "app-lib-features-bike-calibrar-botao-screen-dart"
primary_target: "app/lib/features/bike/calibrar_botao_screen.dart"
related_targets: []
---

Escopo: calibração do botão de peso (manual) e a guia por voltas no pedal. Modo: Operate. A bike não sabe a posição do botão.

## Direction contract
THESIS: o app conta as voltas por você: gire com uma mão, toque com a outra. Recusa o formulário com campo numérico.
OWN-WORLD: mundo Pedalaqui; um círculo verde grande (220 dp) como alvo de toque com o número de voltas em ExtraBold 84; pílulas de progresso; botão escuro de confirmação.
STORY: começa no mais leve, gira e toca a cada volta inteira, termina no mais pesado; depois o app guia "gire mais 2 voltas" nas subidas e conta o peso nos watts.
FIRST VIEWPORT: título "Toque a cada volta completa", instrução curta, círculo-contador, pílulas, "Desfazer o último toque", botão "Cheguei no mais pesado".
FORM: versão B (toque a cada volta) de 3 mostradas no chat, escolhida em 11/10/2026; sem concept-seed.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
