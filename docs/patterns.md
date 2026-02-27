# Patterns

Quick reference for Telos conventions. Follow these in all new code.

## Service Objects

Name with action + "Service" or "Creator" (e.g., `StripeConnectAccountService`, `GeneralReportCreator`).

### Pattern A: `call` — for operations that return data

```ruby
class FetchReportService
  include ActiveModel::Model

  class Error < StandardError; end

  attr_accessor :user, :date_range

  def call
    validate_inputs
    fetch_data
  end

  private

  def validate_inputs
    raise Error, "user required" unless user
  end

  def fetch_data
    # ...
  end
end
```

### Pattern B: `save` — for operations that persist data (returns true/false)

```ruby
class CreateListingService
  include ActiveModel::Model

  class Error < StandardError; end

  attr_accessor :user, :params

  def save
    ActiveRecord::Base.transaction do
      build_listing
      assign_attributes
      listing.save!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
```

## Controllers

- Max 30-50 lines. Extract to services if longer.
- Use `params.expect()` for strong parameters.
- `authorize! @resource` for authorization.
- Handle service errors, provide user feedback.

```ruby
class ListingsController < ApplicationController
  def create
    @listing = current_user.listings.build
    service = CreateListingService.new(user: current_user, params: listing_params)

    if service.save
      redirect_to @listing, notice: "Listing created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def listing_params
    params.expect(listing: [:title, :description, :price])
  end
end
```

## Models

- Persistence, associations, validations, scopes only.
- Callbacks only for persistence concerns (`before_validation :set_defaults`).
- Use `store_accessor` for JSONB columns.
- NO business logic — move to services.

## Authorization (ActionPolicy)

```ruby
class ListingPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def update?
    owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

## Turbo Frames

- Use for isolated page sections that update independently.
- Keep frame IDs unique and semantic: `edit_user_123`.
- Set `target: "_top"` when navigation should replace the whole page.
- Use `src:` attribute for lazy loading.

```erb
<%= turbo_frame_tag dom_id(@listing, :details) do %>
  <!-- Content that updates independently -->
<% end %>
```

## Turbo Streams

- Use for real-time updates and multi-part form responses.
- Prefer specific actions: `append`, `prepend`, `replace`, `update`, `remove`.
- Target elements by ID — ensure target exists in DOM.

```ruby
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: turbo_stream.replace(
      dom_id(@listing),
      partial: "listings/listing",
      locals: { listing: @listing }
    )
  end
end
```

## Stimulus Controllers

- Small, focused (single responsibility).
- Use data attributes for configuration, not hardcoded values.
- Connect external libraries in `connect()`, clean up in `disconnect()`.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]

  update() {
    this.outputTarget.textContent = this.inputTarget.value
  }
}
```

## Testing

- RSpec + FactoryBot.
- Prefer request specs over system specs.
- System specs only for complex JS interactions.
- Use `let` and `before` blocks, avoid fixtures.

```ruby
RSpec.describe "Listings", type: :request do
  let(:user) { create(:user) }

  describe "POST /listings" do
    it "creates a listing" do
      sign_in user
      post listings_path, params: { listing: attributes_for(:listing) }
      expect(response).to redirect_to(Listing.last)
    end
  end
end
```

## Code Quality Thresholds

| Metric | Target | Hard Limit |
|---|---|---|
| Method length | 5-7 lines | 10 lines |
| Cyclomatic complexity | — | 7 per method |
| Perceived complexity | — | 8 per method |
| ABC size | — | 17 per method |
| Class size | — | 100 lines |
| Rubycritic score | 90+ | 85 minimum |

## Validation

Three-layer approach:
1. **Model validations** — data integrity (presence, format, inclusion)
2. **Custom validators** — complex logic in `app/validators/`
3. **Service validators** — business rules and external dependencies

## i18n Conventions

- **Shared keys** (navbar, flash messages, errors, common labels) go in the root locale file: `config/locales/{locale}.yml`
- **Feature-specific keys** go in their own file: `config/locales/{feature}/{locale}.yml`
- All supported locales must have matching key structures. If you add a key to `en.yml`, add it to `es.yml` too.
- Use Rails' built-in scoping: `t(".title")` in views resolves based on the template path.

```
config/locales/
  en.yml              # shared: navbar, flash, errors, common
  es.yml
  devise.en.yml       # devise-specific
  listings/
    en.yml            # feature-specific: listings
    es.yml
```

## Shared Concerns

When two models share 3+ methods with identical logic, extract a concern to `app/models/concerns/`. Name descriptively: `Chartable`, `Sluggable`, `Trackable`.

```ruby
# app/models/concerns/sluggable.rb
module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug
  end

  private

  def generate_slug
    self.slug = name&.parameterize
  end
end
```

Same rule applies to controllers: shared behavior goes in `app/controllers/concerns/`.

## Shared View Partials

When two features share HTML structure, extract to `app/views/shared/`. Partials **must** use local variables only — never instance variables.

```erb
<%# app/views/shared/_card.html.erb %>
<div class="rounded-lg border p-4">
  <h3><%= title %></h3>
  <%= yield %>
</div>

<%# Usage %>
<%= render "shared/card", title: "Details" do %>
  <p>Card content here</p>
<% end %>
```
