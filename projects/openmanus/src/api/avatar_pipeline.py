"""Avatar Conversacional KlawAqua-AGI
Pipeline: Conversación → TTS → Lip-Sync → Video Avatar
Integrado en OpenManus via /avatar/speak"""
import subprocess, os, json, time, tempfile
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/avatar", tags=["avatar"])

AVATARS_DIR = "/opt/klawaqua/projects/klawaqua-avatar/avatars"
VOICES_DIR = "/opt/klawaqua/projects/klawaqua-avatar/voices"
OUTPUTS_DIR = "/opt/klawaqua/projects/klawaqua-avatar/outputs"
os.makedirs(OUTPUTS_DIR, exist_ok=True)

class SpeakRequest(BaseModel):
    text: str
    avatar: str = "default"  # nombre del archivo avatar (sin extension)
    voice: str = "es-ES-ElviraNeural"
    method: str = "ffmpeg"   # ffmpeg, sadtalker, wav2lip

class AvatarResponse(BaseModel):
    status: str
    video_path: str
    audio_path: str
    duration_s: float
    method: str


def find_avatar(avatar_name: str) -> str:
    """Busca el archivo de avatar por nombre"""
    # Buscar en avatars/
    for ext in ['.png', '.jpg', '.jpeg', '.webp']:
        path = os.path.join(AVATARS_DIR, f"{avatar_name}{ext}")
        if os.path.exists(path):
            return path
    
    # Si es "default", usar el primer avatar disponible
    if avatar_name == "default":
        for f in sorted(os.listdir(AVATARS_DIR)):
            if f.endswith(('.png', '.jpg', '.jpeg')):
                return os.path.join(AVATARS_DIR, f)
    
    raise FileNotFoundError(f"Avatar '{avatar_name}' no encontrado. Avatares disponibles: {os.listdir(AVATARS_DIR)}")


def generate_tts(text: str, voice: str, output_path: str) -> float:
    """Genera audio con Edge TTS. Retorna duración en segundos."""
    cmd = [
        "edge-tts", "--text", text, "--voice", voice,
        "--rate", "-5%", "--write-media", output_path
    ]
    subprocess.run(cmd, capture_output=True, text=True, timeout=60, check=True)
    
    # Obtener duración
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", output_path],
        capture_output=True, text=True, timeout=10
    )
    return float(result.stdout.strip())


def generate_ffmpeg_avatar(image_path: str, audio_path: str, output_path: str, duration: float):
    """Genera video cinemático con Ken Burns + audio (zero-cost, sin lip-sync real)"""
    frames = int(duration * 25)
    
    # Video cinemático con efecto Ken Burns (zoom suave)
    vf = (
        f"zoompan=z='min(zoom+0.0015,1.08)':d={frames}:"
        f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720,"
        f"eq=contrast=1.1:saturation=1.2:brightness=0.05,fps=25"
    )
    
    # Generar video
    subprocess.run([
        "ffmpeg", "-y", "-loop", "1", "-i", image_path,
        "-vf", vf,
        "-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p",
        "-t", str(duration), "-an", output_path
    ], capture_output=True, text=True, timeout=120, check=True)
    
    # Combinar con audio
    final_path = output_path.replace(".mp4", "_final.mp4")
    subprocess.run([
        "ffmpeg", "-y", "-i", output_path, "-i", audio_path,
        "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
        "-shortest", final_path
    ], capture_output=True, text=True, timeout=60, check=True)
    
    return final_path


@router.post("/speak", response_model=AvatarResponse)
async def avatar_speak(request: SpeakRequest):
    """Genera video del avatar hablando con el texto dado"""
    try:
        # 1. Encontrar avatar
        avatar_path = find_avatar(request.avatar)
        
        # 2. Generar TTS
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        audio_path = os.path.join(OUTPUTS_DIR, f"tts_{timestamp}.mp3")
        duration = generate_tts(request.text, request.voice, audio_path)
        
        # 3. Generar video avatar
        video_base = os.path.join(OUTPUTS_DIR, f"avatar_{timestamp}")
        
        if request.method == "ffmpeg":
            video_tmp = os.path.join(OUTPUTS_DIR, f"cinematic_{timestamp}.mp4")
            video_path = generate_ffmpeg_avatar(avatar_path, audio_path, video_tmp, duration)
        else:
            raise HTTPException(status_code=400, detail=f"Método no implementado: {request.method}")
        
        return AvatarResponse(
            status="ok",
            video_path=video_path,
            audio_path=audio_path,
            duration_s=round(duration, 1),
            method=request.method
        )
        
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error en pipeline: {e.stderr[:300] if hasattr(e, 'stderr') else str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/avatars")
async def list_avatars():
    """Lista avatares disponibles"""
    avatars = []
    for f in sorted(os.listdir(AVATARS_DIR)):
        if f.endswith(('.png', '.jpg', '.jpeg')):
            fp = os.path.join(AVATARS_DIR, f)
            avatars.append({
                "name": os.path.splitext(f)[0],
                "path": fp,
                "size_kb": round(os.path.getsize(fp) / 1024, 1)
            })
    return {"avatars": avatars, "count": len(avatars), "dir": AVATARS_DIR}


@router.get("/health")
async def avatar_health():
    """Verifica que el pipeline de avatar está listo"""
    checks = {}
    
    # Verificar edge-tts
    try:
        subprocess.run(["edge-tts", "--version"], capture_output=True, timeout=5, check=True)
        checks["edge-tts"] = "ok"
    except:
        checks["edge-tts"] = "missing"
    
    # Verificar ffmpeg
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, timeout=5, check=True)
        checks["ffmpeg"] = "ok"
    except:
        checks["ffmpeg"] = "missing"
    
    # Contar avatares
    checks["avatars_count"] = len([f for f in os.listdir(AVATARS_DIR) if f.endswith(('.png', '.jpg'))])
    
    # Verificar Waifu Diffusion
    wf_dir = "/opt/klawaqua/models/waifu-diffusion"
    checks["waifu_diffusion"] = "ready" if os.path.exists(os.path.join(wf_dir, "model_index.json")) else "pending"
    
    return {"status": "ok", "checks": checks}


class GenerateRequest(BaseModel):
    prompt: str = "masterpiece, best quality, 1girl, anime style, portrait"
    negative: Optional[str] = None
    steps: int = 20
    seed: Optional[int] = None
    model: str = "waifu"  # waifu or z-anime


@router.post("/generate")
async def generate_avatar(request: GenerateRequest):
    """Genera un nuevo avatar anime"""
    import subprocess, json
    
    if request.model == "waifu":
        cmd = ["/home/clarwis/.hermes/hermes-agent/venv/bin/python3", "/opt/klawaqua/scripts/waifu_generate.py",
               "--prompt", request.prompt, "--steps", str(request.steps)]
        if request.negative:
            cmd += ["--negative", request.negative]
        if request.seed:
            cmd += ["--seed", str(request.seed)]
    elif request.model == "z-anime":
        cmd = ["python3", "/opt/klawaqua/scripts/z_anime_generate.py",
               "--prompt", request.prompt, "--steps", str(min(request.steps, 4))]
    else:
        raise HTTPException(status_code=400, detail=f"Modelo desconocido: {request.model}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180, check=True)
        return json.loads(result.stdout.strip().split("\n")[-1])
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=e.stderr[-500:])
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Timeout generando avatar")
