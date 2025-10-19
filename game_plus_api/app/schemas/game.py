from pydantic import BaseModel, HttpUrl
from typing import Optional

class GamePublic(BaseModel):
    id: int
    name: str
    description: Optional[str]
    thumbnail_url: Optional[HttpUrl]
    class Config:
        orm_mode = True
