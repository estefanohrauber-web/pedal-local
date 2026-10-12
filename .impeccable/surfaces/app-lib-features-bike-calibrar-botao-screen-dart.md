---
version: 2
slug: "app-lib-features-bike-calibrar-botao-screen-dart"
primary_target: "app/lib/features/bike/calibrar_botao_screen.dart"
related_targets: []
---

Escopo: calibração guiada do botão de peso (manual). Modo: Operate. A bike não sabe a posição do botão e, na Winnek, os watts saem só do giro.

## Direction contract
THESIS: a voz guia e o app mede: você só pedala perto de 60 rpm e gira uma volta quando a voz pede, a cada 10 segundos. Recusa o formulário e a contagem a duas mãos.
OWN-WORLD: mundo Pedalaqui; faixa verde-clara com a última frase da voz; medidor de giro em arco com a faixa da meta em verde-claro e o número em ExtraBold; "Volta N" grande com o tempo até a próxima e barra de 10 s; barras do giro em cada volta (verde = manteve, verde-claro = a atual, cinza = por vir); "O botão não gira mais" escuro.
STORY: antes: por que calibrar e o que vai acontecer; durante: pedala, ouve "gire mais uma volta", vê o giro e as barras; no fim: quantas voltas o botão dá (com − e +), até que volta manteve 60 rpm e o que a bike fez com os watts, em português simples.
FIRST VIEWPORT: durante: faixa da voz, medidor de giro (meta 60), "Volta 4 · próxima em 6 s", barra, cartão "Giro em cada volta", "Desfazer uma volta" e "O botão não gira mais".
FORM: versão A (a voz guia) de 3 mostradas no chat em 11/10/2026; sem concept-seed: o dono pediu “me apresente 3 versões aqui no claude antes de executar no app”, e a escolha dele entre as 3 substituiu o sorteio.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
