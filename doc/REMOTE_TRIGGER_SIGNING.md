# Remote Trigger signing

How a backend must sign FCM/APNs payloads for a `RemoteTriggerRule` that has a `secretKey`.

## Backend signing (v2, recommended)

Add three fields to the payload. Reference signer: [`doc/examples/remote_trigger_sign_v2.py`](examples/remote_trigger_sign_v2.py).

| Field | Value |
|---|---|
| `x-native-wm-timestamp` | Unix seconds, decimal string |
| `x-native-wm-nonce` | Unique string per message (>= 8 chars; a UUID is fine) |
| `x-native-wm-signature` | `v2=` + lowercase hex `HMAC-SHA256(secret, canonical)` |

`canonical = "NWM2\n" + join("\n", entries)`, where `entries` are all payload keys **except** the signature,
sorted by the UTF-8 bytes of the key, each encoded as `<len(key)>:<key><len(value)>:<value>`
(lengths are UTF-8 byte counts, which makes the encoding collision-free even if values contain `|` or `=`).
Values: strings as-is, `true`/`false`, `null`, integers in decimal; objects/arrays as compact JSON with sorted keys,
no escaped `/`, non-ASCII kept raw. Send non-integral numbers as strings.

The device rejects a message when the signature is wrong, when the timestamp is more than 300 s away from
the device clock, or when the nonce was already accepted within that window (replay protection).
A device with a badly wrong clock will therefore reject valid pushes.

**Example signed payload:**
```json
{
  "type": "sync",
  "data_id": "999",
  "x-native-wm-timestamp": "1700000000",
  "x-native-wm-nonce": "9f1c6e0a4b7d4a52",
  "x-native-wm-signature": "v2=dca042f1..."
}
```

## Legacy v1 (deprecated)
A bare hex signature over `key1=val1|key2=val2` (sorted keys, signature removed) is still accepted so existing
backends keep working, but it has **no replay protection**, and values containing `|`/`=` can collide. Each
accepted v1 message logs a deprecation warning. Plan to migrate to v2.

## Rules without a `secretKey`
A rule with no `secretKey` accepts `native_wm` direct commands from anyone who can deliver a push to the app.
By default this is unchanged for compatibility, but it logs a warning on every such message.

To refuse them instead, opt in per rule:

```dart
RemoteTriggerRule(
  payloadKey: 'type',
  workerMappings: {...},
  rejectUnsignedCommands: true, // only meaningful without a secretKey
)
```

With `secretKey` set, signatures are always enforced and this flag has no effect. Always set a `secretKey` in production.

On iOS, `native_wm` commands are also executed when **no rule is registered at all** (Android ignores them);
that path has no rule to carry the flag, so register a rule for the source if you want it protected.
