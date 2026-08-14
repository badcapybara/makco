{
  "project": "Makco",
  "description": "Chennai Metro booking app - reverse-engineered Namma Yatri/Chennai One",
  "github": {
    "repo": "https://github.com/pandatern/makco",
    "owner": "pandatern",
    "branch": "main"
  },
  "endpoints": {
    "api": "https://api.pandatern.tech",
    "local_backend": "http://127.0.0.1:8080"
  },
  "backend": {
    "language": "Nim",
    "framework": "Prologue",
    "entry": "backend/src/makco.nim",
    "build": "cd backend/src && nim c -d:ssl -d:release -o:makco makco.nim",
    "run": "./backend/src/makco",
    "admin_token": "admin_token_6374746721",
    "payment_skip": "only for exact admin token"
  },
  "frontend": {
    "platform": "Android",
    "build": "cd frontend/android && ./gradlew assembleRelease",
    "api_base": "https://api.pandatern.tech"
  },
  "workflows": {
    "android_build": ".github/workflows/build-android.yml",
    "backend_build": ".github/workflows/build-backend.yml"
  }
}