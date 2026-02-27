# Reusable Abstractions

**Before building a new service, concern, or policy, check this file.** Existing abstractions should be reused or extended, not duplicated.

**When you add a new reusable abstraction, add it here.**

## Services

| Name | Location | What It Does | When to Use |
|---|---|---|---|
| `ApplicationService` | `app/services/application_service.rb` | Base class with `call`/`save` class methods that delegate to instance methods. Defines `Error` base exception. | Inherit from this for all service objects. Use `call` for operations that return data, `save` for operations that persist. |

## Policies

| Name | Location | What It Does | When to Use |
|---|---|---|---|
| `ApplicationPolicy` | `app/policies/application_policy.rb` | Base policy with default-deny for all actions. Provides `owner?` helper. | Inherit from this for all authorization policies. Override action methods (`create?`, `update?`, etc.) to allow access. |

## Controller Concerns

| Name | Location | What It Does | When to Use |
|---|---|---|---|
| `Authenticatable` | `app/controllers/concerns/authenticatable.rb` | Adds `before_action :authenticate_user!` and configures Devise redirect paths. | Include in controllers that require authentication. Already included in `ApplicationController`. |
| `LocaleSettable` | `app/controllers/concerns/locale_settable.rb` | Sets `I18n.locale` from params or session using `around_action`. | Include in controllers that need locale switching. |

## Model Concerns

_None yet. Add shared model behavior here as the application grows._

When two models share 3+ methods with identical logic, extract a concern here. Name descriptively: `Chartable`, `Sluggable`, `Trackable`.
