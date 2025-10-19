from fastapi.middleware.cors import CORSMiddleware

def setup_cors(app):
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # ⚠️ dev mode, sau này giới hạn domain
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
