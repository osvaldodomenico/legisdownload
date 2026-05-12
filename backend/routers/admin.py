import os
import datetime
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import HTMLResponse

ADMIN_TOKEN = os.getenv("ADMIN_TOKEN", "shiftadmin123")
COOKIES_FILE = "/app/cookies/cookies.txt"

router = APIRouter()

_STYLE = """
<style>
  body{font-family:monospace;background:#0a0a0a;color:#e0e0e0;padding:40px;max-width:600px}
  h1{color:#f5a623;letter-spacing:2px;font-size:18px}
  h2{color:#00e5ff;font-size:13px;letter-spacing:1px}
  .ok{color:#00e5ff} .err{color:#ff4444}
  label{display:block;margin:12px 0 4px;color:#888;font-size:12px}
  input{background:#111;color:#e0e0e0;border:1px solid #333;padding:8px;width:100%;box-sizing:border-box}
  button{background:#f5a623;color:#000;border:none;padding:10px 28px;cursor:pointer;font-weight:700;margin-top:16px;letter-spacing:1px}
  a{color:#f5a623}
  .box{border:1px solid #222;padding:16px;margin:16px 0}
</style>
"""


@router.get("/admin/cookies", response_class=HTMLResponse)
async def admin_page():
    exists = os.path.isfile(COOKIES_FILE)
    if exists:
        mtime = datetime.datetime.fromtimestamp(
            os.path.getmtime(COOKIES_FILE)).strftime("%d/%m/%Y %H:%M")
        size_kb = os.path.getsize(COOKIES_FILE) // 1024
        status = f'<span class="ok">✓ cookies.txt ativo — {size_kb} KB — atualizado {mtime}</span>'
    else:
        status = '<span class="err">✗ Nenhum cookies.txt configurado (Instagram/TikTok/Facebook podem falhar)</span>'

    return f"""<!DOCTYPE html><html><head><title>ShiftDownloads Admin</title>{_STYLE}</head>
<body>
  <h1>SHiFT // DOWNLOADS</h1>
  <h2>PAINEL ADMIN — COOKIES</h2>
  <div class="box">{status}</div>

  <p style="color:#888;font-size:11px">
    Para baixar do Instagram/TikTok/Facebook, faça upload de um <code>cookies.txt</code>
    no formato Netscape exportado de uma conta logada
    (extensão <b>Get cookies.txt LOCALLY</b> no Chrome).
  </p>

  <form method="post" enctype="multipart/form-data">
    <label>TOKEN DE ADMIN</label>
    <input type="password" name="token" required placeholder="••••••••">
    <label>ARQUIVO cookies.txt</label>
    <input type="file" name="file" accept=".txt" required>
    <button type="submit">⬆ UPLOAD COOKIES</button>
  </form>
</body></html>"""


@router.post("/admin/cookies", response_class=HTMLResponse)
async def upload_cookies(token: str = Form(...), file: UploadFile = File(...)):
    if token != ADMIN_TOKEN:
        raise HTTPException(status_code=403, detail="Token inválido")

    os.makedirs(os.path.dirname(COOKIES_FILE), exist_ok=True)
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Arquivo vazio")

    with open(COOKIES_FILE, "wb") as f:
        f.write(content)

    size_kb = len(content) // 1024
    return f"""<!DOCTYPE html><html><head><title>ShiftDownloads Admin</title>{_STYLE}</head>
<body>
  <h1>SHiFT // DOWNLOADS</h1>
  <h2>PAINEL ADMIN — COOKIES</h2>
  <div class="box"><span class="ok">✓ cookies.txt atualizado — {size_kb} KB</span></div>
  <p><a href="/api/admin/cookies">← Voltar</a></p>
</body></html>"""
