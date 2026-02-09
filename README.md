# Social Scribe

**AI-powered meeting transcription and social media content generation platform.** Connects to calendars, sends AI notetakers to meetings via Recall.ai, transcribes them, and uses Google Gemini to generate follow-up emails and social media posts. Integrates with HubSpot and Salesforce CRMs for contact management, and provides an AI chat interface for asking questions about CRM contacts.

Built with Elixir, Phoenix LiveView, and PostgreSQL.

---

## Features

- **Google Calendar Integration** — Log in with Google, connect multiple accounts, view upcoming events on the dashboard
- **Automated Meeting Transcription** — Toggle recording for any event; Recall.ai bot joins Zoom/Google Meet calls, transcribes them
- **AI Content Generation** — Gemini drafts follow-up emails and runs user-defined automations to generate platform-specific posts (LinkedIn, Facebook)
- **Social Media Posting** — Connect LinkedIn and Facebook via OAuth; post generated content directly from the meeting detail page
- **HubSpot & Salesforce CRM** — Search contacts, get AI-suggested field updates from transcripts, review and apply changes
- **AI Chat Panel** — "Ask Anything" slide-out panel on every dashboard page; CRM-aware, looks up contacts across connected providers
- **Background Processing** — Oban workers for bot polling, AI generation, and proactive CRM token refresh

---

## App Flow

[![Auth Flow](https://img.youtube.com/vi/RM7YSlu5ZDg/maxresdefault.jpg)](https://youtu.be/RM7YSlu5ZDg)
**Login With Google and Meetings Sync**

[![Creating Automations](https://img.youtube.com/vi/V2tIKgUQYEw/maxresdefault.jpg)](https://youtu.be/V2tIKgUQYEw)
**Creating Automations**

[![Meetings Recording](https://img.youtube.com/vi/pZrLsoCfUeA/maxresdefault.jpg)](https://youtu.be/pZrLsoCfUeA)
**Meetings Recordings**

[![Facebook Login](https://img.youtube.com/vi/JRhPqCN-jeI/maxresdefault.jpg)](https://youtu.be/JRhPqCN-jeI)
**Facebook Login**

[![Facebook Post](https://img.youtube.com/vi/4w6zpz0Rn2o/maxresdefault.jpg)](https://youtu.be/4w6zpz0Rn2o)
**Facebook Post**

[![LinkedIn Login and Post](https://img.youtube.com/vi/wuD_zefGy2k/maxresdefault.jpg)](https://youtu.be/wuD_zefGy2k)
**LinkedIn Login & Post**

---

## Screenshots

**Dashboard View:**

![Dashboard View](readme_assets/dashboard_view.png)

**Automation Configuration:**

![Automation Configuration](readme_assets/edit_automation.png)

---

## Tech Stack

| Component | Technology |
|---|---|
| Backend | Elixir, Phoenix LiveView |
| Database | PostgreSQL |
| Background Jobs | Oban |
| Authentication | Ueberauth (Google, LinkedIn, Facebook, HubSpot, Salesforce) |
| Meeting Transcription | Recall.ai API |
| AI Content Generation | Google Gemini API |
| CRM Integrations | HubSpot API v3, Salesforce REST API |
| Frontend | Tailwind CSS, Heroicons |
| CI/CD | GitHub Actions (format, compile, test, coverage) |
| Containerization | Docker, Docker Compose |
| Testing | ExUnit, Mox (mock-based), StreamData (property-based), ExCoveralls |
| Deployment | Fly.io |

---

## Project Structure

```
social_scribe/
├── lib/
│   ├── social_scribe/           # Core business logic
│   │   ├── accounts/            # User management, OAuth credentials
│   │   ├── automations/         # User-defined content generation templates
│   │   ├── bots/                # Recall.ai bot lifecycle
│   │   ├── calendar/            # Google Calendar event syncing
│   │   ├── chat/                # AI chat conversations and messages
│   │   ├── crm/                 # CRM provider config, contact schema
│   │   ├── workers/             # Oban workers (polling, AI gen, token refresh)
│   │   ├── crm_api_behaviour.ex # Unified CRM behaviour (5 callbacks)
│   │   ├── crm_suggestions.ex   # AI-powered contact update suggestions
│   │   ├── hubspot_api.ex       # HubSpot API client
│   │   ├── salesforce_api.ex    # Salesforce API client
│   │   └── ...
│   ├── social_scribe_web/       # Web layer
│   │   ├── components/          # Shared UI (modal, sidebar, clipboard)
│   │   ├── controllers/         # Auth, session, error controllers
│   │   ├── live/                # LiveView pages
│   │   │   ├── automation_live/ # Automation CRUD
│   │   │   ├── chat_live/       # Chat panel component
│   │   │   ├── meeting_live/    # Meeting list, detail, CRM modal
│   │   │   ├── home_live.ex     # Dashboard with calendar
│   │   │   └── user_settings_live.ex
│   │   ├── live_hooks.ex        # Chat state management hook
│   │   ├── router.ex            # Route definitions
│   │   └── user_auth.ex         # Auth plugs and helpers
│   └── ueberauth/strategy/      # Custom OAuth strategies (HubSpot, Salesforce)
├── test/
│   ├── social_scribe/           # Context and worker tests
│   │   ├── chat/                # Chat AI tests (unit + property)
│   │   └── workers/             # Oban worker tests
│   ├── social_scribe_web/       # Web layer tests
│   │   ├── controllers/         # Auth, session controller tests
│   │   └── live/                # LiveView tests (modals, settings, chat)
│   └── support/                 # Fixtures, examples, test cases
├── config/                      # Compile-time and runtime config
├── priv/                        # Migrations, static assets, seeds
├── Dockerfile                   # Production multi-stage image
├── Dockerfile.dev               # Development image (with inotify-tools)
├── docker-compose.yml           # PostgreSQL + app for local dev
└── mix.exs                      # Project manifest and dependencies
```

---

## Getting Started

### Prerequisites

- Elixir 1.18+ / Erlang/OTP 27+
- PostgreSQL 16+
- Node.js (for Tailwind CSS asset compilation)

### Option 1: Local Setup

```bash
git clone https://github.com/fparadas/social_scribe.git
cd social_scribe
mix setup        # Install deps, create DB, run migrations, build assets
```

Configure environment variables (see [Environment Variables](#environment-variables) below), then:

```bash
source .env && mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

### Option 2: Docker Compose

```bash
git clone https://github.com/fparadas/social_scribe.git
cd social_scribe
```

Configure environment variables in `.env`, then:

```bash
docker compose up
```

This starts PostgreSQL and the Phoenix dev server. On first run it installs deps, creates the database, runs migrations, and builds assets automatically. Visit [localhost:4000](http://localhost:4000).

To run just the database (useful if you prefer running the app locally):

```bash
docker compose up -d db
```

To run tests inside Docker:

```bash
docker compose exec app sh -c 'MIX_ENV=test mix test'
```

### Environment Variables

Create a `.env` file with the following:

```
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_REDIRECT_URI=http://localhost:4000/auth/google/callback
LINKEDIN_CLIENT_ID=...
LINKEDIN_CLIENT_SECRET=...
LINKEDIN_REDIRECT_URI=http://localhost:4000/auth/linkedin/callback
FACEBOOK_CLIENT_ID=...
FACEBOOK_CLIENT_SECRET=...
FACEBOOK_REDIRECT_URI=http://localhost:4000/auth/facebook/callback
HUBSPOT_CLIENT_ID=...
HUBSPOT_CLIENT_SECRET=...
SALESFORCE_CLIENT_ID=...
SALESFORCE_CLIENT_SECRET=...
RECALL_API_KEY=...
RECALL_REGION=us-west-2
GEMINI_API_KEY=...
```

### Salesforce Setup (Development)

1. Create a free Salesforce Developer Edition at [developer.salesforce.com](https://developer.salesforce.com)
2. Setup > App Manager > New Connected App
3. Enable OAuth, callback: `http://localhost:4000/auth/salesforce/callback`
4. Scopes: `api`, `refresh_token`, `offline_access`
5. Set `SALESFORCE_CLIENT_ID` and `SALESFORCE_CLIENT_SECRET` env vars

---

## Common Commands

```bash
mix setup                        # Full setup: deps, database, assets
mix phx.server                   # Start dev server (localhost:4000)
iex -S mix phx.server            # Start dev server with IEx shell
mix test                         # Run all tests
mix test test/path/file.exs      # Run single test file
mix test test/path/file.exs:42   # Run test at line number
mix coveralls                    # Run tests with coverage report
mix coveralls.html               # Coverage report as HTML (cover/excoveralls.html)
mix format                       # Format code
mix ecto.migrate                 # Run pending migrations
mix ecto.reset                   # Drop, create, migrate, seed
```

---

## Testing

36 test files, 387 tests (352 unit/integration + 35 property-based), 57% coverage.

```bash
mix test                    # Run all tests
mix coveralls --raise       # Run tests with 55% coverage threshold enforcement
```

### Test Categories

| Category | Files | What's tested |
|---|---|---|
| **Context tests** | `accounts_test`, `automations_test`, `bots_test`, `calendar_test`, `meetings_test`, `chat_test`, `crm_test` | Core business logic CRUD, queries, associations |
| **CRM API tests** | `hubspot_api_test`, `salesforce_api_test` | API client calls, token refresh wrapper, error handling |
| **CRM suggestions tests** | `hubspot_suggestions_test`, `salesforce_suggestions_test` | AI suggestion generation and field merging |
| **Token refresher tests** | `hubspot_token_refresher_test`, `salesforce_token_refresher_test`, `crm_token_refresher_test` | OAuth token refresh logic, Oban worker dispatch |
| **Chat AI tests** | `chat_ai_test`, `chat_ai_property_test` | @mention extraction, CRM lookup, AI response |
| **Worker tests** | `ai_content_generation_worker_test`, `bot_status_poller_test`, `crm_contact_syncer_test` | Oban job execution, state transitions |
| **LiveView tests** | `hubspot_modal_test`, `salesforce_modal_test`, `chat_panel_test`, `automation_live_test`, `user_settings_live_test` | Component rendering, user interactions, Mox integration |
| **Controller tests** | `auth_controller_test`, `user_session_controller_test`, `error_html_test`, `error_json_test` | OAuth callbacks, session management, error pages |
| **Auth tests** | `user_auth_test` | Auth plugs, session token logic |
| **Property tests** | `hubspot_api_property_test`, `hubspot_suggestions_property_test`, `salesforce_api_property_test`, `salesforce_suggestions_property_test`, `chat_ai_property_test` | StreamData-driven fuzzing of API responses, suggestion merging, chat input |

### Test Conventions

- **Mox for external APIs** — All external services (Recall.ai, Google Calendar, Gemini, HubSpot, Salesforce) use behaviours with Mox mocks in tests
- **SQL Sandbox** — `Ecto.Adapters.SQL.Sandbox` for database isolation between tests
- **Oban manual mode** — `testing: :manual` in test env; jobs are tested via `Oban.Testing`
- **Fixtures** — Test data factories in `test/support/fixtures/` for accounts, automations, bots, calendar, CRM, meetings
- **Property tests** — StreamData used for CRM API response fuzzing, suggestion field merging, and chat input parsing

---

## CI/CD

### CI Pipeline (GitHub Actions)

The CI pipeline runs on every push and PR to `master`/`main`:

1. **Install dependencies** — `mix deps.get`
2. **Compile with warnings as errors** — `mix compile --warnings-as-errors`
3. **Check formatting** — `mix format --check-formatted`
4. **Run tests with coverage** — `mix coveralls --raise` (fails build if coverage drops below 55%)

See [`.github/workflows/test.yml`](.github/workflows/test.yml).

### Deployment

The app ships with a multi-stage production `Dockerfile` and is pre-configured for Fly.io.

```bash
fly launch                                    # Create app + Postgres
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  GOOGLE_CLIENT_ID="..." \
  GOOGLE_CLIENT_SECRET="..." \
  # ... all env vars
fly deploy                                    # Build and deploy
fly ssh console -C "/app/bin/migrate"         # Run migrations
```

**Production environment variables** (in addition to OAuth/API keys):

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (auto-set by Fly Postgres) |
| `SECRET_KEY_BASE` | Generate with `mix phx.gen.secret` |
| `PHX_HOST` | Production hostname (e.g. `myapp.fly.dev`) |
| `PORT` | Server port (default `4000`) |

**Production security:** `force_ssl` enabled, `check_origin` enforced, production redirect URIs configured for Google, HubSpot, and Salesforce OAuth.

---

## Architecture

### Unified CRM Architecture

All CRM integrations share a single set of generic modules, parameterized by config from `CRM.ProviderConfig`:

| Layer | Module | Purpose |
|---|---|---|
| Behaviour | `CrmApiBehaviour` | Single behaviour with 5 callbacks + `impl/1` dispatcher |
| API Clients | `HubspotApi`, `SalesforceApi` | Per-provider implementations |
| Config | `CRM.ProviderConfig` | Centralized provider config (field labels, AI prompts, UI styling) |
| Suggestions | `CrmSuggestions` | Generic AI-powered contact update suggestions from transcripts |
| Token Refresh | `Workers.CrmTokenRefresher` | Single Oban worker dispatching by `"provider"` arg |
| Modal UI | `CrmModalComponent` | Single parameterized LiveComponent for all CRMs |
| LiveView | `MeetingLive.Show` | 3 generic `handle_info` handlers for search/suggest/apply |

### External API Clients

All external APIs are defined as behaviours and swapped with Mox mocks in tests:

| Module | Behaviour | Mock | Config key |
|---|---|---|---|
| `RecallApi` | `RecallApi` | `RecallApiMock` | `:recall_api` |
| `GoogleCalendar` | `GoogleCalendarApi` | `GoogleCalendarApiMock` | `:google_calendar_api` |
| `AIContentGenerator` | `AIContentGeneratorApi` | `AIContentGeneratorMock` | `:ai_content_generator_api` |
| `HubspotApi` | `CrmApiBehaviour` | `HubspotApiMock` | `:hubspot_api` |
| `SalesforceApi` | `CrmApiBehaviour` | `SalesforceApiMock` | `:salesforce_api` |
| Token refresher | `TokenRefresherApi` | `TokenRefresherMock` | `:token_refresher_api` |

### Background Workers (Oban)

| Worker | Schedule | Purpose |
|---|---|---|
| `BotStatusPoller` | Every 2 min | Polls Recall.ai bot statuses, processes completed meetings, enqueues AI generation |
| `AIContentGenerationWorker` | On demand | Generates follow-up email + runs all user automations against transcript |
| `CrmTokenRefresher` | Every 5 min (per provider) | Proactively refreshes HubSpot/Salesforce tokens expiring within 10 minutes |
| `CrmContactSyncer` | On demand | Syncs CRM contacts to local database for chat lookups |

---

## Developer Guide

### Adding a New CRM Provider

To add a new CRM (e.g. Pipedrive):

1. **Register the provider in `CRM.ProviderConfig`** (`lib/social_scribe/crm/provider_config.ex`):
   ```elixir
   "pipedrive" => %{
     name: "pipedrive",
     display_name: "Pipedrive",
     api_config_key: :pipedrive_api,
     field_labels: %{"firstname" => "First Name", ...},
     ai_field_descriptions: "- Phone numbers (phone)\n- Email ...",
     ai_field_names: "firstname, lastname, email, phone, ...",
     modal_submit_text: "Update Pipedrive",
     modal_submit_class: "bg-green-500 hover:bg-green-600",
     button_class: "bg-green-500 hover:bg-green-600"
   }
   ```

2. **Implement `CrmApiBehaviour`** (e.g. `lib/social_scribe/pipedrive_api.ex`):
   ```elixir
   defmodule SocialScribe.PipedriveApi do
     @behaviour SocialScribe.CrmApiBehaviour
     # Implement: search_contacts/2, get_contact/2, update_contact/3, apply_updates/3, list_contacts/1
   end
   ```

3. **Create a token refresher** (e.g. `lib/social_scribe/pipedrive_token_refresher.ex`) implementing `CrmTokenRefresherBehaviour`, and register it in the `@default_refreshers` map in `Workers.CrmTokenRefresher`.

4. **Add an Oban cron entry** in `config/config.exs`:
   ```elixir
   {"*/5 * * * *", SocialScribe.Workers.CrmTokenRefresher, args: %{"provider" => "pipedrive"}}
   ```

5. **Create Ueberauth OAuth strategy** (e.g. `lib/ueberauth/strategy/pipedrive.ex`) and add the route + callback handler in `AuthController`.

6. **Wire up the config** in `config/dev.exs` and `config/test.exs`:
   ```elixir
   config :social_scribe, :pipedrive_api, SocialScribe.PipedriveApi
   ```

7. **Register mock in `test/test_helper.exs`**:
   ```elixir
   Mox.defmock(SocialScribe.PipedriveApiMock, for: SocialScribe.CrmApiBehaviour)
   ```

No changes needed to `CrmSuggestions`, `CrmModalComponent`, `MeetingLive.Show`, `ChatAI`, or any AI prompt logic. They all work generically off the provider config.

### Conventions

- **Behaviours for external services** — Every external API has a behaviour module, a real implementation, and a Mox mock. Runtime dispatch via `Application.get_env(:social_scribe, :config_key)`.
- **Oban for background work** — All async processing goes through Oban workers with defined queues (`default`, `ai_content`, `polling`).
- **CRM provider config** — UI labels, AI prompts, styling, and field mappings are centralized in `CRM.ProviderConfig`, not scattered across modules.
- **Token refresh wrapper** — `with_token_refresh/2` in API clients auto-retries on 401 with a fresh token.
- **LiveView + PubSub** — Long-running operations (AI suggestions, chat responses) run in supervised async tasks and push results back via `send/2`.
- **Formatting** — Run `mix format` before committing. The project uses the Phoenix LiveView HTML formatter plugin.

---

## Known Issues & Limitations

- **Facebook Posting & App Review:** Posting to Facebook Pages requires Meta app review for non-admin users. During development, posting works for app admins to Pages they directly manage.
- **Agenda Integration:** Currently only syncs calendar events with a `hangoutLink` or `location` field containing a Zoom or Google Meet link.

---

## Learn More

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)
- [Elixir Forum](https://elixirforum.com/c/phoenix-forum)
