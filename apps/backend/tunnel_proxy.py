import httpx
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = httpx.AsyncClient(timeout=120.0)

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"])
async def proxy(request: Request, path: str):
    if path.startswith("v1") or path.startswith("docs") or path.startswith("openapi.json"):
        target_base = "http://127.0.0.1:8000"
    else:
        target_base = "http://127.0.0.1:8080"
    
    url = f"{target_base}/{path}"
    if request.url.query:
        url += f"?{request.url.query}"
    
    headers = dict(request.headers)
    headers.pop("host", None)
    headers.pop("content-length", None)
    body = await request.body()
    
    req = client.build_request(
        method=request.method,
        url=url,
        headers=headers,
        content=body,
    )
    res = await client.send(req, stream=True)
    
    res_headers = dict(res.headers)
    res_headers.pop("content-length", None)
    res_headers.pop("content-encoding", None)
    
    return StreamingResponse(
        res.aiter_raw(),
        status_code=res.status_code,
        headers=res_headers,
        background=res.aclose,
    )

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5050)
