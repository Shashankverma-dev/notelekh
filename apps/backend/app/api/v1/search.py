from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.entities import User
from app.schemas.all_schemas import SearchResponse
from app.services.auth_service import get_current_user
from app.services.search_service import execute_global_search

router = APIRouter(prefix="/search", tags=["search"])

@router.get("", response_model=SearchResponse)
def global_search(
    q: str = Query("", description="Search term"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return execute_global_search(query_str=q, user_id=current_user.id, db=db)
