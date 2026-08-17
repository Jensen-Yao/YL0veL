@echo off
REM 主人电脑侧：启动绑定 0.0.0.0 的 CosyVoice TTS 服务（供桃桃手机局域网调用）
REM 使用前请先看 D:\Desktop\模型管理\README-torch.md 与 local-models skill 说明

set VENV=D:\Desktop\模型管理\venv
set PY=%VENV%\Scripts\python.exe

echo [YL0veL] 正在检查 11436 端口服务...
powershell -NoProfile -Command "$c = Get-NetTCPConnection -LocalPort 11436 -State Listen -ErrorAction SilentlyContinue; if ($c) { exit 0 } else { exit 1 }"
if %ERRORLEVEL%==0 (
    echo [YL0veL] 服务已在运行（可能绑定 127.0.0.1，仅本机可用）。
    echo [YL0veL] 若要手机访问，请先停掉现有服务（任务管理器结束 python.exe 中带 watchdog_tts/tts_server 的进程），再运行本脚本。
    pause
    exit /b 0
)

echo [YL0veL] 启动局域网 TTS 服务（0.0.0.0:11436）...
REM 注意：防火墙需放行 11436 端口入站（首次运行时 Windows 可能弹窗询问，选“允许”）
start "YL0veL-TTS-LAN" /min cmd /c "%PY% -u -m uvicorn tts_server:app --host 0.0.0.0 --port 11436 --app-dir D:\Desktop\模型管理\service"

echo [YL0veL] 服务启动中，约 10~30 秒加载模型（首次请求时加载）。
echo [YL0veL] 手机 App 设置里的地址填：http://<本机局域网IP>:11436
echo [YL0veL] 查看本机 IP：运行 ipconfig 找 IPv4 地址（如 192.168.x.x）
pause
