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
- [ ] **7. No celular** — instalar, pôr o endereço, conferir o sensor no Home Assistant.

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
