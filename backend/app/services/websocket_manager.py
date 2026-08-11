from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: set[WebSocket] = set()
        self.admin_connections: set[WebSocket] = set()

    async def connect(self, websocket: WebSocket, *, is_admin: bool = False) -> None:
        await websocket.accept()
        self.active_connections.add(websocket)
        if is_admin:
            self.admin_connections.add(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        self.active_connections.discard(websocket)
        self.admin_connections.discard(websocket)

    async def broadcast(self, message: dict[str, object]) -> None:
        disconnected: list[WebSocket] = []
        for websocket in tuple(self.active_connections):
            try:
                await websocket.send_json(message)
            except Exception:  # noqa: BLE001 - una conexion rota se descarta
                disconnected.append(websocket)
        for websocket in disconnected:
            self.disconnect(websocket)

    async def broadcast_admins(self, message: dict[str, object]) -> None:
        disconnected: list[WebSocket] = []
        for websocket in tuple(self.admin_connections):
            try:
                await websocket.send_json(message)
            except Exception:  # noqa: BLE001 - una conexion rota se descarta
                disconnected.append(websocket)
        for websocket in disconnected:
            self.disconnect(websocket)


manager = ConnectionManager()
