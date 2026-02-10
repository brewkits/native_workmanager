from flask import Flask, request, Response, jsonify, send_from_directory, stream_with_context, redirect
import time
import os
import json
import logging
import random
import string

app = Flask(__name__)

# --- CONFIGURATION ---
PORT = 8080
# Directory containing test files for download
FILES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'files')

# Configure delay for each file (simulate slow network to test Progress/Timeout)
# Unit: seconds
FILE_DELAYS = {
    '10MB.zip': 2.0,   # Download in ~2s
    '50MB.zip': 10.0,  # Download in ~10s
    '100MB.zip': 30.0, # Download in ~30s (Test timeout)
}

# --- HELPERS ---

def create_dummy_file(filename, size_in_mb):
    """Create dummy file with specific size if it doesn't exist"""
    path = os.path.join(FILES_DIR, filename)
    if not os.path.exists(path):
        print(f"Generating {filename} ({size_in_mb} MB)...")
        with open(path, 'wb') as f:
            f.write(os.urandom(size_in_mb * 1024 * 1024))

def setup_files():
    """Initialize directory and test files"""
    if not os.path.exists(FILES_DIR):
        os.makedirs(FILES_DIR)

    create_dummy_file('1MB.zip', 1)
    create_dummy_file('10MB.zip', 10)
    create_dummy_file('50MB.zip', 50)
    # create_dummy_file('100MB.zip', 100)  # Uncomment if need to test large files

# --- ROUTES ---

@app.route('/')
def index():
    return "Native WorkManager Test Server is Running!"

# 1. DOWNLOAD WORKER TEST
@app.route('/files/<path:filename>')
def serve_file(filename):
    """
    Serve file downloads with capabilities:
    - Simulate slow network (Delay)
    - Support Resume (Range Headers)
    """
    file_path = os.path.join(FILES_DIR, filename)
    if not os.path.exists(file_path):
        return Response("File not found", 404)

    total_size = os.path.getsize(file_path)
    chunk_size = 64 * 1024  # 64KB chunks

    # Handle Range Header (for Resume Download feature)
    range_header = request.headers.get('Range', None)
    start_byte = 0
    end_byte = total_size - 1
    status_code = 200

    if range_header:
        try:
            range_val = range_header.replace('bytes=', '')
            parts = range_val.split('-')
            if parts[0]:
                start_byte = int(parts[0])
            if len(parts) > 1 and parts[1]:
                end_byte = int(parts[1])
            status_code = 206  # Partial Content
        except Exception as e:
            print(f"Range parse error: {e}")

    content_length = end_byte - start_byte + 1
    target_duration = FILE_DELAYS.get(filename, 0)

    def generate():
        with open(file_path, 'rb') as f:
            f.seek(start_byte)
            bytes_to_send = content_length

            # Calculate delay per chunk
            num_chunks = (bytes_to_send + chunk_size - 1) // chunk_size
            delay_per_chunk = target_duration / num_chunks if num_chunks > 0 else 0

            while bytes_to_send > 0:
                read_size = min(chunk_size, bytes_to_send)
                chunk = f.read(read_size)
                if not chunk:
                    break

                yield chunk

                bytes_to_send -= len(chunk)
                if delay_per_chunk > 0:
                    time.sleep(delay_per_chunk)  # Simulate slow network

    headers = {
        'Content-Type': 'application/octet-stream',
        'Accept-Ranges': 'bytes',
        'Content-Length': str(content_length),
        'Content-Disposition': f'attachment; filename={filename}'
    }

    if status_code == 206:
        headers['Content-Range'] = f'bytes {start_byte}-{end_byte}/{total_size}'

    return Response(stream_with_context(generate()), status=status_code, headers=headers)

# 2. UPLOAD WORKER TEST (Multipart)
@app.route('/upload', methods=['POST'])
def upload_file():
    """
    Test HttpUploadWorker.
    Server receives file and returns information about the received file.
    """
    # Simulate server processing delay
    time.sleep(1)

    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    # Read accompanying form fields
    form_data = request.form.to_dict()

    # Read headers
    headers = dict(request.headers)

    return jsonify({
        'status': 'success',
        'filename': file.filename,
        'content_type': file.content_type,
        'size': len(file.read()),  # Read to get size (in production should save)
        'form_fields': form_data,
        'headers_received': headers
    })

# 3. REQUEST & SYNC WORKER TEST (Echo)
@app.route('/echo', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
def echo():
    """
    Test HttpRequestWorker & HttpSyncWorker.
    Returns everything the client sends (similar to httpbin.org)
    """
    # Simulate random delay (0.1s - 0.5s)
    time.sleep(random.uniform(0.1, 0.5))

    data = None
    json_body = None

    try:
        if request.is_json:
            json_body = request.json
        else:
            data = request.data.decode('utf-8')
    except:
        pass

    return jsonify({
        'method': request.method,
        'url': request.url,
        'headers': dict(request.headers),
        'args': request.args,  # Query params
        'form': request.form,  # Form data
        'data': data,          # Raw body
        'json': json_body,     # JSON body
        'origin': request.remote_addr
    })

# 4. STATUS CODE TEST (Error handling)
@app.route('/status/<int:code>')
def status_code(code):
    """
    Test error handling: Returns specific status code (401, 403, 500...)
    """
    return Response(f"Simulated {code}", status=code)

# 5. REDIRECT TEST
@app.route('/redirect-to')
def redirect_to():
    """
    Test redirect follow capability
    Query: ?url=/echo&status=302
    """
    target = request.args.get('url', '/echo')
    status = int(request.args.get('status', 302))
    return redirect(target, code=status)

if __name__ == '__main__':
    setup_files()
    print(f"🚀 Test Server running on http://0.0.0.0:{PORT}")
    print(f"📂 Files directory: {FILES_DIR}")
    # threaded=True to handle multiple concurrent requests (parallel upload/download)
    app.run(host='0.0.0.0', port=PORT, threaded=True)