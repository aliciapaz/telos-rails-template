# Architecture

## Stack Overview

| Layer | Technology |
|---|---|
| Framework | Rails 8 |
| Database | SQLite3 |
| Frontend | Hotwire (Turbo + Stimulus) |
| Styling | Tailwind CSS |
| Background Jobs | Solid Queue |
| Authorization | ActionPolicy |
| Testing | RSpec + FactoryBot |
| Linting | RuboCop (Standard/Shopify) |
| Security | Brakeman + bundle-audit |

## Request Flow

```
Browser
  │
  ▼
Routes (config/routes.rb)
  │
  ▼
Controller ──────────────────────────────┐
  │  • Thin: params, auth, response      │
  │  • authorize! @resource               │
  │                                       │
  ▼                                       │
Service Object                            │
  │  • All business logic lives here      │
  │  • call (returns data)                │
  │  • save (persists, returns bool)      │
  │                                       │
  ▼                                       │
Model                                     │
  │  • Persistence + associations         │
  │  • Validations + scopes              │
  │  • No business logic                  │
  │                                       │
  ▼                                       │
Database (SQLite3)                        │
                                          │
  ◄───────────────────────────────────────┘
  │
  ▼
View (ERB + Turbo Frames/Streams)
  │
  ▼
Browser (Stimulus for JS interactions)
```

## Key Boundaries

### Controller → Service
Controllers instantiate services and handle the response. They never contain business logic.

### Service → Model
Services orchestrate model operations within transactions. Models handle persistence only.

### Controller → Policy
Authorization is checked via ActionPolicy before any action. Policies define who can do what.

### View → Turbo
Views use Turbo Frames for isolated updates and Turbo Streams for real-time broadcasts. Custom JS is limited to Stimulus controllers.

## Background Jobs

```
Job (thin wrapper)
  │
  ▼
Service Object (all logic)
  │
  ▼
Model / External API
```

Jobs delegate to service objects. They handle missing records gracefully (log and return).

## External Services

Wrapped in service objects that:
- Validate configuration on initialize
- Return `{ success: boolean, data/error: ... }`
- Rescue service-specific exceptions
- Never expose API keys
