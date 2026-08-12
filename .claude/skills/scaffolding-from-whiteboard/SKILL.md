---
name: scaffolding-from-whiteboard
description: Use when asked to scaffold, generate, or bootstrap a codebase from an nvim-whiteboard board — a .wb file, a saved board name, or the currently open whiteboard — into a programming language the user chooses.
---

# Scaffolding code from a whiteboard board

Turn an nvim-whiteboard architecture sketch into project scaffolding in the
user's declared language. If no language was declared, ask before generating.

## Finding the board

Boards live in `save_directory` (default: `stdpath('data') .. '/whiteboard'`,
i.e. `~/.local/share/nvim/whiteboard/<name>.wb`). If the board is only open and
unsaved, have the user run `:WhiteboardSave <name>` first.

## .wb format (version 1)

JSON produced by `vim.json.encode`:

```json
{
  "version": 1,
  "name": "payments",
  "nodes":       { "1": { "id": 1, "x": 4, "y": 2, "width": 16, "height": 5,
                          "shape": "client", "text": "Browser",
                          "label": "optional", "style": { "border": "single" } } },
  "connections": { "1": { "id": 1, "from": 1, "to": 2,
                          "style": "solid", "label": "HTTPS" } },
  "canvas":      { "...": "cursor/grid state — ignore for scaffolding" }
}
```

`vim.json.encode` emits integer-keyed tables as **arrays when ids are dense
from 1** and as objects otherwise (after deletions). Handle both. `x`/`y`/
`width`/`height` matter only for reading the layout, not for scaffolding.

## Mapping shapes to scaffold artifacts

| Shapes | Scaffold as |
|---|---|
| `service`, `server`, `api` | Service module with an entrypoint |
| `database`, `cache` | Storage adapter / repository behind an interface |
| `queue` | Producer + consumer stubs |
| `client` | Client stub (skip only if the user says the client is out of scope) |
| `class` | Class |
| `function_` | Function |
| `module`, `package`, `component`, `box` | Plain module |
| `router`, `load_balancer`, `firewall`, `switch`, `cloud` | Infrastructure — config/comment, not code, unless the user says otherwise |

Node `text` names the artifact (convert to the language's naming convention);
node `label` is a hint for docs/comments.

## Mapping connections to code

A connection `from → to` means *from depends on to*. Express it the idiomatic
way for the language: constructor injection, module import, or interface
parameter. The connection `label` hints at the interaction — name the method,
event, or protocol after it (`SQL` → repository methods, `events` → an event
type, `HTTPS` → an HTTP client call).

**Chains through infrastructure nodes:** when a dependency path runs through a
node that scaffolds as config rather than code (`A → load_balancer → B`),
collapse through it — A depends on the next code-producing node downstream
(via whatever the infra config exposes, e.g. a base URL), and the infra
node's config names B as its upstream.

## Workflow

1. Parse the `.wb`, list nodes and connections back to the user as a sanity
   check (names, shapes, dependency directions). If the language or the output
   directory wasn't declared, ask for them here — once, not again later.
2. Generate the minimal idiomatic layout: one module per code-producing node,
   wiring that mirrors the connections, and a top-level entrypoint that
   composes them. Compile-clean stubs; no speculative extras, and no framework
   unless the user named one.
3. Verify it builds/typechecks with the language's standard tool and report
   the result.
