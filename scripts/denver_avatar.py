#!/usr/bin/env python3
"""
Denver Avatar Cinematic - Imagen + Audio TTS + Video cinemático
1. Genera audio con Edge TTS en español
2. Genera video cinemático con FFmpeg (zoom Ken Burns + filtros)
3. Combina audio + video
4. Opcional: Wav2Lip para lip-sync real si las dependencias están disponibles
"""

import os, sys, subprocess, tempfile
from pathlib import Path

KLAWAQUA = "/opt/klawaqua"
WAV2LIP_DIR = f"{KLAWAQUA}/projects/Wav2Lip"

def log(msg):
    print(f"▶ {msg}")


def generate_tts(text, output_path):
    """Generar audio con Edge TTS"""
    log(f"Generando audio TTS: '{text[:50]}...'")
    cmd = [
        "edge-tts",
        "--text", text,
        "--voice", "es-ES-ElviraNeural",
        "--rate", "-5%",
        "--write-media", output_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"TTS failed: {result.stderr}")
    log(f"Audio generado: {output_path}")
    return output_path


def generate_cinematic_video(image_path, duration, output_path):
    """Video cinemático con efecto Ken Burns"""
    log("Generando video cinemático...")
    d = str(duration)
    frames = str(int(duration * 25))
    
    cmd = [
        "ffmpeg", "-hide_banner", "-y",
        "-loop", "1", "-i", image_path,
        "-vf", (
            f"zoompan=z='min(zoom+0.0015,1.08)':"
            f"d={frames}:"
            f"x='iw/2-(iw/zoom/2)':"
            f"y='ih/2-(ih/zoom/2)':"
            f"s=1280x720,"
            "eq=contrast=1.1:saturation=1.2:brightness=0.05,"
            "fps=25"
        ),
        "-c:v", "libx264", "-preset", "medium", "-crf", "23",
        "-pix_fmt", "yuv420p",
        "-t", d, "-an",
        output_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        raise RuntimeError(f"Video failed: {result.stderr}")
    log(f"Video cinemático: {output_path}")
    return output_path


def combine_video_audio(video_path, audio_path, output_path):
    """Combinar video + audio"""
    log("Combinando video + audio...")
    cmd = [
        "ffmpeg", "-hide_banner", "-y",
        "-i", video_path, "-i", audio_path,
        "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
        "-shortest",
        "-pix_fmt", "yuv420p",
        output_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"Combine failed: {result.stderr}")
    log(f"Video final: {output_path}")
    return output_path


def try_wav2lip(image_path, audio_path, output_path):
    """Intentar lip-sync con Wav2Lip si las dependencias funcionan"""
    log("Intentando lip-sync con Wav2Lip...")
    checkpoint = os.path.join(WAV2LIP_DIR, "checkpoints", "wav2lip.pth")
    if not os.path.exists(checkpoint):
        log(" Wav2Lip checkpoint no encontrado, salto lip-sync")
        return None
    
    # Probar si numpy funciona sin errores
    test_result = subprocess.run(
        ["python3", "-c", "import numpy as np; print(hasattr(np, 'complex'))"],
        capture_output=True, text=True, timeout=5
    )
    
    if "True" in test_result.stdout:
        log("⚠ Numpy antiguo detectado, Wav2Lip requiere parche")
        return None
    
    # Intentar inferencia
    cmd = [
        "python3", os.path.join(WAV2LIP_DIR, "inference.py"),
        "--checkpoint_path", checkpoint,
        "--face", image_path,
        "--audio", audio_path,
        "--outfile", output_path,
        "--resize_factor", "1"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode == 0 and os.path.exists(output_path):
            log(f"✓ Lip-sync exitoso: {output_path}")
            return output_path
        else:
            log(f"⚠ Wav2Lip fallo: {result.stderr[:200]}")
            return None
    except subprocess.TimeoutExpired:
        log("⚠ Wav2Lip timeout, usando fallback")
        return None


def main():
    # Config
    image_path = sys.argv[1] if len(sys.argv) > 1 else "/home/clarwis/.hermes/image_cache/img_cfd01f3b801c.jpg"
    text = sys.argv[2] if len(sys.argv) > 2 else "Hola, soy Denver y te quiero mucho"
    output_dir = sys.argv[3] if len(sys.argv) > 3 else "/tmp"
    output_name = Path(output_dir) / "denver_talking.mp4"
    
    log("Pipeline: imagen + TTS → video cinemático + audio ± lip-sync")
    log(f"Imagen: {image_path}")
    log(f"Texto: {text}")
    log(f"Salida: {output_name}")
    
    try:
        # 1. Generar audio
        audio_path = os.path.join(output_dir, "denver_speech.mp3")
        generate_tts(text, audio_path)
        
        # 2. Generar video cinemático
        temp_video = os.path.join(output_dir, "denver_cinematic.mp4")
        generate_cinematic_video(image_path, 5, temp_video)
        
        # 3. Combinar video + audio
        combine_video_audio(temp_video, audio_path, output_name)
        
        # 4. Verificar output
        ffprobe = subprocess.run(["ffprobe", str(output_name)], 
            capture_output=True, text=True, timeout=5)
        for line in ffprobe.stderr.split("\n"):
            if "Duration" in line:
                log(f"Duración: {line.strip()}")
            if "stream" in line.lower():
                log(line.strip())
        
        log(f"✓ Video generado: {output_name}")
        log(f"Tamaño: {os.path.getsize(output_name)/1024:.1f} KB")
        
        # Cleanup
        try: os.remove(temp_video)
        except: pass
        try: os.remove(audio_path)
        except: pass
        
    except Exception as e:
        log(f" Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
