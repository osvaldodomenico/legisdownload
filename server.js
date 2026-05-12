const http = require("http");
const fs = require("fs");
const fsp = require("fs/promises");
const path = require("path");
const os = require("os");
const { spawn } = require("child_process");

const HOST = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.PORT || 3000);
const ROOT_DIR = __dirname;
const PUBLIC_DIR = path.join(ROOT_DIR, "public");
const DOWNLOADS_DIR = path.join(ROOT_DIR, "downloads");
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "";
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || "";
const BIN_CANDIDATES = {
  "yt-dlp": ["yt-dlp", "/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"],
  "ffmpeg": ["ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
};

for (const dir of [PUBLIC_DIR, DOWNLOADS_DIR]) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

async function resolveBinary(command) {
  const candidates = BIN_CANDIDATES[command] || [command];

  for (const candidate of candidates) {
    if (candidate.startsWith("/") && fs.existsSync(candidate)) {
      return candidate;
    }

    const exists = await new Promise((resolve) => {
      const child = spawn(candidate, ["--version"]);
      child.on("error", () => resolve(false));
      child.on("exit", (code) => resolve(code === 0));
    });

    if (exists) {
      return candidate;
    }
  }

  return null;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1024 * 1024) {
        reject(new Error("Corpo da requisicao muito grande."));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!raw) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(new Error("JSON invalido."));
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res, status, payload) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  });
  res.end(JSON.stringify(payload));
}

function sendText(res, status, text) {
  res.writeHead(status, {
    "Content-Type": "text/plain; charset=utf-8",
    "Cache-Control": "no-store"
  });
  res.end(text);
}

function mimeType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const map = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".mp3": "audio/mpeg",
    ".m4a": "audio/mp4"
  };

  return map[ext] || "application/octet-stream";
}

function sanitizeRelativePath(relativePath) {
  const normalized = path.normalize(relativePath).replace(/^(\.\.(\/|\\|$))+/, "");
  return normalized;
}

function getNetworkAddresses() {
  const urls = [];
  const interfaces = os.networkInterfaces();

  Object.values(interfaces).forEach((entries) => {
    (entries || []).forEach((entry) => {
      if (entry && entry.family === "IPv4" && !entry.internal) {
        urls.push(`http://${entry.address}:${PORT}`);
      }
    });
  });

  return Array.from(new Set([`http://localhost:${PORT}`, ...urls]));
}

function formatDuration(seconds) {
  if (!seconds || Number.isNaN(Number(seconds))) {
    return "";
  }

  const total = Number(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = Math.floor(total % 60);

  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  }

  return `${minutes}:${String(secs).padStart(2, "0")}`;
}

function sortFormats(formats) {
  return formats.sort((a, b) => {
    const heightDiff = (b.height || 0) - (a.height || 0);
    if (heightDiff !== 0) {
      return heightDiff;
    }

    const fpsDiff = (b.fps || 0) - (a.fps || 0);
    if (fpsDiff !== 0) {
      return fpsDiff;
    }

    return (b.tbr || 0) - (a.tbr || 0);
  });
}

function getSelectableFormats(formats, hasFfmpeg) {
  const selected = formats
    .filter((format) => format.vcodec && format.vcodec !== "none")
    .filter((format) => Boolean(format.ext))
    .filter((format) => hasFfmpeg || (format.acodec && format.acodec !== "none"))
    .map((format) => {
      const qualityLabel = format.format_note || format.resolution || (format.height ? `${format.height}p` : format.ext);
      const audioLabel = format.acodec && format.acodec !== "none" ? "com audio" : "video sem audio";
      const size = format.filesize || format.filesize_approx || 0;
      const sizeMb = size ? `${(size / 1024 / 1024).toFixed(1)} MB` : "tamanho desconhecido";

      return {
        id: format.format_id,
        ext: format.ext,
        height: format.height || 0,
        fps: format.fps || 0,
        needsMerge: !format.acodec || format.acodec === "none",
        label: `${qualityLabel} • ${format.ext.toUpperCase()} • ${audioLabel} • ${sizeMb}`
      };
    });

  const deduped = [];
  const seen = new Set();
  for (const item of sortFormats(selected)) {
    const key = `${item.id}:${item.ext}`;
    if (!seen.has(key)) {
      seen.add(key);
      deduped.push(item);
    }
  }

  return deduped;
}

function runCommand(command, args) {
  return new Promise((resolve, reject) => {
    let stdout = "";
    let stderr = "";
    const child = spawn(command, args, { cwd: ROOT_DIR });

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", reject);

    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr.trim() || stdout.trim() || `Falha ao executar ${command}.`));
        return;
      }

      resolve({ stdout, stderr });
    });
  });
}

async function getMediaInfo(mediaUrl, hasFfmpeg, ytDlpBinary) {
  const { stdout } = await runCommand(ytDlpBinary, [
    "--dump-single-json",
    "--no-playlist",
    "--skip-download",
    mediaUrl
  ]);

  const data = JSON.parse(stdout);
  return {
    id: data.id,
    title: data.title,
    webpageUrl: data.webpage_url || mediaUrl,
    extractor: data.extractor_key || data.extractor || "Midia",
    uploader: data.uploader || data.channel || "",
    duration: formatDuration(data.duration),
    thumbnail: data.thumbnail || "",
    description: data.description || "",
    formats: getSelectableFormats(data.formats || [], hasFfmpeg)
  };
}

async function findDownloadedFile(token) {
  const entries = await fsp.readdir(DOWNLOADS_DIR);
  const match = entries.find((entry) => entry.startsWith(token));
  if (!match) {
    throw new Error("Download concluido, mas nao foi possivel localizar o arquivo.");
  }
  return match;
}

function createOutputToken() {
  return `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

async function downloadMedia({
  mediaUrl,
  mode,
  formatId,
  audioPreset,
  hasFfmpeg,
  ytDlpBinary
}) {
  const token = createOutputToken();
  const outputTemplate = path.join(DOWNLOADS_DIR, `${token}_%(title).120B [%(id)s].%(ext)s`);
  const args = ["--no-playlist", "--restrict-filenames", "-o", outputTemplate];

  if (mode === "audio") {
    if (!hasFfmpeg) {
      throw new Error("Para gerar MP3, instale o ffmpeg no sistema.");
    }

    const presetMap = {
      best: "0",
      balanced: "5",
      compact: "7"
    };

    args.push("-x", "--audio-format", "mp3", "--audio-quality", presetMap[audioPreset] || presetMap.best);
  } else {
    const fallbackFormat = hasFfmpeg ? "bestvideo*+bestaudio/best" : "best[acodec!=none][vcodec!=none]/best";
    args.push("-f", formatId || fallbackFormat);

    if (hasFfmpeg) {
      args.push("--merge-output-format", "mp4");
    }
  }

  args.push(mediaUrl);
  await runCommand(ytDlpBinary, args);

  const fileName = await findDownloadedFile(token);
  const stats = await fsp.stat(path.join(DOWNLOADS_DIR, fileName));
  return {
    fileName,
    sizeBytes: stats.size
  };
}

async function sendTelegramFile(fileName, caption) {
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
    throw new Error("Configure TELEGRAM_BOT_TOKEN e TELEGRAM_CHAT_ID para usar o envio por Telegram.");
  }

  const filePath = path.join(DOWNLOADS_DIR, fileName);
  await fsp.access(filePath);
  const buffer = await fsp.readFile(filePath);
  const form = new FormData();
  form.set("chat_id", TELEGRAM_CHAT_ID);
  form.set("caption", caption || "Arquivo enviado pelo ShiftDownloads");
  form.set("document", new Blob([buffer]), fileName);

  const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument`, {
    method: "POST",
    body: form
  });

  const payload = await response.json();
  if (!response.ok || !payload.ok) {
    throw new Error(payload.description || "Falha ao enviar o arquivo para o Telegram.");
  }

  return payload;
}

async function serveStatic(req, res, pathname) {
  const decodedPath = decodeURIComponent(pathname);
  const target = decodedPath === "/" ? "index.html" : sanitizeRelativePath(decodedPath.slice(1));
  const filePath = path.join(PUBLIC_DIR, target);

  if (!filePath.startsWith(PUBLIC_DIR)) {
    sendText(res, 403, "Acesso negado.");
    return;
  }

  try {
    const data = await fsp.readFile(filePath);
    res.writeHead(200, {
      "Content-Type": mimeType(filePath),
      "Cache-Control": "no-store"
    });
    res.end(data);
  } catch (error) {
    sendText(res, 404, "Arquivo nao encontrado.");
  }
}

async function serveDownload(res, pathname) {
  const relativePath = sanitizeRelativePath(decodeURIComponent(pathname).replace(/^\/downloads\//, ""));
  const filePath = path.join(DOWNLOADS_DIR, relativePath);

  if (!filePath.startsWith(DOWNLOADS_DIR)) {
    sendText(res, 403, "Acesso negado.");
    return;
  }

  try {
    const stat = await fsp.stat(filePath);
    if (!stat.isFile()) {
      throw new Error("Nao e arquivo");
    }

    res.writeHead(200, {
      "Content-Type": mimeType(filePath),
      "Content-Length": stat.size,
      "Content-Disposition": `attachment; filename="${path.basename(filePath)}"`,
      "Cache-Control": "no-store"
    });

    fs.createReadStream(filePath).pipe(res);
  } catch (error) {
    sendText(res, 404, "Arquivo nao encontrado.");
  }
}

async function createServer() {
  const ytDlpBinary = await resolveBinary("yt-dlp");
  const ffmpegBinary = await resolveBinary("ffmpeg");
  const hasYtDlp = Boolean(ytDlpBinary);
  const hasFfmpeg = Boolean(ffmpegBinary);

  const server = http.createServer(async (req, res) => {
    const requestUrl = new URL(req.url, `http://${req.headers.host || `localhost:${PORT}`}`);
    const { pathname } = requestUrl;

    try {
      if (req.method === "GET" && pathname === "/api/config") {
        sendJson(res, 200, {
          host: HOST,
          port: PORT,
          tools: {
            ytDlp: hasYtDlp,
            ffmpeg: hasFfmpeg,
            telegramEnabled: Boolean(TELEGRAM_BOT_TOKEN && TELEGRAM_CHAT_ID)
          },
          accessUrls: getNetworkAddresses()
        });
        return;
      }

      if (req.method === "POST" && pathname === "/api/info") {
        if (!hasYtDlp) {
          sendJson(res, 400, {
            error: "Instale o yt-dlp para analisar links e iniciar downloads."
          });
          return;
        }

        const body = await readBody(req);
        if (!body.url) {
          sendJson(res, 400, { error: "Informe um link valido." });
          return;
        }

        const info = await getMediaInfo(body.url, hasFfmpeg, ytDlpBinary);
        sendJson(res, 200, { info });
        return;
      }

      if (req.method === "POST" && pathname === "/api/download") {
        if (!hasYtDlp) {
          sendJson(res, 400, {
            error: "Instale o yt-dlp para liberar o download."
          });
          return;
        }

        const body = await readBody(req);
        if (!body.url) {
          sendJson(res, 400, { error: "Informe um link valido." });
          return;
        }

        const mode = body.mode === "audio" ? "audio" : "video";
        const result = await downloadMedia({
          mediaUrl: body.url,
          mode,
          formatId: body.formatId,
          audioPreset: body.audioPreset,
          hasFfmpeg,
          ytDlpBinary
        });

        sendJson(res, 200, {
          fileName: result.fileName,
          fileUrl: `/downloads/${encodeURIComponent(result.fileName)}`,
          sizeBytes: result.sizeBytes
        });
        return;
      }

      if (req.method === "POST" && pathname === "/api/share/telegram") {
        const body = await readBody(req);
        if (!body.fileName) {
          sendJson(res, 400, { error: "Arquivo nao informado." });
          return;
        }

        await sendTelegramFile(body.fileName, body.caption);
        sendJson(res, 200, { success: true });
        return;
      }

      if (req.method === "GET" && pathname.startsWith("/downloads/")) {
        await serveDownload(res, pathname);
        return;
      }

      if (req.method === "GET") {
        await serveStatic(req, res, pathname);
        return;
      }

      sendText(res, 405, "Metodo nao permitido.");
    } catch (error) {
      sendJson(res, 500, {
        error: error.message || "Erro interno no servidor."
      });
    }
  });

  server.listen(PORT, HOST, () => {
    console.log(`ShiftDownloads online em http://localhost:${PORT}`);
    console.log(`Acessos na rede local: ${getNetworkAddresses().join(" | ")}`);
    console.log(`yt-dlp: ${hasYtDlp ? "ok" : "nao encontrado"} | ffmpeg: ${hasFfmpeg ? "ok" : "nao encontrado"}`);
  });
}

createServer().catch((error) => {
  console.error(error);
  process.exit(1);
});
