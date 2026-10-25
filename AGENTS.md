{
  "project": "Makco",
  "description": "Chennai Metro booking app - reverse-engineered Namma Yatri/Chennai One",
  "github": {
    "repo": "https://github.com/badcapybara/makco",
    "owner": "badcapybara",
    "branch": "main"
  },
  "endpoints": {
    "api": "http://163.123.236.154:8080",
    "local_backend": "http://127.0.0.1:8080"
  },
  "backend": {
    "language": "Rust",
    "framework": "axum",
    "entry": "backend/src/main.rs",
    "build": "cd backend && cargo build --release",
    "run": "systemctl restart makco (binary backend/target/release/makco on :8080)",
    "payment": "universal; every account completes Juspay before a ticket is issued (no admin or mock bypass)"
  },
  "frontend": {
    "platform": "Android",
    "build": "cd frontend/flutter && flutter build apk --release",
    "api_base": "http://163.123.236.154:8080",
    "state": "Riverpod 3",
    "routing": "go_router",
    "version": "3.3.1+331"
  },
  "deploy": {
    "service": "makco.service",
    "downloads": "http://163.123.236.154/app-release.apk",
    "web_root": "/var/www/makco"
  }
}
