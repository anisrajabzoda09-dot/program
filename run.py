import uvicorn
import os
import socket

def find_available_port(default_port=8080):
    for port in [default_port, 8000, 8081, 8888, 5000]:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('0.0.0.0', port))
                return port
            except OSError:
                continue
    return default_port

if __name__ == "__main__":
    port_env = os.environ.get("PORT")
    port = int(port_env) if port_env else find_available_port(8080)
    print("==================================================")
    print(" Оғози сервери «Нигоҳ — Parental Control» (FastAPI)")
    print(f" Сервер дар суроғаи зер дастрас аст:")
    print(f" 👉 http://localhost:{port}")
    print(f" 🎮 Нигоҳ 3D: http://localhost:{port}/3d")
    print(f" 🌐 WeEvolveIT: http://localhost:{port}/weevolve")
    print(f" 📱 Версияи мобилӣ: http://localhost:{port}/mobile")
    print("==================================================")
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
