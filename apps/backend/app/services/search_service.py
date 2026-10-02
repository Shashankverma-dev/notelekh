
from sqlalchemy.orm import Session

from app.models.entities import (
    CanvasDocument,
    Conversation,
    FileItem,
    Highlight,
    Message,
    Note,
    Workspace,
)
from app.schemas.all_schemas import SearchResponse, SearchResultItem


def execute_global_search(query_str: str, user_id: str, db: Session) -> SearchResponse:
    q = query_str.strip().lower()
    if not q:
        return SearchResponse(query=query_str, total_results=0, results=[])

    results: list[SearchResultItem] = []
    pattern = f"%{q}%"

    # 1. Search Workspaces
    workspaces = db.query(Workspace).filter(
        Workspace.user_id == user_id,
        (Workspace.name.ilike(pattern) | Workspace.description.ilike(pattern))
    ).all()
    for ws in workspaces:
        results.append(SearchResultItem(
            entity_type="workspace",
            id=ws.id,
            title=ws.name,
            snippet=ws.description or "Workspace project",
            workspace_id=ws.id,
            workspace_name=ws.name,
            created_at=ws.created_at
        ))

    # 2. Search Conversations
    conversations = db.query(Conversation).filter(
        Conversation.user_id == user_id,
        Conversation.title.ilike(pattern)
    ).all()
    for conv in conversations:
        ws_name = conv.workspace.name if conv.workspace else "General Chats"
        results.append(SearchResultItem(
            entity_type="conversation",
            id=conv.id,
            title=conv.title,
            snippet=f"Conversation in {ws_name}",
            workspace_id=conv.workspace_id,
            workspace_name=ws_name,
            created_at=conv.created_at
        ))

    # 3. Search Messages
    messages = db.query(Message).join(Conversation).filter(
        Conversation.user_id == user_id,
        Message.content.ilike(pattern)
    ).limit(20).all()
    for msg in messages:
        snippet = msg.content[:140] + ("..." if len(msg.content) > 140 else "")
        ws_name = msg.conversation.workspace.name if msg.conversation.workspace else "General"
        results.append(SearchResultItem(
            entity_type="message",
            id=msg.id,
            title=f"Message in '{msg.conversation.title}'",
            snippet=snippet,
            workspace_id=msg.conversation.workspace_id,
            workspace_name=ws_name,
            created_at=msg.created_at
        ))

    # 4. Search Notes
    notes = db.query(Note).join(Workspace).filter(
        Workspace.user_id == user_id,
        (Note.title.ilike(pattern) | Note.content.ilike(pattern))
    ).all()
    for n in notes:
        snippet = n.content[:140] + ("..." if len(n.content) > 140 else "")
        results.append(SearchResultItem(
            entity_type="note",
            id=n.id,
            title=n.title,
            snippet=snippet or "Note content",
            workspace_id=n.workspace_id,
            workspace_name=n.workspace.name,
            created_at=n.created_at
        ))

    # 5. Search Files
    files = db.query(FileItem).join(Workspace).filter(
        Workspace.user_id == user_id,
        FileItem.name.ilike(pattern)
    ).all()
    for f in files:
        results.append(SearchResultItem(
            entity_type="file",
            id=f.id,
            title=f.name,
            snippet=f"{f.mime_type} • {(f.size // 1024)} KB",
            workspace_id=f.workspace_id,
            workspace_name=f.workspace.name,
            created_at=f.created_at
        ))

    # 6. Search Highlights
    highlights = db.query(Highlight).join(Workspace).filter(
        Workspace.user_id == user_id,
        (Highlight.text.ilike(pattern) | Highlight.comment.ilike(pattern))
    ).all()
    for h in highlights:
        results.append(SearchResultItem(
            entity_type="highlight",
            id=h.id,
            title=f"Highlight ({h.color})",
            snippet=h.text[:120],
            workspace_id=h.workspace_id,
            workspace_name=h.workspace.name,
            created_at=h.created_at
        ))

    # 7. Search Canvas Documents
    canvases = db.query(CanvasDocument).join(Workspace).filter(
        Workspace.user_id == user_id,
        CanvasDocument.name.ilike(pattern)
    ).all()
    for c in canvases:
        results.append(SearchResultItem(
            entity_type="canvas",
            id=c.id,
            title=c.name,
            snippet="Digital Canvas Document",
            workspace_id=c.workspace_id,
            workspace_name=c.workspace.name,
            created_at=c.created_at
        ))

    return SearchResponse(
        query=query_str,
        total_results=len(results),
        results=results
    )
