import re
import os
import sys
import glob
from pathlib import Path

import chromadb

REPO_ROOT = Path(__file__).parent.parent
CHROMA_PATH = REPO_ROOT / "data" / "chroma"
PROCESSED_LOG = REPO_ROOT / "data" / "processed.txt"


def vtt_to_text(filepath: str) -> str:
    with open(filepath, encoding="utf-8") as f:
        content = f.read()
    lines = content.split("\n")
    clean, prev = [], None
    for line in lines:
        if any([
            line.startswith("WEBVTT"),
            line.startswith("Kind:"),
            line.startswith("Language:"),
            "-->" in line,
            "<" in line,
            not line.strip(),
        ]):
            continue
        if line != prev:
            clean.append(line)
            prev = line
    return re.sub(r"\s+", " ", " ".join(clean)).strip()


def chunk_text(text: str, chunk_size: int = 400, overlap: int = 50) -> list[str]:
    words = text.split()
    chunks = []
    i = 0
    while i < len(words):
        chunk = " ".join(words[i : i + chunk_size])
        if chunk:
            chunks.append(chunk)
        i += chunk_size - overlap
    return chunks


def extract_video_id(filename: str) -> str:
    match = re.search(r"\[([a-zA-Z0-9_-]{11})\]", filename)
    return match.group(1) if match else filename


def extract_title(filename: str, video_id: str) -> str:
    name = os.path.basename(filename)
    name = re.sub(r"\[" + video_id + r"\].*$", "", name).strip()
    return name


def main():
    transcripts_dir = sys.argv[1] if len(sys.argv) > 1 else str(REPO_ROOT / "transcripts")
    transcripts_dir = os.path.expanduser(transcripts_dir)

    if not os.path.exists(transcripts_dir):
        print(f"Error: no existe el directorio '{transcripts_dir}'")
        print("Uso: uv run src/indexer.py /ruta/a/transcripts")
        sys.exit(1)

    CHROMA_PATH.mkdir(parents=True, exist_ok=True)
    PROCESSED_LOG.parent.mkdir(parents=True, exist_ok=True)

    client = chromadb.PersistentClient(path=str(CHROMA_PATH))
    collection = client.get_or_create_collection(
        name="mark_knowledge",
        metadata={"hnsw:space": "cosine"},
    )

    processed = set()
    if PROCESSED_LOG.exists():
        processed = set(PROCESSED_LOG.read_text().splitlines())

    vtt_files = glob.glob(os.path.join(transcripts_dir, "**", "*.vtt"), recursive=True)
    vtt_files += glob.glob(os.path.join(transcripts_dir, "*.vtt"))
    vtt_files = list(set(vtt_files))

    if not vtt_files:
        print(f"No se encontraron archivos .vtt en '{transcripts_dir}'")
        sys.exit(1)

    new_count = 0
    for vtt_file in sorted(vtt_files):
        if vtt_file in processed:
            print(f"  skip  {os.path.basename(vtt_file)}")
            continue

        text = vtt_to_text(vtt_file)
        if not text:
            print(f"  empty {os.path.basename(vtt_file)}")
            continue

        video_id = extract_video_id(vtt_file)
        title = extract_title(vtt_file, video_id)
        chunks = chunk_text(text)

        collection.add(
            documents=chunks,
            ids=[f"{video_id}_chunk_{i}" for i in range(len(chunks))],
            metadatas=[
                {
                    "video_id": video_id,
                    "title": title,
                    "youtube_url": f"https://youtu.be/{video_id}",
                    "chunk_index": i,
                }
                for i in range(len(chunks))
            ],
        )

        with open(PROCESSED_LOG, "a") as f:
            f.write(vtt_file + "\n")

        print(f"  ok    {title[:60]} ({len(chunks)} chunks)")
        new_count += 1

    print(f"\n✓ {new_count} videos nuevos indexados")
    print(f"✓ Total chunks en DB: {collection.count()}")


if __name__ == "__main__":
    main()
