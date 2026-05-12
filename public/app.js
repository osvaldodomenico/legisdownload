const state = {
  config: null,
  info: null,
  result: null
};

const form = document.querySelector("#download-form");
const urlInput = document.querySelector("#media-url");
const toolStatus = document.querySelector("#tool-status");
const analyzeButton = document.querySelector("#analyze-button");
const downloadButton = document.querySelector("#download-button");
const modeCards = [...document.querySelectorAll(".mode-card")];
const videoQualityField = document.querySelector("#video-quality-field");
const audioQualityField = document.querySelector("#audio-quality-field");
const videoQualitySelect = document.querySelector("#video-quality");
const audioQualitySelect = document.querySelector("#audio-quality");
const previewEmpty = document.querySelector("#preview-empty");
const previewContent = document.querySelector("#preview-content");
const previewThumb = document.querySelector("#preview-thumb");
const previewPlatform = document.querySelector("#preview-platform");
const previewTitle = document.querySelector("#preview-title");
const previewUploader = document.querySelector("#preview-uploader");
const previewDuration = document.querySelector("#preview-duration");
const resultEmpty = document.querySelector("#result-empty");
const resultContent = document.querySelector("#result-content");
const resultName = document.querySelector("#result-name");
const resultLink = document.querySelector("#result-link");
const copyLinkButton = document.querySelector("#copy-link-button");
const webShareButton = document.querySelector("#web-share-button");
const whatsappShare = document.querySelector("#whatsapp-share");
const telegramShare = document.querySelector("#telegram-share");
const telegramUploadButton = document.querySelector("#telegram-upload-button");
const toast = document.querySelector("#toast");

function getSelectedMode() {
  return form.elements.mode.value;
}

function setLoading(button, loading, label) {
  button.disabled = loading;
  button.dataset.originalLabel = button.dataset.originalLabel || button.textContent;
  button.textContent = loading ? label : button.dataset.originalLabel;
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.remove("hidden");
  window.clearTimeout(showToast.timeoutId);
  showToast.timeoutId = window.setTimeout(() => {
    toast.classList.add("hidden");
  }, 3200);
}

function setStatus(message, tone = "default") {
  toolStatus.textContent = message;
  toolStatus.dataset.tone = tone;
}

function updateModeUI() {
  const mode = getSelectedMode();
  modeCards.forEach((card) => {
    const input = card.querySelector("input");
    card.classList.toggle("active", input.checked);
  });
  videoQualityField.classList.toggle("hidden", mode !== "video");
  audioQualityField.classList.toggle("hidden", mode !== "audio");
}

function humanFileSize(sizeBytes) {
  if (!sizeBytes) {
    return "";
  }
  const mb = sizeBytes / 1024 / 1024;
  return `${mb.toFixed(1)} MB`;
}

function buildPublicUrl(relativeUrl) {
  if (typeof window !== "undefined" && window.location?.origin) {
    return new URL(relativeUrl, window.location.origin).toString();
  }

  if (!state.config) {
    return relativeUrl;
  }

  const base = state.config.accessUrls[0];
  return new URL(relativeUrl, base).toString();
}

function populateVideoFormats(formats) {
  videoQualitySelect.innerHTML = "";
  if (!formats.length) {
    const option = document.createElement("option");
    option.value = "";
    option.textContent = "Nenhuma qualidade disponivel para esta midia";
    videoQualitySelect.append(option);
    return;
  }

  const autoOption = document.createElement("option");
  autoOption.value = "";
  autoOption.textContent = "Automatico - melhor opcao compativel";
  videoQualitySelect.append(autoOption);

  formats.forEach((format) => {
    const option = document.createElement("option");
    option.value = format.id;
    option.textContent = format.label;
    videoQualitySelect.append(option);
  });
}

function renderPreview(info) {
  state.info = info;
  previewThumb.src = info.thumbnail || "";
  previewThumb.alt = info.title || "Thumbnail";
  previewPlatform.textContent = info.extractor;
  previewTitle.textContent = info.title;
  previewUploader.textContent = info.uploader ? `Canal/perfil: ${info.uploader}` : "";
  previewDuration.textContent = info.duration ? `Duracao: ${info.duration}` : "";
  populateVideoFormats(info.formats || []);
  previewEmpty.classList.add("hidden");
  previewContent.classList.remove("hidden");
}

function renderResult(result) {
  state.result = result;
  const publicUrl = buildPublicUrl(result.fileUrl);
  const shareText = encodeURIComponent(`Arquivo pronto para baixar: ${publicUrl}`);
  resultName.textContent = `${result.fileName}${result.sizeBytes ? ` • ${humanFileSize(result.sizeBytes)}` : ""}`;
  resultLink.href = publicUrl;
  resultLink.download = result.fileName;
  whatsappShare.href = `https://wa.me/?text=${shareText}`;
  telegramShare.href = `https://t.me/share/url?url=${encodeURIComponent(publicUrl)}&text=${encodeURIComponent("Arquivo pronto para baixar")}`;
  resultEmpty.classList.add("hidden");
  resultContent.classList.remove("hidden");
  telegramUploadButton.classList.toggle("hidden", !state.config?.tools?.telegramEnabled);
}

async function requestJson(url, payload) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || "Falha na requisicao.");
  }
  return data;
}

async function analyzeLink() {
  const mediaUrl = urlInput.value.trim();
  if (!mediaUrl) {
    showToast("Cole um link antes de analisar.");
    return;
  }

  setLoading(analyzeButton, true, "Analisando...");
  setStatus("Buscando informacoes e qualidades disponiveis...");

  try {
    const data = await requestJson("/api/info", { url: mediaUrl });
    renderPreview(data.info);
    setStatus("Link analisado com sucesso.", "success");
  } catch (error) {
    setStatus(error.message, "error");
    showToast(error.message);
  } finally {
    setLoading(analyzeButton, false);
  }
}

async function handleDownload(event) {
  event.preventDefault();
  const mediaUrl = urlInput.value.trim();
  if (!mediaUrl) {
    showToast("Cole um link antes de baixar.");
    return;
  }

  const mode = getSelectedMode();
  const payload = {
    url: mediaUrl,
    mode,
    formatId: mode === "video" ? videoQualitySelect.value : "",
    audioPreset: mode === "audio" ? audioQualitySelect.value : ""
  };

  setLoading(downloadButton, true, "Baixando...");
  setStatus("Download em andamento. Isso pode levar alguns instantes...");

  try {
    const data = await requestJson("/api/download", payload);
    renderResult(data);
    setStatus("Arquivo pronto para baixar e compartilhar.", "success");
    showToast("Download concluido.");
  } catch (error) {
    setStatus(error.message, "error");
    showToast(error.message);
  } finally {
    setLoading(downloadButton, false);
  }
}

async function loadConfig() {
  const response = await fetch("/api/config");
  state.config = await response.json();

  const messages = [];
  if (!state.config.tools.ytDlp) {
    messages.push("yt-dlp nao encontrado");
  }
  if (!state.config.tools.ffmpeg) {
    messages.push("ffmpeg nao encontrado");
  }

  if (messages.length) {
    setStatus(`Ajuste necessario: ${messages.join(" | ")}. Veja o README para instalar.`, "error");
  } else {
    setStatus("Tudo pronto para analisar links e baixar arquivos.", "success");
  }
}

async function copyResultLink() {
  if (!state.result) {
    return;
  }

  const publicUrl = buildPublicUrl(state.result.fileUrl);
  await navigator.clipboard.writeText(publicUrl);
  showToast("Link copiado.");
}

async function shareResult() {
  if (!state.result) {
    return;
  }

  const publicUrl = buildPublicUrl(state.result.fileUrl);
  if (navigator.share) {
    await navigator.share({
      title: "ShiftDownloads",
      text: "Arquivo pronto para baixar",
      url: publicUrl
    });
    return;
  }

  showToast("Seu navegador nao suporta compartilhamento nativo.");
}

async function uploadToTelegram() {
  if (!state.result) {
    return;
  }

  telegramUploadButton.disabled = true;
  telegramUploadButton.textContent = "Enviando...";

  try {
    await requestJson("/api/share/telegram", {
      fileName: state.result.fileName,
      caption: "Arquivo enviado pelo ShiftDownloads"
    });
    showToast("Arquivo enviado para o Telegram.");
  } catch (error) {
    showToast(error.message);
  } finally {
    telegramUploadButton.disabled = false;
    telegramUploadButton.textContent = "Enviar arquivo via bot do Telegram";
  }
}

modeCards.forEach((card) => {
  card.addEventListener("click", () => {
    const input = card.querySelector("input");
    input.checked = true;
    updateModeUI();
  });
});

analyzeButton.addEventListener("click", analyzeLink);
form.addEventListener("submit", handleDownload);
copyLinkButton.addEventListener("click", copyResultLink);
webShareButton.addEventListener("click", shareResult);
telegramUploadButton.addEventListener("click", uploadToTelegram);

loadConfig().catch((error) => {
  setStatus(error.message, "error");
});
updateModeUI();
