# Test Server for native_workmanager

A Flask-based local HTTP server for testing all native_workmanager Worker types (Download, Upload, Request, Sync).

## Quick Start

```bash
# Install dependencies
pip install flask

# Run server
python test_server.py

# Run tests (in another terminal)
python test_server_test.py
```

## What's Included

- **test_server.py** - Main Flask server with all test endpoints
- **test_server_test.py** - Unit tests validating server functionality
- **GUIDE.md** - Comprehensive usage guide with examples
- **files/** - Auto-generated test files (1MB, 10MB, 50MB)

## Key Features

✅ **Resume Downloads** - Full Range header support for download resumption
✅ **Network Throttling** - Configurable delays to simulate slow networks
✅ **Multipart Upload** - Test file uploads with form fields
✅ **Echo Endpoint** - Validates all request data (headers, body, params)
✅ **Error Simulation** - Test 403, 404, 500 status codes
✅ **Auto File Generation** - Creates test files automatically on startup

## Server Endpoints

| Endpoint | Purpose | Method |
|----------|---------|--------|
| `/` | Health check | GET |
| `/files/<filename>` | Download with resume support | GET |
| `/upload` | Multipart file upload | POST |
| `/echo` | Echo request data back | GET/POST/PUT/DELETE/PATCH |
| `/status/<code>` | Simulate HTTP status codes | GET |
| `/redirect-to` | Test redirect handling | GET |

## Connection URLs

**From Android Emulator:**
```
http://10.0.2.2:8080
```

**From iOS Simulator:**
```
http://127.0.0.1:8080
```

**From Physical Device (same WiFi):**
```
http://<YOUR_COMPUTER_IP>:8080
```

## Example Usage

### Test Download with Resume

```dart
await NativeWorkManager.enqueue(
  NativeWorker.httpDownload(
    url: 'http://10.0.2.2:8080/files/50MB.zip',
    savePath: '/path/to/save.zip',
  ),
);
```

### Test Upload with Form Data

```dart
await NativeWorkManager.enqueue(
  NativeWorker.httpUpload(
    url: 'http://10.0.2.2:8080/upload',
    filePath: '/path/to/photo.jpg',
    additionalFields: {'user_id': '123'},
  ),
);
```

### Test Request/Sync

```dart
await NativeWorkManager.enqueue(
  NativeWorker.httpSync(
    url: 'http://10.0.2.2:8080/echo',
    method: HttpMethod.post,
    requestBody: {'data': 'test'},
  ),
);
```

## Running Tests

```bash
# Run all unit tests
python test_server_test.py

# Expected output:
# 🚀 Test Environment Started on http://127.0.0.1:8081
# .......
# ----------------------------------------------------------------------
# Ran 7 tests in XXs
# OK
```

## Configuration

### Custom Delays

Edit `FILE_DELAYS` in `test_server.py`:

```python
FILE_DELAYS = {
    '10MB.zip': 2.0,   # 2 seconds
    '50MB.zip': 10.0,  # 10 seconds
}
```

### Custom Port

```python
PORT = 8080  # Change to any available port
```

## Why This Server?

This test server is inspired by [background_downloader](https://github.com/781flyingdutchman/background_downloader)'s rigorous testing approach:

1. **Validates native code behavior** - Ensures Workers send correct headers/body
2. **Tests edge cases** - Resume, timeouts, errors, slow networks
3. **CI/CD ready** - Can be integrated into automated test pipelines
4. **Educational** - Learn professional library testing patterns

## Troubleshooting

**Port already in use:**
```bash
lsof -ti:8080 | xargs kill  # macOS/Linux
netstat -ano | findstr :8080  # Windows
```

**Can't connect from emulator:**
- Android: Must use `10.0.2.2`, not `localhost`
- iOS: Use `127.0.0.1` or `localhost`

**Files not generating:**
- Check disk space (needs ~61MB for default files)
- Check write permissions in `benchmark/server/files/`

## Architecture

```
benchmark/server/
├── test_server.py          # Main Flask server
├── test_server_test.py     # Unit tests
├── GUIDE.md                # Detailed usage guide
├── README.md               # This file
└── files/                  # Auto-generated test files
    ├── 1MB.zip
    ├── 10MB.zip
    └── 50MB.zip
```

## Contributing

When adding new endpoints:

1. Add route handler in `test_server.py`
2. Add corresponding test in `test_server_test.py`
3. Update `GUIDE.md` with usage examples
4. Run tests to verify: `python test_server_test.py`

## Production Warning

⚠️ **This is a TEST server only**. Do NOT deploy to production:
- No authentication
- No rate limiting
- No input validation
- Development server (not production WSGI)

For production apps, use proper backend frameworks with security hardening.

## License

Part of the [native_workmanager](https://github.com/your-repo/native_workmanager) project.
