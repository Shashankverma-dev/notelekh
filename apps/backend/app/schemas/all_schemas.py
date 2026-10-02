from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr


# ================= USER =================
class UserBase(BaseModel):
    email: EmailStr
    display_name: str

class UserOut(UserBase):
    id: str
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ================= WORKSPACE =================
class WorkspaceBase(BaseModel):
    name: str
    description: str | None = ""
    icon: str | None = "folder"
    is_pinned: bool | None = False

class WorkspaceCreate(WorkspaceBase):
    pass

class WorkspaceUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    icon: str | None = None
    is_pinned: bool | None = None
    archived_at: datetime | None = None

class WorkspaceOut(WorkspaceBase):
    id: str
    user_id: str
    archived_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    conversation_count: int | None = 0
    file_count: int | None = 0
    canvas_count: int | None = 0
    model_config = ConfigDict(from_attributes=True)

# ================= CONVERSATION & MESSAGES =================
class MessageBase(BaseModel):
    role: str
    content: str
    model: str | None = "gpt-4o-mini"
    selected_context: list[dict[str, Any]] | None = []

class MessageCreate(BaseModel):
    content: str
    model: str | None = "gpt-4o-mini"
    selected_context: list[dict[str, Any]] | None = []

class MessageOut(MessageBase):
    id: str
    conversation_id: str
    token_usage: dict[str, Any] | None = {}
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

class ConversationCreate(BaseModel):
    workspace_id: str | None = None
    title: str | None = "New Conversation"

class ConversationUpdate(BaseModel):
    title: str | None = None
    workspace_id: str | None = None
    status: str | None = None

class ConversationSaveRequest(BaseModel):
    workspace_id: str
    title: str | None = None

class ConversationOut(BaseModel):
    id: str
    workspace_id: str | None = None
    user_id: str
    title: str
    status: str
    created_at: datetime
    updated_at: datetime
    messages: list[MessageOut] | None = []
    model_config = ConfigDict(from_attributes=True)

# ================= CANVAS =================
class CanvasObjectBase(BaseModel):
    object_type: str # stroke, text, shape, image, highlight
    z_index: int | None = 0
    bounds: dict[str, Any] | None = {}
    transform: dict[str, Any] | None = {}
    data: dict[str, Any]

class CanvasObjectCreate(CanvasObjectBase):
    pass

class CanvasObjectUpdate(BaseModel):
    object_type: str | None = None
    z_index: int | None = None
    bounds: dict[str, Any] | None = None
    transform: dict[str, Any] | None = None
    data: dict[str, Any] | None = None

class CanvasObjectOut(CanvasObjectBase):
    id: str
    canvas_document_id: str
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

class CanvasDocumentCreate(BaseModel):
    workspace_id: str
    name: str | None = "Untitled Canvas"

class CanvasDocumentUpdate(BaseModel):
    name: str | None = None
    thumbnail_key: str | None = None

class CanvasDocumentOut(BaseModel):
    id: str
    workspace_id: str
    name: str
    document_version: int
    thumbnail_key: str | None = None
    created_at: datetime
    updated_at: datetime
    objects: list[CanvasObjectOut] | None = []
    model_config = ConfigDict(from_attributes=True)

# ================= FILES =================
class FileItemOut(BaseModel):
    id: str
    workspace_id: str
    name: str
    mime_type: str
    size: int
    storage_key: str
    processing_status: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# ================= NOTES & HIGHLIGHTS =================
class NoteCreate(BaseModel):
    workspace_id: str
    title: str | None = "Untitled Note"
    content: str | None = ""

class NoteUpdate(BaseModel):
    title: str | None = None
    content: str | None = None

class NoteOut(BaseModel):
    id: str
    workspace_id: str
    title: str
    content: str
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

class HighlightCreate(BaseModel):
    workspace_id: str
    source_type: str
    source_id: str
    text: str
    color: str | None = "yellow"
    comment: str | None = ""

class HighlightOut(BaseModel):
    id: str
    workspace_id: str
    source_type: str
    source_id: str
    text: str
    color: str
    comment: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# ================= AI ORCHESTRATION =================
class AIContextItem(BaseModel):
    type: str # message, note, canvas_selection, file, highlight
    title: str
    content: str | None = None
    image_base64: str | None = None
    metadata: dict[str, Any] | None = {}

class AIChatRequest(BaseModel):
    prompt: str
    conversation_id: str | None = None
    workspace_id: str | None = None
    model: str | None = "gpt-4o-mini"
    context_items: list[AIContextItem] | None = []
    stream: bool | None = True

class AISelectionAnalyzeRequest(BaseModel):
    action: str # explain, summarize, ocr_rewrite, generate_questions, convert_diagram
    prompt: str | None = None
    workspace_id: str | None = None
    selected_text: str | None = None
    selected_image_base64: str | None = None
    selected_objects: list[dict[str, Any]] | None = None

class AISummaryResponse(BaseModel):
    result: str
    usage: dict[str, Any] | None = {}

# ================= SEARCH =================
class SearchResultItem(BaseModel):
    entity_type: str # workspace, conversation, message, note, file, highlight, canvas
    id: str
    title: str
    snippet: str
    workspace_id: str | None = None
    workspace_name: str | None = None
    created_at: datetime

class SearchResponse(BaseModel):
    query: str
    total_results: int
    results: list[SearchResultItem]
