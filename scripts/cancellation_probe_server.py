#!/usr/bin/env python3 -I
"""Local probe server for scripts/android-cancellation-check.sh (stdlib only).

 :8765  WebSocket  - completes the handshake, sends nothing, logs open/close times.
 :8766  HTTP POST  - drains the body slowly (so an upload stays in flight), logs the
                     bytes received before the peer went away.
Events are appended as JSON lines to the file given as argv[1].
"""
import base64, hashlib, json, socket, sys, threading, time

LOG = sys.argv[1]
lock = threading.Lock()


def log(**kw):
    kw["t"] = time.time()
    with lock, open(LOG, "a") as f:
        f.write(json.dumps(kw) + "\n")


def read_headers(conn):
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = conn.recv(4096)
        if not chunk:
            return None, b""
        buf += chunk
    head, _, rest = buf.partition(b"\r\n\r\n")
    return head.decode("latin1"), rest


def ws_client(conn):
    head, _ = read_headers(conn)
    if head is None:
        return
    key = next(l.split(":", 1)[1].strip() for l in head.split("\r\n") if l.lower().startswith("sec-websocket-key"))
    acc = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
    conn.sendall(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                  f"Sec-WebSocket-Accept: {acc}\r\n\r\n").encode())
    log(ev="ws_open")
    # OkHttp answers cancellation with a CLOSE frame and then waits for the server to
    # finish the handshake, so "closed" means: we saw opcode 0x8 (or EOF).
    try:
        while True:
            data = conn.recv(4096)
            if not data:
                break
            if data[0] & 0x0F == 0x8:
                log(ev="ws_close_frame")
                conn.sendall(b"\x88\x00")
                break
    except OSError:
        pass
    log(ev="ws_close")
    conn.close()


def upload_client(conn):
    head, rest = read_headers(conn)
    if head is None:
        return
    length = 0
    for l in head.split("\r\n"):
        if l.lower().startswith("content-length"):
            length = int(l.split(":", 1)[1])
    got = len(rest)
    log(ev="up_open", length=length)
    try:
        while got < length:
            chunk = conn.recv(16384)
            if not chunk:
                break
            got += len(chunk)
            time.sleep(0.04)  # ~0.4 MB/s: a 12 MB body stays in flight for ~30 s
    except OSError:
        pass
    complete = got >= length
    log(ev="up_close", got=got, length=length, complete=complete)
    if complete:
        conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
    conn.close()


def serve(port, handler):
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", port))
    s.listen(8)
    while True:
        c, _ = s.accept()
        threading.Thread(target=handler, args=(c,), daemon=True).start()


threading.Thread(target=serve, args=(8765, ws_client), daemon=True).start()
log(ev="ready")
serve(8766, upload_client)
