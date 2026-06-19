from pathlib import Path

import chromadb
from mcp.server.fastmcp import FastMCP

REPO_ROOT = Path(__file__).parent.parent
CHROMA_PATH = REPO_ROOT / "data" / "chroma"

mcp = FastMCP("mark-coach")

_client = None
_collection = None


def get_collection():
    global _client, _collection
    if _collection is None:
        if not CHROMA_PATH.exists():
            raise RuntimeError(
                "La base de conocimiento no existe. Ejecutá primero: uv run src/indexer.py /ruta/transcripts"
            )
        _client = chromadb.PersistentClient(path=str(CHROMA_PATH))
        _collection = _client.get_collection("mark_knowledge")
    return _collection


@mcp.tool()
def search_mark_knowledge(query: str, n_results: int = 6) -> str:
    """
    Busca en la base de conocimiento de Mark Builds Brands.
    Úsalo para encontrar qué dice Mark sobre cualquier tema de ecommerce,
    Facebook Ads, creatividades, escalado, análisis de métricas, etc.
    """
    try:
        collection = get_collection()
    except RuntimeError as e:
        return str(e)

    results = collection.query(query_texts=[query], n_results=n_results)

    if not results["documents"][0]:
        return "No se encontró contenido relevante."

    output = []
    for doc, meta in zip(results["documents"][0], results["metadatas"][0]):
        title = meta.get("title", "Sin título")
        url = meta.get("youtube_url", "")
        output.append(f"**{title}**\n{url}\n\n{doc}")

    return "\n\n---\n\n".join(output)


def main():
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
