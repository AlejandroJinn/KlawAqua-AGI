#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Avatar Parlante Pipeline
Texto → LLM (qwen3.5:4b) → TTS (Edge) → Video (SadTalker/Wav2Lip)

Uso:
  python3 avatar_pipeline.py "Hola, soy KlawAqua" output.mp4
  python3 avatar_pipeline.py --input texto.txt --output video.mp4 --image avatar.png
"""

import os
import sys
import subprocess
import tempfile
import argparse
from pathlib import Path
from datetime import datetime

# Constants
KLAWAQUA_BASE = "/opt/klawaqua"
SADTALKER_DIR = f"{KLAWAQUA_BASE}/projects/klawaqua-avatar/SadTalker"
CHECKPOINTS_DIR = f"{SADTALKER_DIR}/checkpoints"
DEFAULT_IMAGE = f"{SADTALKER_DIR}/examples/source_image/happy.png"
DEFAULT_VOICE = "es-ES-ElviraNeural"

def log(message: str, level: str = "INFO"):
    """Log message with timestamp"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] [{level}] {message}")

def generate_text_with_llm(prompt: str) -> str:
    """Generate text using qwen3.5:4b via Ollama"""
    try:
        log("Generando texto con qwen3.5:4b...")
        result = subprocess.run(
            ["ollama", "run", "qwen3.5:4b", prompt],
            capture_output=True,
            text=True,
            timeout=120
        )
        if result.returncode == 0:
            text = result.stdout.strip()
            log(f"Texto generado: {text[:100]}...")
            return text
        else:
            log(f"Error en LLM: {result.stderr}", "ERROR")
            return None
    except subprocess.TimeoutExpired:
        log("Timeout en generación de texto", "ERROR")
        return None
    except Exception as e:
        log(f"Excepción en LLM: {e}", "ERROR")
        return None

def text_to_speech(text: str, output_audio: str, voice: str = DEFAULT_VOICE) -> bool:
    """Convert text to speech using edge-tts"""
    try:
        log(f"Generando audio con Edge TTS ({voice})...")
        import edge_tts
        
        communicate = edge_tts.Communicate(text, voice)
        communicate.save_sync(output_audio)
        
        if os.path.exists(output_audio):
            size = os.path.getsize(output_audio)
            log(f"Audio generado: {size/1024:.2f} KB")
            return True
        else:
            log("No se generó el audio", "ERROR")
            return False
    except ImportError:
        log("edge-tts no instalado. Ejecutar: pip install edge-tts", "ERROR")
        return False
    except Exception as e:
        log(f"Error en TTS: {e}", "ERROR")
        return False

def generate_video_sadtalker(audio_path: str, image_path: str, output_video: str) -> bool:
    """Generate talking avatar video using SadTalker"""
    try:
        log("Generando video con SadTalker...")
        
        if not os.path.exists(SADTALKER_DIR):
            log(f"SadTalker no encontrado en {SADTALKER_DIR}", "ERROR")
            return False
        
        if not os.path.exists(CHECKPOINTS_DIR):
            log(f"Checkpoints no encontrados en {CHECKPOINTS_DIR}", "ERROR")
            log("Ejecutar: cd SadTalker && bash download_models.sh", "ERROR")
            return False
        
        with tempfile.TemporaryDirectory() as tmpdir:
            cmd = [
                "python3", f"{SADTALKER_DIR}/inference.py",
                "--driven_audio", audio_path,
                "--source_image", image_path,
                "--result_dir", tmpdir,
                "--checkpoint_dir", CHECKPOINTS_DIR,
                "--preprocess", "crop",
                "--size", "256",
                "--still",  # Less head movement
                "--expr_coeff", "3.0",  # More expression
                "--pose_coeff", "1.5"  # Moderate pose
            ]
            
            log(f"Ejecutando: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
            
            if result.returncode != 0:
                log(f"SadTalker falló: {result.stderr}", "ERROR")
                return False
            
            # Find output video
            import glob
            video_files = glob.glob(f"{tmpdir}/*.mp4")
            if not video_files:
                video_files = glob.glob(f"{tmpdir}/*.avi")
            
            if not video_files:
                log("SadTalker no generó video", "ERROR")
                return False
            
            # Move to output
            generated_video = video_files[0]
            subprocess.run(["mv", generated_video, output_video], check=True)
            
            if os.path.exists(output_video):
                size = os.path.getsize(output_video)
                log(f"Video generado: {size/1024/1024:.2f} MB")
                return True
            else:
                return False
                
    except subprocess.TimeoutExpired:
        log("Timeout en SadTalker (10 min)", "ERROR")
        return False
    except Exception as e:
        log(f"Error en SadTalker: {e}", "ERROR")
        return False

def avatar_pipeline(
    text: str = None,
    text_file: str = None,
    output_video: str = "output.mp4",
    image_path: str = None,
    voice: str = DEFAULT_VOICE,
    use_llm: bool = False
) -> bool:
    """
    Complete avatar pipeline:
    Text (or LLM) → TTS → Video
    """
    log("=" * 60)
    log("   KLAWAQUA-AGI: AVATAR PARLANTE PIPELINE")
    log("=" * 60)
    
    # Step 1: Get text (from LLM or input)
    if use_llm:
        if not text:
            text = "Explica qué es KlawAqua-AGI en 2-3 frases"
        llm_text = generate_text_with_llm(text)
        if not llm_text:
            log("Fallo en generación de texto con LLM", "ERROR")
            return False
        text = llm_text
    elif text_file:
        if not os.path.exists(text_file):
            log(f"Archivo no encontrado: {text_file}", "ERROR")
            return False
        with open(text_file, 'r') as f:
            text = f.read().strip()
        log(f"Texto leído desde {text_file}")
    
    if not text:
        log("No hay texto para procesar", "ERROR")
        return False
    
    log(f"Texto a sintetizar: {text[:100]}...")
    
    # Step 2: Create temp files
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_audio:
        audio_path = f_audio.name
    
    try:
        # Step 3: Text-to-Speech
        if not text_to_speech(text, audio_path, voice):
            return False
        
        # Step 4: Use default image if not provided
        if not image_path:
            image_path = DEFAULT_IMAGE
            if not os.path.exists(image_path):
                # Try to find any image in SadTalker examples
                import glob
                images = glob.glob(f"{SADTALKER_DIR}/examples/source_image/*.png")
                if images:
                    image_path = images[0]
                else:
                    log("No se encontró imagen de avatar", "ERROR")
                    return False
        
        log(f"Usando imagen: {image_path}")
        
        # Step 5: Generate video
        if not generate_video_sadtalker(audio_path, image_path, output_video):
            return False
        
        log("=" * 60)
        log(f"   ✅ VIDEO GENERADO EXITOSAMENTE")
        log(f"   Output: {output_video}")
        log(f"   Tamaño: {os.path.getsize(output_video)/1024/1024:.2f} MB")
        log("=" * 60)
        
        return True
        
    finally:
        # Cleanup
        if os.path.exists(audio_path):
            os.unlink(audio_path)

def main():
    parser = argparse.ArgumentParser(
        description="KLAWAQUA-AGI Avatar Parlante Pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  # generar video con texto directo
  python3 avatar_pipeline.py "Hola mundo" output.mp4
  
  # generar con LLM
  python3 avatar_pipeline.py --llm "Qué es KlawAqua" --output video.mp4
  
  # desde archivo de texto
  python3 avatar_pipeline.py --input guion.txt --output video.mp4
  
  # con imagen personalizada
  python3 avatar_pipeline.py "Hola" output.mp4 --image mi_avatar.png
  
  # con voz diferente
  python3 avatar_pipeline.py "Hola" output.mp4 --voice es-MX-DaliaNeural
        """
    )
    
    parser.add_argument("text", nargs="?", help="Texto a sintetizar")
    parser.add_argument("--input", "-i", dest="text_file", help="Archivo de texto")
    parser.add_argument("--output", "-o", default="output.mp4", help="Video de salida")
    parser.add_argument("--image", help="Imagen del avatar (default: happy.png)")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help="Voz Edge TTS")
    parser.add_argument("--llm", action="store_true", help="Usar qwen3.5:4b para generar texto")
    parser.add_argument("--prompt", "-p", help="Prompt para LLM")
    
    args = parser.parse_args()
    
    # Validate input
    if not args.text and not args.text_file and not args.llm:
        parser.print_help()
        sys.exit(1)
    
    # Use LLM if requested
    use_llm = args.llm or (args.prompt is not None)
    text = args.prompt if args.prompt else args.text
    
    # Run pipeline
    success = avatar_pipeline(
        text=text,
        text_file=args.text_file,
        output_video=args.output,
        image_path=args.image,
        voice=args.voice,
        use_llm=use_llm
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
