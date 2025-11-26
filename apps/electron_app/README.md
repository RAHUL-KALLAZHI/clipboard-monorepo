# Clipboard Desktop (Electron) - with QR generation

## Quick start

1. Install dependencies:
   ```
   npm install
   ```

2. Run the app:
   ```
   npm start
   ```

## Environment
- By default the app expects backend server at http://localhost:3000
- To change server URL:
  ```
  SERVER=http://your.server:3000 npm start
  ```

## Notes
- This project uses `qrcode` package in the preload to generate a data URL for the QR image.
- The app creates a pairing code and shows a QR image encoding JSON: {"pairingId": "...", "code": "123456"}.
- After a mobile device confirms pairing (calls /pair/confirm), the server will emit `paired` to this app and it will start authenticated socket and poll clipboard.
