# Editor de treinos — plano (registro da execução)

Desenho: `docs/superpowers/specs/2026-10-09-editor-de-treinos-design.md`.
Executado direto com TDD (sem código no plano antes), como nos planos anteriores, a pedido do
usuário.

**Objetivo:** o usuário monta, edita, copia e apaga treinos com blocos prontos no celular, e ajusta
qualquer treino durante o pedal (pular, +1 min, ±5 %).

**Arquitetura:** os blocos (`WorkoutBlock`) são o que se guarda e se edita; na hora de mostrar e
pedalar, viram os trechos de sempre (`WorkoutStep`), então o desenho, a tela do treino, o condutor
(`WorkoutRunner`), a voz e o modo ERG continuam os mesmos. Treinos do usuário ficam numa tabela
nova; `findWorkoutProvider` acha qualquer treino (biblioteca ou do usuário) pelo id.

## Tarefas

- [ ] **1. Domínio dos blocos** — `lib/domain/workout_blocks.dart` (novo), `lib/domain/workout.dart`.
  - `WorkoutStep.free` (pedal livre) e `withSeconds`; `Workout.withSteps`.
  - `BlockKind` (7 tipos), títulos e explicações; `WorkoutBlock` com `novo(kind)` (valores do
    desenho), `copyWith`, `totalSeconds`, `toSteps` (série → “Tiro 3 de 4[. frase]” + descanso
    “Recupere”; livre → trecho `free` a 50 %), JSON.
  - `CustomWorkout` (id `meu-…`, nome, blocos, datas) → `toWorkout()` na categoria “Meus treinos”;
    linha do banco.
  - `blocksFromSteps` (copiar treino pronto: aquecer, séries de pares repetidos sem giro no
    descanso, subida, rampa, soltar, ritmo); limites e ajudas (`zoneTargets`, `moreTime`/`lessTime`,
    `clampFraction`, `workoutProblem`, `workoutNameOrDefault`, `insertIndex`, `moveBlock`);
    `describeBlock` e `blockHeading` para os cartões.
  - Testes: `test/domain/workout_blocks_test.dart` (cada bloco → trechos, série com frase, números,
    livre como muito leve, JSON ida e volta, cópia de toda a biblioteca com o mesmo desenho, tipos
    reconhecidos na cópia, limites, resumos em palavras).
- [ ] **2. Condutor do treino** — `lib/domain/workout_runner.dart`.
  - Pedal livre: meta 0, sem “fora da meta”, voz “1 minuto de pedal livre, no seu ritmo.”.
  - `skipStep`, `extendStep` (até +30 min por trecho), `nudge(±1)` (5 %, de −30 % a +30 %), com a
    voz confirmando; `workout` passa a refletir o +1 min; `WorkoutFrame.adjustment`.
  - Nada disso no Teste de rampa.
  - Testes em `test/domain/workout_runner_test.dart`.
- [ ] **3. Dados** — `lib/data/db/app_database.dart` (versão 7), `lib/data/custom_workouts_store.dart`
  (novo: SQLite e memória), `lib/data/rides_store.dart` (`workoutName`), `lib/data/providers.dart`,
  `lib/features/pedal/ride_controller.dart` (`findWorkoutProvider`).
  - Tabela `custom_workouts`; coluna `workout_name` nos pedais; migração da 6 para a 7.
  - `rideName` usa o nome guardado antes de procurar na biblioteca.
  - Testes: `test/data/custom_workouts_store_test.dart` (salvar, listar, apagar, migração 6 → 7,
    `findWorkoutProvider`), `test/data/rides_store_test.dart` (nome do treino no pedal).
- [ ] **4. Pedal do treino** — `lib/features/pedal/ride_controller.dart`.
  - Acha treinos do usuário (espera eles carregarem); guarda `workoutName`.
  - `skipStep`, `extendStep`, `nudge` repassam ao condutor, falam e mandam a meta nova para a bike
    na hora (mesmo abaixo de 5 W de diferença); no pedal livre, a carga volta para a bike.
  - Testes em `test/features/ride_controller_test.dart`.
- [ ] **5. Telas do pedal** — `lib/features/treinos/treino_pedal_screen.dart`, `workout_chart.dart`,
  `treino_screen.dart` (linhas dos trechos).
  - Botões Pular bloco, +1 min, Mais leve −5 %, Mais forte +5 % (os dois últimos somem no pedal
    livre; nada no Teste de rampa); “Pedal livre / Sem meta” no trecho livre; “Metas +5 % neste
    pedal”; “Depois: … pedal livre”; barra cinza clara no desenho.
  - Teste de tela em `test/widget/treinos_test.dart`.
- [ ] **6. Editor** — `lib/features/treinos/editor_treino_screen.dart` e `bloco_sheet.dart` (novos),
  rotas `/treino-novo[?de=id]` e `/treino-editar/:id`.
  - Nome, desenho e números ao vivo; lista com segurar e arrastar; menu Duplicar/Apagar; “Adicionar
    bloco” (entra antes do Soltar e já abre os ajustes); Salvar com validação; sair com mudanças
    pergunta.
  - Ajustes do bloco: tempo (− e +, segurar repete), intensidade em palavras + ajuste fino com
    watts, giro (Livre, Pesado, Normal, Rápido, Outro), inclinação, série (repetições, tiro,
    descanso), frase da voz; “Pronto”.
- [ ] **7. Treinos e tela do treino** — `treinos_screen.dart` (“Meus treinos” e “Criar treino”),
  `treino_screen.dart` (Copiar e editar; Editar, Duplicar, Apagar com confirmação).
  - Testes de tela em `test/widget/treinos_test.dart`: criar do zero e salvar; copiar da biblioteca
    e mudar um bloco; sair sem salvar; apagar; o treino montado começa no pedal com o nome certo.
  - Todos os testes de tela passam a sobrescrever `customWorkoutsStoreProvider` com o de memória.
- [ ] **8. No celular e registro** — instalar, conferir as telas em fotos, migração 6 → 7 com as
  rotas e pedais do usuário intactos; notas aqui; ajuste no desenho (a série gera as frases
  “Tiro 3 de 4” em vez de um campo novo no trecho); commit e push.

## Notas da execução
