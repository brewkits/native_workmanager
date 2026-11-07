#!/usr/bin/env python3
"""Reference signer for Remote Trigger signature scheme v2 (stdlib only).

Spec (native_workmanager >= next minor):
  payload fields added by the backend:
    x-native-wm-timestamp   Unix seconds, decimal string
    x-native-wm-nonce       unique string per message (>= 8 chars recommended)
    x-native-wm-signature   "v2=" + lowercase hex(HMAC-SHA256(secret, canonical))
  canonical = "NWM2\\n" + join("\\n", entries)
  entries   = every payload key EXCEPT x-native-wm-signature, sorted by UTF-8 bytes of
              the key; each entry is  <len(key)>:<key><len(value)>:<value>  where len is
              the UTF-8 byte length (length prefixes make the encoding collision-free).
  value     = strings as-is; true/false -> "true"/"false"; null -> "null"; integers in
              decimal; objects/arrays -> compact JSON, keys sorted, no escaped "/",
              non-ASCII kept raw, control chars as \\b \\f \\n \\r \\t or \\u00xx.
              Tip: send non-integral numbers as strings (float text differs per language).
The device rejects a v2 message whose timestamp is more than 300 s away from its clock or
whose nonce it has already accepted inside that window (replay protection).
"""
import hashlib, hmac, json, sys, time, uuid

SIG = "x-native-wm-signature"


def _value(v):
    if isinstance(v, str):
        return v
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    return json.dumps(v, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def canonical(payload):
    entries = []
    for k in sorted((k for k in payload if k != SIG), key=lambda k: k.encode("utf-8")):
        kb, vb = k.encode("utf-8"), _value(payload[k]).encode("utf-8")
        entries.append(f"{len(kb)}:{k}{len(vb)}:{vb.decode('utf-8')}")
    return "NWM2\n" + "\n".join(entries)


def sign(payload, secret, now=None, nonce=None):
    p = dict(payload)
    p["x-native-wm-timestamp"] = str(int(now if now is not None else time.time()))
    p["x-native-wm-nonce"] = nonce or uuid.uuid4().hex
    mac = hmac.new(secret.encode("utf-8"), canonical(p).encode("utf-8"), hashlib.sha256)
    p[SIG] = "v2=" + mac.hexdigest()
    return p


if __name__ == "__main__":
    print(json.dumps(sign(json.loads(sys.argv[1]), sys.argv[2]), indent=2))
