from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.entities import User

def get_current_user(
    db: Session = Depends(get_db)
) -> User:
    """Returns the default workspace user directly with zero authentication barriers."""
    default_user = db.query(User).filter(User.email == "shashank@noteflow.io").first()
    if not default_user:
        default_user = User(
            email="shashank@noteflow.io",
            display_name="Notelekh User",
            hashed_password="workspace_user_active"
        )
        db.add(default_user)
        db.commit()
        db.refresh(default_user)
    return default_user
