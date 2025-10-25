import asyncio
import json
import random
import websockets

WS_URL = "ws://localhost:8000/ws/match/3?token="
TOKEN_A = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0IiwiaWF0IjoxNzYxMjc5MTk0LCJleHAiOjE3NjcyNzkxMzR9.OJGPacM8mqLRGyHHsUjCJjIVM4emG39XLGZw3wkCTCg"  # user A (sẽ thành X)
TOKEN_B = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiaWF0IjoxNzYxMjc5MTk5LCJleHAiOjE3NjcyNzkxMzl9.IOTl1i76oD_--xd0xzyYexQgkWDOjPqoWKHxNFreksg"  # user B (sẽ thành O)

BOARD_ROWS, BOARD_COLS = 15, 19

class AutoPlayer:
    def __init__(self, name, token, expected_symbol):
        self.name = name
        self.token = token
        self.expected_symbol = expected_symbol  # chỉ để log kỳ vọng
        self.ws = None

        self.symbol = None        # X | O (nhận từ "joined")
        self.turn = "X"
        self.board = [["" for _ in range(BOARD_COLS)] for _ in range(BOARD_ROWS)]
        self.finished = False
        self.winner_id = None
        self.draw_reason = None

    async def connect(self):
        uri = WS_URL + self.token
        self.ws = await websockets.connect(uri)
        print(f"✅ {self.name} connected (expect {self.expected_symbol})")

    def _print_board(self, title="\n📋 Final Board State:"):
        print(title)
        for x in range(BOARD_ROWS):
            row = " ".join(self.board[x][y] if self.board[x][y] else "·" for y in range(BOARD_COLS))
            print(f"{x:02d} {row}")
        print("-" * (BOARD_COLS * 2 + 3))

    async def handle_message(self, raw):
        data = json.loads(raw)
        t = data.get("type")
        p = data.get("payload", {})

        if t == "joined":
            you = p.get("you", {})
            self.symbol = you.get("symbol")
            self.turn = p.get("turn", "X")
            print(f"{self.name}: joined as {self.symbol} (turn={self.turn})")

        elif t == "start":
            self.turn = p.get("turn", self.turn)
            players = p.get("players", [])
            print(f"{self.name}: game START, turn={self.turn}, players={players}")

        elif t == "move":
            x, y, s = p["x"], p["y"], p["symbol"]
            self.board[x][y] = s               # ✅ chỉ update khi SERVER xác nhận
            self.turn = p["next_turn"]
            print(f"{self.name} saw move {s} at ({x},{y}), next={self.turn}")

        elif t == "win":
            self.winner_id = p["winner_user_id"]
            self.finished = True
            print(f"🏁 {self.name} detected WINNER = {self.winner_id}")

        elif t == "draw":
            self.draw_reason = p.get("reason", "board_full")
            self.finished = True
            print(f"🤝 {self.name} detected DRAW reason={self.draw_reason}")

        elif t == "error":
            # In lỗi từ server (vd: Not your turn, Invalid cell, ...)
            err = p if isinstance(p, str) else p.get("message", p)
            print(f"⚠️ {self.name} ERROR: {err}")

        elif t == "chat":
            # optional
            pass

        elif t == "pong":
            pass

        else:
            print(f"{self.name} got unknown msg: {data}")

    def _find_empty_random(self):
        cells = [(x, y) for x in range(BOARD_ROWS) for y in range(BOARD_COLS) if not self.board[x][y]]
        return random.choice(cells) if cells else None

    async def play_loop(self):
        try:
            while not self.finished:
                raw = await self.ws.recv()
                await self.handle_message(raw)

                if self.finished:
                    break  # 🧠 stop ngay khi có win/draw

                # chỉ đánh khi: 1) chưa kết thúc, 2) đã có symbol, 3) đúng lượt mình
                if self.symbol and self.turn == self.symbol:
                    await asyncio.sleep(0.1)     # delay nhẹ
                    if self.finished:
                        break  # 🧠 kiểm tra lại sau delay

                    cell = self._find_empty_random()
                    if not cell:
                        print(f"{self.name}: no empty cell (should draw soon)")
                        break
                    x, y = cell
                    await self.ws.send(json.dumps({"type": "move", "payload": {"x": x, "y": y}}))
                    print(f"➡️ {self.name} ({self.symbol}) TRY move at ({x},{y})")
        except websockets.exceptions.ConnectionClosed:
            print(f"🔌 {self.name} disconnected")

        self._print_board()


async def main():
    a = AutoPlayer("PlayerA", TOKEN_A, "X")
    b = AutoPlayer("PlayerB", TOKEN_B, "O")

    await asyncio.gather(a.connect(), b.connect())
    await asyncio.gather(a.play_loop(), b.play_loop())

    print("\n🎯 RESULT:")
    if a.winner_id:
        print(f"🏆 Winner user_id = {a.winner_id}")
    elif a.draw_reason:
        print(f"🤝 Draw reason = {a.draw_reason}")
    print("✅ Game finished.\n")

if __name__ == "__main__":
    asyncio.run(main())
