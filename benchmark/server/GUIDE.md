# Native WorkManager Test Server Guide

This server is designed to test all scenarios for the native_workmanager library:

- **Download**: Simulate slow network (delay), Resume (Range headers), large files
- **Upload**: Multipart, binary, and simulate slow server processing
- **Sync/Request**: Echo back JSON and headers to verify sent data
- **Edge cases**: Simulate 403, 404, 500 errors, and timeouts

## Running the Server

### Installation

```bash
# Install Flask if not already installed
pip install flask
```

### Start Server

```bash
python benchmark/server/test_server.py
```

### Access URLs

**From emulators/simulators:**
- Android Emulator: `http://10.0.2.2:8080`
- iOS Simulator: `http://127.0.0.1:8080` (or `http://localhost:8080`)
- Physical devices: `http://<YOUR_COMPUTER_IP>:8080` (Computer and phone must be on same WiFi)

## Testing Each Worker Type

### A. HttpDownloadWorker Test

Configure worker to download large files with delays, giving you time to disconnect network or kill app to test resume functionality.

```dart
NativeWorker.httpDownload(
  // Download 50MB file, server will return gradually over 10s
  url: 'http://10.0.2.2:8080/files/50MB.zip',
  savePath: '/path/to/save.zip',
  timeout: Duration(minutes: 5),
)
```

**Test scenarios:**
- **Progress tracking**: Watch progress bar update during throttled download
- **Resume capability**: Kill app mid-download, restart, verify resume from last position
- **Timeout handling**: Use 100MB.zip (30s delay) with short timeout to test timeout behavior

### B. HttpUploadWorker Test

Test file upload with additional form fields.

```dart
NativeWorker.httpUpload(
  url: 'http://10.0.2.2:8080/upload',
  filePath: '/path/to/image.jpg',
  fileFieldName: 'file',
  additionalFields: {
    'user_id': '123',
    'token': 'abc-xyz'
  },
)
```

**What the server validates:**
- File is received correctly
- Form fields are included
- Headers are properly set
- Returns file metadata (name, size, content-type)

### C. HttpSyncWorker Test

Test sending JSON and receiving JSON response.

```dart
NativeWorker.httpSync(
  url: 'http://10.0.2.2:8080/echo',
  method: HttpMethod.post,
  requestBody: {
    'sync_time': DateTime.now().toIso8601String(),
    'data': ['item1', 'item2']
  },
)
```

**What the server returns:**
- Your exact JSON payload
- All headers you sent
- HTTP method used
- Query parameters
- Origin IP

### D. HttpRequestWorker Test (Error Handling)

Test how Native Worker handles various HTTP errors.

```dart
// Test 500 Internal Server Error
NativeWorker.httpRequest(
  url: 'http://10.0.2.2:8080/status/500',
)

// Test 403 Forbidden
NativeWorker.httpRequest(
  url: 'http://10.0.2.2:8080/status/403',
)

// Test 404 Not Found
NativeWorker.httpRequest(
  url: 'http://10.0.2.2:8080/status/404',
)
```

**Verify:**
- Worker properly captures error status codes
- Error messages are descriptive
- Retry logic works as expected

## Why This Test Server?

### 1. Automatic Test Data Generation

The `setup_files()` function automatically creates dummy files (1MB, 10MB, 50MB) when server starts. No manual file copying needed.

### 2. Network Throttling

The `FILE_DELAYS` configuration simulates slow networks:

```python
FILE_DELAYS = {
    '10MB.zip': 2.0,   # Download in ~2s
    '50MB.zip': 10.0,  # Download in ~10s
    '100MB.zip': 30.0, # Download in ~30s
}
```

**Use cases:**
- Verify progress bar updates smoothly
- Test timeout functionality
- Test user cancellation during long operations

### 3. Resume Download Support

The Range header logic in `serve_file()` function is core to testing resume functionality that background_downloader has. If your Native Worker sends the correct `Range: bytes=100-` header, this server will understand and return the remaining portion.

**How to test:**
1. Start downloading a 50MB file
2. Kill the app at 50% progress
3. Restart app and resume
4. Server should return 206 Partial Content with correct range

### 4. Detailed Logging

Server logs every request, helping you debug whether Native code is sending correct headers/body.

```
📥 POST /upload - user_id: 123, file: photo.jpg (2.5MB)
📤 GET /files/10MB.zip - Range: bytes=5242880-
✅ 206 Partial Content - Serving bytes 5242880-10485759
```

## Running Tests

### Unit Tests

```bash
python benchmark/server/test_server_test.py
```

### Why Tests Are Important

**Validation "Benchmark"**: If Native Worker download is slow or resume fails, you need to know if the issue is in your Native code or the test server. This test file proves the server works correctly (correct range handling, correct delays).

**CI/CD Integration**: You can include this in your CI pipeline. Before running Flutter integration tests, the system will automatically run these server tests to ensure the environment is clean.

**Learn Architecture**: How background_downloader does testing is very rigorous (Test Server → Test Client → Test Library). Applying this model will elevate your library quality to professional level.

## Server Endpoints Reference

### Health Check
- **Endpoint**: `GET /`
- **Returns**: "Native WorkManager Test Server is Running!"

### File Download (with Resume)
- **Endpoint**: `GET /files/<filename>`
- **Supports**: Range headers for resume
- **Files**: 1MB.zip, 10MB.zip, 50MB.zip
- **Returns**: File with simulated delay

### File Upload
- **Endpoint**: `POST /upload`
- **Expects**: Multipart form data with 'file' field
- **Returns**: JSON with file info and form fields

### Echo (Request/Sync)
- **Endpoint**: `GET|POST|PUT|DELETE|PATCH /echo`
- **Returns**: Everything you sent (method, headers, body, query params)

### Status Code Simulation
- **Endpoint**: `GET /status/<code>`
- **Example**: `/status/500`, `/status/403`, `/status/404`
- **Returns**: Specified HTTP status code

### Redirect Test
- **Endpoint**: `GET /redirect-to?url=<target>&status=<code>`
- **Example**: `/redirect-to?url=/echo&status=302`
- **Returns**: Redirect to target URL

## Troubleshooting

### Cannot connect from Android Emulator
- Use `http://10.0.2.2:8080` (NOT `localhost` or `127.0.0.1`)
- Ensure server is running on host machine

### Cannot connect from iOS Simulator
- Use `http://127.0.0.1:8080` or `http://localhost:8080`
- Check firewall settings on Mac

### Cannot connect from Physical Device
- Ensure phone and computer are on same WiFi network
- Find computer's IP: `ifconfig` (Mac/Linux) or `ipconfig` (Windows)
- Use `http://<COMPUTER_IP>:8080`
- Check firewall allows connections on port 8080

### Server starts but tests fail
- Check if port 8080 is already in use
- Try different port: Edit `PORT = 8080` in test_server.py
- Update test URLs accordingly

## Advanced Usage

### Custom File Delays

Edit `FILE_DELAYS` in test_server.py:

```python
FILE_DELAYS = {
    '10MB.zip': 5.0,   # Slower: 5 seconds
    '50MB.zip': 20.0,  # Much slower
}
```

### Add Larger Test Files

Uncomment in `setup_files()`:

```python
create_dummy_file('100MB.zip', 100)
create_dummy_file('500MB.zip', 500)  # For stress testing
```

### Custom Endpoints

Add your own test endpoints:

```python
@app.route('/custom-test')
def custom_test():
    # Your test logic
    return jsonify({'status': 'ok'})
```

## Production Considerations

**⚠️ Warning**: This is a TEST server only. Do NOT use in production:
- No authentication/authorization
- No rate limiting
- No input validation
- No security hardening
- Uses development Flask server (not production WSGI)

For production, use proper frameworks like:
- Flask + Gunicorn/uWSGI
- Django
- FastAPI
- Express.js
