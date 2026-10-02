from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.entities import CanvasDocument, User, Workspace
from app.schemas.all_schemas import (
    CanvasDocumentOut,
    ConversationOut,
    FileItemOut,
    HighlightOut,
    NoteOut,
    WorkspaceCreate,
    WorkspaceOut,
    WorkspaceUpdate,
)
from app.services.auth_service import get_current_user

router = APIRouter(prefix="/workspaces", tags=["workspaces"])

@router.get("", response_model=list[WorkspaceOut])
def list_workspaces(
    include_archived: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    query = db.query(Workspace).filter(Workspace.user_id == current_user.id)
    if not include_archived:
        query = query.filter(Workspace.archived_at == None)
    workspaces = query.order_by(Workspace.is_pinned.desc(), Workspace.updated_at.desc()).all()
    
    result = []
    for ws in workspaces:
        out = WorkspaceOut.model_validate(ws)
        out.conversation_count = len(ws.conversations)
        out.file_count = len(ws.files)
        out.canvas_count = len(ws.canvas_documents)
        result.append(out)
    return result

@router.post("", response_model=WorkspaceOut)
def create_workspace(
    ws_in: WorkspaceCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = Workspace(
        user_id=current_user.id,
        name=ws_in.name,
        description=ws_in.description or "",
        icon=ws_in.icon or "folder",
        is_pinned=ws_in.is_pinned or False
    )
    db.add(ws)
    db.commit()
    db.refresh(ws)
    
    # Auto-create a default Canvas and Note for the workspace
    default_canvas = CanvasDocument(
        workspace_id=ws.id,
        name=f"{ws.name} Notebook"
    )
    db.add(default_canvas)
    db.commit()
    
    out = WorkspaceOut.model_validate(ws)
    out.canvas_count = 1
    return out

@router.get("/{id}", response_model=WorkspaceOut)
def get_workspace(
    id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    out = WorkspaceOut.model_validate(ws)
    out.conversation_count = len(ws.conversations)
    out.file_count = len(ws.files)
    out.canvas_count = len(ws.canvas_documents)
    return out

@router.patch("/{id}", response_model=WorkspaceOut)
def update_workspace(
    id: str,
    ws_in: WorkspaceUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    
    update_data = ws_in.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(ws, key, value)
    
    ws.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(ws)
    return WorkspaceOut.model_validate(ws)

@router.delete("/{id}")
def delete_workspace(
    id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    db.delete(ws)
    db.commit()
    return {"status": "deleted", "id": id}

@router.get("/{id}/conversations", response_model=list[ConversationOut])
def get_workspace_conversations(
    id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return [ConversationOut.model_validate(c) for c in ws.conversations]

@router.get("/{id}/canvas", response_model=list[CanvasDocumentOut])
def get_workspace_canvas_docs(
    id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return [CanvasDocumentOut.model_validate(c) for c in ws.canvas_documents]

@router.get("/{id}/files", response_model=list[FileItemOut])
def get_workspace_files(
    id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return [FileItemOut.model_validate(f) for f in ws.files]

@router.get("/{id}/notes", response_model=list[NoteOut])
def get_workspace_notes(
    id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return [NoteOut.model_validate(n) for n in ws.notes]

@router.get("/{id}/highlights", response_model=list[HighlightOut])
def get_workspace_highlights(
    id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return [HighlightOut.model_validate(h) for h in ws.highlights]

@router.get("/{id}/export")
def export_workspace(
    id: str,
    format: str = "pdf",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ws = db.query(Workspace).filter(Workspace.id == id, Workspace.user_id == current_user.id).first()
    if not ws:
        raise HTTPException(status_code=404, detail="Workspace not found")
    
    clean_name = "".join(c for c in ws.name if c.isalnum() or c in (" ", "_", "-")).strip().replace(" ", "_")
    if not clean_name:
        clean_name = "workspace"
        
    fmt = format.lower().strip()
    if fmt == "docx":
        from app.services.export_service import export_workspace_docx
        data = export_workspace_docx(ws)
        return Response(
            content=data,
            media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            headers={"Content-Disposition": f'attachment; filename="{clean_name}_export.docx"'}
        )
    elif fmt == "md" or fmt == "markdown":
        from app.services.export_service import export_workspace_markdown
        text_data = export_workspace_markdown(ws)
        return Response(
            content=text_data.encode("utf-8"),
            media_type="text/markdown; charset=utf-8",
            headers={"Content-Disposition": f'attachment; filename="{clean_name}_export.md"'}
        )
    else:  # default to PDF
        from app.services.export_service import export_workspace_pdf
        pdf_data = export_workspace_pdf(ws)
        return Response(
            content=pdf_data,
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="{clean_name}_export.pdf"'}
        )
