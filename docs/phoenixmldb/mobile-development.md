---
title: Mobile Development
description: PhoenixmlDb on .NET MAUI, iOS, Android, and offline-first patterns
sort: 13
---

# Mobile Development

PhoenixmlDb provides comprehensive mobile support with multiple SDK options for iOS and Android.

## SDK Options

| Platform | SDK | Language | Package |
|----------|-----|----------|---------|
| iOS/Android (.NET) | PhoenixmlDb.Mobile | C# | NuGet |
| iOS (Native) | phoenixml-ios | Swift | Swift Package |
| Android (Native) | phoenixml-android | Kotlin | Maven/Gradle |
| Any Platform | REST API | HTTP/JSON | N/A |

## .NET MAUI / Xamarin

### NuGet Installation

```bash
dotnet add package PhoenixmlDb.Mobile
```

### Basic Usage

```csharp
using PhoenixmlDb.Mobile;

// Create database connection
var db = new MobileDatabase(new MobileDatabaseOptions
{
    ServerAddress = "https://your-server.com:5000",
    EnableOfflineMode = true
});

// Connect and use
await db.ConnectAsync();
var container = await db.OpenContainerAsync("mydata");
await container.PutXmlDocumentAsync("user.xml", "<user><name>John</name></user>");
```

### MAUI Integration

```csharp
// In MauiProgram.cs
builder.Services.AddPhoenixmlDb(options =>
{
    options.ServerAddress = "https://your-server.com:5000";
    options.EnableOfflineMode = true;
});
```

## Native iOS (Swift)

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/endpointsystems/phoenixml-ios.git", from: "1.0.0")
]
```

### Basic Usage

```swift
import PhoenixmlDb

// Create database
let db = PhoenixmlDatabase(
    serverAddress: "your-server.com",
    options: DatabaseOptions(
        port: 5000,
        enableOfflineMode: true
    )
)

// Connect and use
try await db.connect()
let container = try await db.openContainer(name: "mydata")

// Store documents
try await container.putXmlDocument(
    name: "user.xml",
    xml: "<user><name>John</name></user>"
)

// Retrieve documents
if let xml = try await container.getXmlDocument(name: "user.xml") {
    print(xml)
}

// Store Codable objects
struct User: Codable {
    let name: String
    let email: String
}

let user = User(name: "John", email: "john@example.com")
try await container.putDocument(name: "user.json", object: user)
```

### SwiftUI Integration

```swift
@MainActor
class DatabaseViewModel: ObservableObject {
    private let database: PhoenixmlDatabase
    @Published var isConnected = false

    init() {
        database = PhoenixmlDatabase(
            serverAddress: "your-server.com",
            options: .default
        )
    }

    func connect() async {
        do {
            try await database.connect()
            isConnected = database.isConnected
        } catch {
            print("Connection failed: \(error)")
        }
    }
}
```

## Native Android (Kotlin)

### Installation

Add to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.phoenixml:phoenixml-android:1.0.0")
}
```

### Basic Usage

```kotlin
import com.phoenixml.db.*

// Create database
val db = PhoenixmlDatabase.create(
    context = applicationContext,
    serverAddress = "your-server.com",
    options = DatabaseOptions(
        port = 5000,
        enableOfflineMode = true
    )
)

// Connect and use
lifecycleScope.launch {
    db.connect()

    val container = db.openContainer("mydata")

    // Store documents
    container.putXmlDocument(
        name = "user.xml",
        xml = "<user><name>John</name></user>"
    )

    // Retrieve documents
    val xml = container.getXmlDocument("user.xml")

    // Store data classes
    @Serializable
    data class User(val name: String, val email: String)

    container.putDocument("user.json", User("John", "john@example.com"))
}
```

### Connection State

```kotlin
// Observe connection state
lifecycleScope.launch {
    db.connectionState.collect { state ->
        when (state) {
            ConnectionState.CONNECTED -> showConnected()
            ConnectionState.CONNECTING -> showConnecting()
            ConnectionState.DISCONNECTED -> showDisconnected()
        }
    }
}
```

### Jetpack Compose

```kotlin
@Composable
fun DatabaseScreen(db: PhoenixmlDatabase) {
    val connectionState by db.connectionState.collectAsState()

    Column {
        Text("Status: ${connectionState.name}")

        Button(onClick = {
            scope.launch { db.connect() }
        }) {
            Text("Connect")
        }
    }
}
```

## REST API

For platforms without a native SDK, use the REST API directly.

### Base URL

```
https://your-server.com:5000/api
```

### Endpoints

#### Health Check

```http
GET /api/health
```

#### Containers

```http
GET    /api/containers              # List containers
POST   /api/containers              # Create container
GET    /api/containers/{name}       # Get container info
DELETE /api/containers/{name}       # Delete container
```

#### Documents

```http
GET    /api/containers/{container}/documents              # List documents
POST   /api/containers/{container}/documents              # Create document
GET    /api/containers/{container}/documents/{name}       # Get document
PUT    /api/containers/{container}/documents/{name}       # Update document
DELETE /api/containers/{container}/documents/{name}       # Delete document
GET    /api/containers/{container}/documents/{name}/content  # Get raw content
```

#### Queries

```http
POST /api/query          # Execute XQuery
POST /api/query/explain  # Explain query plan
POST /api/query/stream   # Streaming query (SSE)
```

### Examples

#### Create a Document (cURL)

```bash
curl -X POST https://your-server.com:5000/api/containers/mydata/documents \
  -H "Content-Type: application/json" \
  -d '{
    "name": "user.xml",
    "content": "<user><name>John</name></user>",
    "format": "xml"
  }'
```

#### Execute Query

```bash
curl -X POST https://your-server.com:5000/api/query \
  -H "Content-Type: application/json" \
  -d '{
    "container": "mydata",
    "query": "for $u in //user return $u/name/text()"
  }'
```

#### JavaScript/TypeScript

```typescript
const api = 'https://your-server.com:5000/api';

// Create document
await fetch(`${api}/containers/mydata/documents`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    name: 'user.json',
    content: JSON.stringify({ name: 'John' }),
    format: 'json'
  })
});

// Query
const results = await fetch(`${api}/query`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    container: 'mydata',
    query: '//user'
  })
}).then(r => r.json());
```

## Offline Mode

All SDKs support offline-first operation with automatic sync.

### How It Works

1. **Connected** — Operations go directly to the server
2. **Offline** — Operations stored locally (SQLite)
3. **Sync** — Changes synchronized when reconnected

### Enable Offline Mode

| SDK | Configuration |
|-----|---------------|
| .NET | `EnableOfflineMode = true` |
| Swift | `enableOfflineMode: true` |
| Kotlin | `enableOfflineMode = true` |

### Manual Sync

**.NET:**

```csharp
await database.SyncAsync();
```

**Swift:**

```swift
try await database.sync()
```

**Kotlin:**

```kotlin
database.sync()
```

## Best Practices

### 1. Handle Offline Gracefully

```csharp
try {
    await database.ConnectAsync();
} catch {
    // Continue with offline mode
    if (database.OfflineModeEnabled) {
        // App works offline
    }
}
```

### 2. Sync on Reconnection

```kotlin
db.connectionState.collect { state ->
    if (state == ConnectionState.CONNECTED) {
        db.sync()
    }
}
```

### 3. Use Cancellation

```swift
let task = Task {
    try await container.getDocument(name: "large.xml")
}
// Cancel if needed
task.cancel()
```

## Platform Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 15.0 |
| Android | API 24 (Android 7.0) |
| .NET MAUI | .NET 8+ |
