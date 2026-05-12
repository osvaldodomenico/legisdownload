# ShiftDownloads

Projeto web responsivo para baixar conteudos de links do YouTube, Instagram e TikTok com:

- download em video com selecao de qualidade
- opcao de extrair somente MP3
- interface limpa para desktop e mobile
- link direto para compartilhar no WhatsApp e Telegram
- envio opcional do arquivo para Telegram via bot

Use apenas para conteudos proprios, publicos ou com permissao de uso.

## Requisitos

- Node.js 18+ (ja compativel com o ambiente atual)
- `yt-dlp`
- `ffmpeg` para:
  - extrair MP3
  - mesclar video de alta qualidade quando audio e video vierem separados

### Instalacao no macOS com Homebrew

```bash
brew install yt-dlp ffmpeg
```

## Como rodar

```bash
npm start
```

A aplicacao sobe em `http://localhost:3000`.

## Compartilhamento

O servidor tambem mostra URLs da rede local no terminal. Isso permite:

- abrir o projeto no celular
- compartilhar o link direto do arquivo no WhatsApp
- compartilhar o link no Telegram

### Envio real do arquivo para Telegram

Se quiser mandar o arquivo diretamente para um chat do Telegram, configure:

```bash
export TELEGRAM_BOT_TOKEN="seu_token"
export TELEGRAM_CHAT_ID="seu_chat_id"
npm start
```

## Estrutura

- `server.js`: backend HTTP com APIs de analise, download e compartilhamento
- `public/index.html`: interface principal
- `public/styles.css`: visual responsivo
- `public/app.js`: logica do frontend

## Observacoes

- sem `yt-dlp`, a interface abre mas a analise e o download ficam bloqueados
- sem `ffmpeg`, video ainda pode funcionar em formatos que ja venham com audio, mas MP3 fica indisponivel
