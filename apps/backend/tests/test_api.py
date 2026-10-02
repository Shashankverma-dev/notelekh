from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "online"

def test_workspaces_and_canvas_flow():
    # Direct access to workspaces and studio
    headers = {}

    # 2. Create Workspace
    ws_res = client.post("/v1/workspaces", json={
        "name": "📚 Blockchain Assignment",
        "description": "Smart contracts & consensus research",
        "icon": "book"
    }, headers=headers)
    assert ws_res.status_code == 200
    ws_data = ws_res.json()
    ws_id = ws_data["id"]
    assert ws_data["name"] == "📚 Blockchain Assignment"

    # 3. Create & Stream AI Chat
    ai_stream_res = client.post("/v1/ai/chat/stream", json={
        "prompt": "Explain consensus algorithms in 2 sentences",
        "workspace_id": ws_id,
        "context_items": [
            {"type": "note", "title": "BFT Notes", "content": "Byzantine Fault Tolerance"}
        ]
    }, headers=headers)
    assert ai_stream_res.status_code == 200
    stream_content = ai_stream_res.text
    assert "data:" in stream_content

    # 4. Canvas Creation & Batch Sync
    canvas_list = client.get(f"/v1/workspaces/{ws_id}/canvas", headers=headers).json()
    assert len(canvas_list) > 0
    canvas_id = canvas_list[0]["id"]

    sync_res = client.post(f"/v1/canvas/{canvas_id}/batch-sync", json={
        "objects": [
            {
                "id": "stroke-1",
                "object_type": "stroke",
                "bounds": {"x": 10, "y": 10, "width": 100, "height": 50},
                "data": {
                    "tool": "pen",
                    "color": "#6366F1",
                    "width": 3.5,
                    "points": [{"x": 10, "y": 10, "pressure": 0.8}, {"x": 50, "y": 40, "pressure": 0.9}]
                }
            }
        ]
    }, headers=headers)
    assert sync_res.status_code == 200
    assert sync_res.json()["count"] == 1

    # 5. Global Search
    search_res = client.get("/v1/search?q=Blockchain", headers=headers)
    assert search_res.status_code == 200
    assert search_res.json()["total_results"] > 0

    # 6. Export Workspace (PDF, Word docx, Markdown)
    pdf_res = client.get(f"/v1/workspaces/{ws_id}/export?format=pdf", headers=headers)
    assert pdf_res.status_code == 200
    assert len(pdf_res.content) > 500
    assert pdf_res.headers["content-type"] == "application/pdf"

    docx_res = client.get(f"/v1/workspaces/{ws_id}/export?format=docx", headers=headers)
    assert docx_res.status_code == 200
    assert len(docx_res.content) > 1000

    md_res = client.get(f"/v1/workspaces/{ws_id}/export?format=md", headers=headers)
    assert md_res.status_code == 200
    assert "# Workspace:" in md_res.text

    # 7. Delete Workspace
    del_res = client.delete(f"/v1/workspaces/{ws_id}", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "deleted"
