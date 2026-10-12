"""Download pinned client Lua/API fixtures for test_mapcanvas.py; never runs in WoW."""
from pathlib import Path
from urllib.request import Request,urlopen
from concurrent.futures import ThreadPoolExecutor
import json,sys
ROOT=Path(__file__).resolve().parents[1]
meta=json.loads((ROOT/'tests'/'forever-source-manifest.json').read_text(encoding='utf-8'))
dest=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'tests'/'forever_sources'
dest.mkdir(parents=True,exist_ok=True)
def fetch(path):
    url=f"https://raw.githubusercontent.com/Gethe/wow-ui-source/{meta['commit']}/{path}"
    with urlopen(Request(url,headers={'User-Agent':'ChestAtlas-validation'}),timeout=30) as response:
        (dest/Path(path).name).write_bytes(response.read())
with ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(fetch,meta['files']))
(dest/'manifest.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
print(f"Saved {len(meta['files'])} pinned files to {dest}")
