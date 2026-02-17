# iOS Supabase Response Format: join_rally (Fehleranalyse und Best Practices)

## Problemstellung

Die Fehlermeldung `data couldn't be read` beim Aufruf von Supabase-Funktionen (z.B. `join_rally`) auf dem iPhone bedeutet fast immer, dass das empfangene JSON nicht exakt zum erwarteten Swift-Model passt. Typische Ursachen:
- **Falsche Feldnamen** (z.B. `rally_id` vs. `rallyId`)
- **Falsche Struktur** (Array vs. Objekt)
- **Optionalität** (fehlende oder unerwartete Felder)

---

## 1. Erwartetes Swift-Model (Beispiel)

Die Antwort von `join_rally` wird in ein Swift-Struct decodiert. Typisch sieht das so aus:

```swift
struct JoinRallyResponse: Codable {
    let rally_id: String
    let participant_id: String
}
```

**Wichtig:**
- Die Feldnamen sind in `snake_case` (wie im Supabase-JSON)
- Wenn du camelCase verwendest, brauchst du explizite CodingKeys:

```swift
struct JoinRallyResponse: Codable {
    let rallyId: String
    let participantId: String
    enum CodingKeys: String, CodingKey {
        case rallyId = "rally_id"
        case participantId = "participant_id"
    }
}
```

---

## 2. Supabase-Aufruf in Swift

Der typische Aufruf sieht so aus:

```swift
let response: [JoinRallyResponse] = try await supabase
    .database
    .rpc("join_rally", params: [
        "p_code": code,
        "p_device_id": deviceId,
        "p_platform": "ios",
        "p_display_name": displayName
    ])
    .execute()
    .value
```

- **Array**: Wenn die Funktion `RETURNS TABLE(...)` verwendet, gibt Supabase ein Array zurück.
- **Objekt**: Wenn du `.single()` verwendest, muss die Funktion ein einzelnes Objekt zurückgeben (kein Array).

**Beispiel für .single():**
```swift
let response: JoinRallyResponse = try await supabase
    .database
    .rpc("join_rally", params: [...])
    .single()
    .execute()
    .value
```

---

## 3. Typische Fehlerquellen

- **Feldnamen stimmen nicht überein**: `rally_id` im JSON, aber `rallyId` im Swift-Struct ohne CodingKeys → Fehler.
- **Array vs. Objekt**: Swift erwartet ein Objekt, Supabase liefert ein Array → Fehler.
- **Optionalität**: Swift erwartet ein Feld, das im JSON fehlt → Fehler.

---

## 4. Beispiel: Supabase SQL-Funktion

**Aktuell sendet Supabase:**
```json
[
  { "rally_id": "uuid...", "participant_id": "uuid..." }
]
```

**Das erwartet Swift:**
- **Array**: `[JoinRallyResponse]`
- **Objekt**: `JoinRallyResponse` (nur mit `.single()` und entsprechendem SQL-RETURN)

**SQL für Array:**
```sql
RETURNS TABLE(rally_id UUID, participant_id UUID)
```

**SQL für einzelnes Objekt:**
```sql
RETURNS record
...
RETURN QUERY SELECT v_rally_id, v_participant_id;
```

---

## 5. Best Practices für Cross-Platform Kompatibilität

- **Immer snake_case** in SQL und Swift-Structs verwenden, wenn kein explizites Mapping.
- **Array vs. Objekt**: Passe das SQL und den Swift-Code aneinander an.
    - Für Arrays: `[JoinRallyResponse]`
    - Für Einzelobjekte: `.single()` und `JoinRallyResponse`
- **Fehlende Felder**: Felder im Swift-Struct als optional (`String?`), wenn sie nicht garantiert im JSON sind.
- **Testen**: Immer mit echten Supabase-Responses testen (z.B. mit Postman oder curl).

---

## 6. Fazit & Empfehlung

- Prüfe immer die Feldnamen und die Struktur (Array vs. Objekt)!
- Passe das SQL-Skript so an, dass es exakt das liefert, was das Swift-Struct erwartet.
- Nutze snake_case für maximale Kompatibilität.
- Bei Unsicherheit: Lass dir das tatsächliche JSON von Supabase ausgeben und vergleiche es mit dem Swift-Struct.

---

## 7. Beispiel für vollständige Kompatibilität

**Swift-Struct:**
```swift
struct JoinRallyResponse: Codable {
    let rally_id: String
    let participant_id: String
}
```

**Supabase SQL:**
```sql
RETURNS TABLE(rally_id UUID, participant_id UUID)
...
RETURN QUERY SELECT v_rally_id, v_participant_id;
```

**Swift-Aufruf:**
```swift
let response: [JoinRallyResponse] = try await supabase
    .database
    .rpc("join_rally", params: [...])
    .execute()
    .value
```

ODER (für einzelnes Objekt):

**Swift-Struct:**
```swift
struct JoinRallyResponse: Codable {
    let rally_id: String
    let participant_id: String
}
```

**Supabase SQL:**
```sql
RETURNS record
...
RETURN QUERY SELECT v_rally_id, v_participant_id;
```

**Swift-Aufruf:**
```swift
let response: JoinRallyResponse = try await supabase
    .database
    .rpc("join_rally", params: [...])
    .single()
    .execute()
    .value
```

---

**Tipp:**
Wenn du die tatsächliche JSON-Antwort sehen willst, logge sie vor dem Decoding:
```swift
let raw = try await supabase.database.rpc(...).execute().raw
print(String(data: raw, encoding: .utf8) ?? "")
```

So kannst du exakt sehen, was Supabase liefert und das Swift-Struct anpassen.
