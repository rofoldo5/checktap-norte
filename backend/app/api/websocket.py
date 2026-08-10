from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.database import SessionLocal
from app.core.security import decode_access_token
from app.models.user import ACCOUNT_STATUS_APPROVED, User
from app.services.websocket_manager import manager

router = APIRouter(tags=["websocket"])


@router.websocket("/ws/tasks")
async def tasks_websocket(websocket: WebSocket, token: str) -> None:
    user_id = decode_access_token(token)
    if user_id is None:
        await websocket.close(code=4401)
        return

    with SessionLocal() as db:
        user = db.get(User, user_id)
        if (
            user is None
            or not user.is_active
            or user.account_status != ACCOUNT_STATUS_APPROVED
        ):
            await websocket.close(code=4401)
            return

    await manager.connect(websocket)
    try:
        await websocket.send_json({"event": "connected"})
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
