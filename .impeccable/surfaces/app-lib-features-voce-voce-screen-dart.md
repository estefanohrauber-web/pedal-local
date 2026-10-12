---
version: 2
slug: "app-lib-features-voce-voce-screen-dart"
primary_target: "app/lib/features/voce/voce_screen.dart"
related_targets: ["app/lib/features/voce/historico_calendario.dart"]
---

Escopo: aba Você: recordes, calendário do mês e todos os pedais. Modo: Operate/Read leve.

## Direction contract
THESIS: a aba Você mostra do que você já foi capaz (recordes) e a constância (calendário); a lista de todos os pedais fica embaixo e o calendário a filtra. Recusa o "desde o começo" de três números soltos.
OWN-WORLD: mundo Pedalaqui; cartão branco "Seus recordes" com os totais numa linha ExtraBold e quatro linhas de recorde (quadrado de ícone verde-claro, título, de onde veio, número tabular à direita); grade do mês com dias em 3 tons de verde; dia escolhido com anel escuro; selo escuro com X para o filtro.
STORY: a pessoa vê os totais e os recordes, toca num recorde para abrir o pedal; no calendário toca num dia verde e a lista mostra só aquele dia; toca de novo, no X ou fora e a lista volta a ter todos.
FIRST VIEWPORT: cabeçalho com nome; cartão "Seus recordes" (km · pedais · tempo · m de subida; mais longe, mais subida, mais tempo, melhor semana); "Histórico" com o cartão do mês; "Todos os pedais" agrupados por dia.
FORM: versão B (recordes) de 3 mostradas no chat em 11/10/2026; o calendário (versão C de antes) fica; sem concept-seed: o dono pediu “me apresente 3 versões aqui no claude antes de executar no app”, e a escolha dele entre as 3 substituiu o sorteio.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
