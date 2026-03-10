---
name: dev-generate-http-files
description: Generates IntelliJ .http files from existing REST controllers for manual API testing. Use when you need executable HTTP request files for local or staging testing.
argument-hint: [ControllerName] in [module] [optional: --all for all controllers in module]
---

# Generate HTTP Files

Reads an existing REST controller and generates an IntelliJ HTTP Client `.http` file with one request block per endpoint. Also creates or updates `http-client.env.json` with environment profiles (`local`, `dev`, `staging`). Use when you need runnable API request files for manual testing without opening Swagger UI.

## Configuration

Read `ai26/config.yaml` → `modules` → find the module with `active: true` (default: `service`).
From that module read `base_package`, `base_package_path`, `main_source_root`, `test_source_root`,
`test_resources_root`.

Fallback values if file cannot be read: `base_package_path=de/tech26/valium`,
`test_resources_root=service/src/test/resources`.

## Task

For each controller specified:

1. `{TEST_RESOURCES}/http/{module}/{controller-name}.http` — IntelliJ HTTP Client request file, one `###` block per endpoint
2. `{TEST_RESOURCES}/http/http-client.env.json` — Environment variables file (created once, updated with new keys if already exists)

No new Kotlin files are created. No build dependencies are needed.

## Implementation Rules

### Reading the controller
- ✅ Read the target `*Controller.kt` to extract: `@RequestMapping` base path, per-method `@GetMapping`/`@PostMapping`/`@PutMapping`/`@PatchMapping`/`@DeleteMapping` paths, HTTP status from `@ResponseStatus`, `@Operation(summary)` for comments, `@PathVariable` names, `@RequestBody` DTO type
- ✅ For `@RequestBody` parameters: read the DTO class and extract `@field:Schema(example = "...")` values to populate the request body
- ✅ Include `@CommonHeaders` (`x-n26-userid`, `x-n26-userLocale`, `x-n26-platform`) on every request that uses the `@CommonHeaders` annotation

### HTTP file format
- ✅ IntelliJ HTTP Client syntax: `{{variable}}` for all host/port/token substitutions
- ✅ Separator `###` between request blocks (including a trailing `###` at end of file)
- ✅ Each block starts with a `# <operation summary>` comment from `@Operation(summary)` or a derived label
- ✅ Method line format: `POST {{host}}/api/v2/chat/conversations`
- ✅ Headers on separate lines: `Header-Name: value`
- ✅ Blank line between headers and body
- ✅ JSON body populated with `@Schema(example)` values where available; use placeholder strings otherwise
- ❌ No hardcoded hosts, ports, or tokens — always use `{{variable}}` syntax
- ❌ No secrets or real user IDs in committed files

### Environment file
- ✅ `http-client.env.json` defines `local`, `dev`, `staging` profiles at minimum
- ✅ Each profile contains: `host`, `port` (for local), `userId`, `locale`, `platform`
- ✅ Use placeholder values for tokens and user IDs (e.g., `"<your-user-id>"`)
- ✅ If the file already exists, merge new variables without removing existing profiles
- ❌ Do not overwrite existing env file — update it additively

## Example Implementation

### `CreateConversationController` → `conversation/create-conversation-controller.http`

Given controller with `@RequestMapping("/api/v2/chat/conversations")` and `@PostMapping`:

```http
### Create a new conversation
POST {{host}}/api/v2/chat/conversations
Content-Type: application/json
x-n26-userid: {{userId}}
x-n26-userLocale: {{locale}}
x-n26-platform: {{platform}}

{
  "conversationId": "{{$uuid}}"
}

###
```

### `http-client.env.json`
```json
{
  "local": {
    "host": "http://localhost:8080",
    "userId": "<your-user-id>",
    "locale": "en",
    "platform": "ANDROID"
  },
  "dev": {
    "host": "https://valium.dev.n26.com",
    "userId": "<your-user-id>",
    "locale": "en",
    "platform": "ANDROID"
  },
  "staging": {
    "host": "https://valium.staging.n26.com",
    "userId": "<your-user-id>",
    "locale": "en",
    "platform": "ANDROID"
  }
}
```

### Controller with path variables and GET + DELETE

```http
### Get {ResourceName} by id
GET {{host}}/api/v1/{module}/{resourceName}/{{resourceId}}
x-n26-userid: {{userId}}
x-n26-userLocale: {{locale}}
x-n26-platform: {{platform}}

###

### Delete {ResourceName}
DELETE {{host}}/api/v1/{module}/{resourceName}/{{resourceId}}
x-n26-userid: {{userId}}
x-n26-userLocale: {{locale}}
x-n26-platform: {{platform}}

###
```

## Anti-Patterns

```http
# ❌ Hardcoded host and real user ID
POST http://localhost:8080/api/v2/chat/conversations
x-n26-userid: 0befcc94-013c-4ff7-a72e-07408f10cac1

# ✅ Variables for all environment-specific values
POST {{host}}/api/v2/chat/conversations
x-n26-userid: {{userId}}
```

```http
# ❌ No separator between requests (breaks IntelliJ HTTP client parsing)
POST {{host}}/api/v1/foo
Content-Type: application/json
{ "a": "b" }
GET {{host}}/api/v1/foo/1

# ✅ Separator between every request
POST {{host}}/api/v1/foo
Content-Type: application/json

{ "a": "b" }

###

GET {{host}}/api/v1/foo/1

###
```

```json
// ❌ Overwriting existing env file when updating — loses manual customisations
// ✅ Merge new keys into existing profiles; never delete existing keys
```

## Verification

1. `.http` file opens in IntelliJ without parse errors (green play buttons on each `###` block)
2. All endpoints from the controller appear in the file (count `###` separators)
3. `@CommonHeaders` are present on every request that uses them in the controller
4. No hardcoded hostnames, ports, or user IDs (search for `localhost`, `n26.com`, UUID patterns)
5. `http-client.env.json` contains `local`, `dev`, and `staging` profiles
6. Request bodies match the DTO field names from the controller's `@RequestBody` type
```
