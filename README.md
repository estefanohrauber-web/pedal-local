# Pedal Local (protótipo)

Pedale, numa bicicleta ergométrica em casa, uma rota real do seu bairro. O app lê a
bike pelo Bluetooth (padrão FTMS), traça a rota pelas ruas, puxa a altimetria e
simula subidas e descidas na velocidade virtual.

## Rodar no computador

    node serve.js

Abra http://localhost:8080 no Chrome. Sem bike, use “Usar bike simulada”.

## Testes

    node --test

## Usar no celular

O Bluetooth no navegador só funciona em endereço `https` (ou `localhost`).
Para o celular, publique a pasta (por exemplo no GitHub Pages) e abra o link
no Chrome do Android.

## Serviços usados

- Mapa: OpenStreetMap
- Rotas: OSRM (routing.openstreetmap.de, perfil bicicleta)
- Altimetria: Open-Meteo Elevation API

O app Flutter (pasta `app/`) usa o Valhalla, nos servidores da FOSSGIS, para rotas e
altitude (veja `docs/superpowers/specs/2026-10-07-app-flutter-fase1-design.md`).
