# Pedais no Home Assistant da casa (painel da TV)

Pedido de 4/11/2026, vindo do projeto do Home Assistant. O painel 3D da casa (TV) ganhou uma
bolinha na bike do porão: tocando, aparecem Estéfano e Eduarda, e cada nome abre uma cópia da aba
Você (recordes, calendário e pedais). Cada pessoa usa o Pedalaqui no próprio celular, e o app manda
os pedais para o Home Assistant.

**Contrato** (formato do JSON e quando mandar): `C:\Projetos\Home Assistant\pedalaqui-ha.md`, no PC
de casa. O lado do Home Assistant (dois sensores por webhook, `sensor.pedalaqui_estefano` e
`sensor.pedalaqui_eduarda`) e o do painel já estavam prontos.

## Tarefas

- [x] **1. Montar o JSON** — `data/ha_retrato.dart`: `retratoHa()`/`corpoHa()` e `formaHa()`.
  Testes em `test/data/ha_retrato_test.dart`: formato e colunas, pedais do mais novo ao mais velho,
  arredondamentos, `voltas` só em volta fechada, nome pelo `rideName()`, rotas só as dos pedais,
  rota apagada, forma (até 24 pontos, 0–100, proporção, centralizada, y para o norte), limite de
  1500 pedais e 200 KB.
- [x] **2. Endereço nos Ajustes** — `AppSettings.haEndereco` (vazio = não manda); campo “Enviar
  para o Home Assistant” em Ajustes › Avançado, com o último envio e “Mandar agora”.
- [x] **3. Mandar** — `data/ha_envio.dart`: `HaEnvio` com `pedir()` (espera 2 s para juntar),
  `aoAbrir()` e `enviarAgora()`; um envio de cada vez; o estado fica em `files/ha_envio.json`
  (o banco não muda). Testes em `test/data/ha_envio_test.dart`.
- [x] **4. Quando** — ao terminar um pedal (e ao descartar um curto), ao apagar um pedal ou uma
  rota, ao mudar um ajuste e ao abrir o app.
- [x] **5. Android** — `res/xml/network_security_config.xml`: `http` liberado só para `192.168.3.70`.
- [x] **6. Tela** — `test/widget/casa_test.dart`: o campo, o “Mandar agora” e o envio ao abrir.
- [x] **7. No celular** — instalar, pôr o endereço, conferir o sensor no Home Assistant.
  Feito em 4/11 às 21h51 no celular de testes (cópia do banco antes; nenhum pedal em andamento):
  ao guardar o endereço do Estéfano o app mandou sozinho, e o “Mandar agora” mandou de novo
  (“Pedais mandados para o Home Assistant.”). `sensor.pedalaqui_estefano` = **27,87 km**, igual
  à soma do banco (6 pedais, 27 870 m), com nome, 75 kg, os 6 pedais e as 2 rotas desenhadas.
  O log do Home Assistant ficou sem avisos; o banco do celular ficou igual (6 pedais).

## Parte 2 — detalhe de cada pedal (5/11/2026)

Pedido novo: no painel, abrir um pedal do histórico e ver o mesmo que a tela do pedal do app (o
mapa pintado, o gráfico, as voltas e os números). Formato final em `pedalaqui-ha.md`, seção
“Detalhe de cada pedal”.

- [x] **8. Montar o detalhe** — `data/ha_detalhe.dart`: `detalheHa()`/`corpoDetalheHa()`: o topo
  da tela (`data/cabecalho_pedal.dart`, a mesma função da tela), os números, as métricas com a
  faixa de cores (percentis 5 e 95, como a tela), as voltas, o caminho e até 600 amostras já
  suavizadas, com `x`/`y` na mesma escala de 0 a 100 da forma das rotas (`ProjecaoHa`, tirada do
  `formaHa`). Abaixo de 60 KB. Testes em `test/data/ha_detalhe_test.dart`.
- [x] **9. 2.º endereço** — `AppSettings.haDetalheEndereco`; campo “Detalhe de cada pedal” em
  Ajustes › Avançado, com a situação embaixo (“Detalhe: tudo mandado…”).
- [x] **10. Mandar** — `HaEnvio.mandarDetalhes()`: depois de cada envio do resumo, um POST por
  pedal que ainda não foi (ou que mudou), do mais novo ao mais velho, com 0,5 s entre eles; para
  na 1.ª falha e continua na próxima vez. O que já foi fica em `files/ha_detalhe.json` (o banco
  não muda). Testes em `test/data/ha_envio_test.dart` e `test/widget/casa_test.dart`.
- [x] **11. No celular** — instalar, pôr o 2.º endereço, conferir os arquivos no Home Assistant.
  Feito em 5/11 às 20h37 (cópia do banco antes; nenhum pedal em andamento): ao guardar o endereço,
  os 6 pedais foram sozinhos e viraram 6 arquivos em `/config/www/casa/pedais/estefano/` (8 a 28 KB,
  com o `index.json`), iguais ao detalhe montado no PC a partir do banco do celular.
- [x] **12. Prints** da tela do pedal (os modos de cor e as voltas) em
  `C:\Projetos\Home Assistant\pedalaqui-prints\` (9 prints, 5/11 às 20h53). Comparando com a tela,
  os tempos iam arredondados para cima (1208 s em vez de 20:07): agora vão como o app escreve
  (`f628877`); os 6 detalhes foram de novo sozinhos ao abrir o app (20h59) e o sensor também.

**Paradas:** o app não guarda. As amostras só andam com a bike em movimento (1 por segundo de
tempo em movimento); parado, nada é gravado.

## Notas da execução

- **Manda só quando precisa:** guarda um resumo (endereço + JSON) do último envio certo. Ao abrir
  o app ou depois de um pedido, manda se o último falhou, se já faz 1 dia ou se algo mudou. Assim,
  mudar a meta semanal (que não vai no retrato) não manda nada, e um pedal cortado no meio (app
  fechado) chega na próxima abertura.
- **Falhou** (fora de casa, HA desligado, demorou mais de 10 s, resposta que não é 2xx, endereço
  sem `http`): só marca; a pessoa não recebe aviso. Nos Ajustes aparece “Não consegui mandar…”.
- **Rota apagada:** como no app, os pedais dela viram “Rota”, na primeira cor, com o desenho do
  próprio pedal; sem desenho, vão sem rota (o painel mostra o ícone).
- **Forma:** simplificada pondo, a cada passo, o ponto que mais foge do desenho, até 24 pontos ou
  até sobrar menos de meia unidade (some no arredondamento). Centralizada como o `TrackShapePainter`,
  porque o painel desenha os números como vêm.
- **Sem nome** nos Ajustes, o campo `nome` fica de fora (o HA usa o nome da pessoa).
- O endereço de cada celular não fica no código (o repositório é público): a pessoa cola nos Ajustes.
- Resultado: `flutter analyze` sem avisos, **426 testes passando** (eram 401).
