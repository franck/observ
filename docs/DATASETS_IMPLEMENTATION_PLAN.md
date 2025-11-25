# Datasets Feature Implementation Plan

## Overview

This document captures the elaboration and implementation plan for adding the Datasets feature to the Observ gem. The feature enables teams to evaluate LLM applications by running them against curated test cases and tracking results over time.

See `docs/DATASETS_FEATURE_SPEC.md` for the full feature specification.

---

## Key Decisions

| Decision | Choice |
|----------|--------|
| Project scoping | Skipped (single-tenant) |
| Table namespace | `observ_` prefix (e.g., `observ_datasets`) |
| Agent integration | Dataset stores `agent_class` string referencing an agent |
| Run execution | Async via ActiveJob, triggered from UI |
| Navigation | Top-level nav item alongside Dashboard, Sessions, etc. |

---

## Phase 1: Core Models & Migrations

### Migration 1: `010_create_observ_datasets.rb`

```ruby
class CreateObservDatasets < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_datasets do |t|
      t.string :name, null: false
      t.text :description
      t.string :agent_class, null: false
      t.json :metadata, default: {}
      t.timestamps

      t.index :name, unique: true
    end
  end
end
```

### Migration 2: `011_create_observ_dataset_items.rb`

```ruby
class CreateObservDatasetItems < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_dataset_items do |t|
      t.references :dataset, null: false, foreign_key: { to_table: :observ_datasets }
      t.integer :status, default: 0, null: false
      t.json :input, null: false
      t.json :expected_output
      t.json :metadata, default: {}
      t.references :source_trace, foreign_key: { to_table: :observ_traces }
      t.timestamps

      t.index [:dataset_id, :status]
    end
  end
end
```

### Migration 3: `012_create_observ_dataset_runs.rb`

```ruby
class CreateObservDatasetRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_dataset_runs do |t|
      t.references :dataset, null: false, foreign_key: { to_table: :observ_datasets }
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.json :metadata, default: {}
      t.integer :total_items, default: 0
      t.integer :completed_items, default: 0
      t.integer :failed_items, default: 0
      t.decimal :total_cost, precision: 10, scale: 6, default: 0
      t.integer :total_tokens, default: 0
      t.timestamps

      t.index [:dataset_id, :name], unique: true
      t.index [:dataset_id, :status]
    end
  end
end
```

### Migration 4: `013_create_observ_dataset_run_items.rb`

```ruby
class CreateObservDatasetRunItems < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_dataset_run_items do |t|
      t.references :dataset_run, null: false, foreign_key: { to_table: :observ_dataset_runs }
      t.references :dataset_item, null: false, foreign_key: { to_table: :observ_dataset_items }
      t.references :trace, foreign_key: { to_table: :observ_traces }
      t.references :observation, foreign_key: { to_table: :observ_observations }
      t.text :error
      t.timestamps

      t.index [:dataset_run_id, :dataset_item_id], unique: true, name: 'idx_run_items_on_run_and_item'
    end
  end
end
```

---

## Models

### `Observ::Dataset`

```ruby
# app/models/observ/dataset.rb
module Observ
  class Dataset < ApplicationRecord
    self.table_name = "observ_datasets"

    has_many :items, class_name: "Observ::DatasetItem",
             foreign_key: :dataset_id, dependent: :destroy, inverse_of: :dataset
    has_many :runs, class_name: "Observ::DatasetRun",
             foreign_key: :dataset_id, dependent: :destroy, inverse_of: :dataset

    validates :name, presence: true, uniqueness: true
    validates :agent_class, presence: true
    validate :agent_class_exists

    def agent
      agent_class.constantize
    end

    def active_items
      items.active
    end

    private

    def agent_class_exists
      agent_class.constantize
    rescue NameError
      errors.add(:agent_class, "must be a valid agent class")
    end
  end
end
```

### `Observ::DatasetItem`

```ruby
# app/models/observ/dataset_item.rb
module Observ
  class DatasetItem < ApplicationRecord
    self.table_name = "observ_dataset_items"

    belongs_to :dataset, class_name: "Observ::Dataset", inverse_of: :items
    belongs_to :source_trace, class_name: "Observ::Trace", optional: true
    has_many :run_items, class_name: "Observ::DatasetRunItem",
             foreign_key: :dataset_item_id, dependent: :destroy, inverse_of: :dataset_item

    enum :status, { active: 0, archived: 1 }

    validates :input, presence: true

    scope :active, -> { where(status: :active) }
    scope :archived, -> { where(status: :archived) }
  end
end
```

### `Observ::DatasetRun`

```ruby
# app/models/observ/dataset_run.rb
module Observ
  class DatasetRun < ApplicationRecord
    self.table_name = "observ_dataset_runs"

    belongs_to :dataset, class_name: "Observ::Dataset", inverse_of: :runs
    has_many :run_items, class_name: "Observ::DatasetRunItem",
             foreign_key: :dataset_run_id, dependent: :destroy, inverse_of: :dataset_run
    has_many :items, through: :run_items, source: :dataset_item

    enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }

    validates :name, presence: true, uniqueness: { scope: :dataset_id }

    def progress_percentage
      return 0 if total_items.zero?
      ((completed_items + failed_items).to_f / total_items * 100).round(1)
    end

    def update_metrics!
      update!(
        completed_items: run_items.where.not(trace_id: nil).where(error: nil).count,
        failed_items: run_items.where.not(error: nil).count,
        total_cost: run_items.joins(:trace).sum("observ_traces.total_cost"),
        total_tokens: run_items.joins(:trace).sum("observ_traces.total_tokens")
      )
    end
  end
end
```

### `Observ::DatasetRunItem`

```ruby
# app/models/observ/dataset_run_item.rb
module Observ
  class DatasetRunItem < ApplicationRecord
    self.table_name = "observ_dataset_run_items"

    belongs_to :dataset_run, class_name: "Observ::DatasetRun", inverse_of: :run_items
    belongs_to :dataset_item, class_name: "Observ::DatasetItem", inverse_of: :run_items
    belongs_to :trace, class_name: "Observ::Trace", optional: true
    belongs_to :observation, class_name: "Observ::Observation", optional: true

    validates :dataset_run_id, uniqueness: { scope: :dataset_item_id }

    def succeeded?
      trace_id.present? && error.blank?
    end

    def failed?
      error.present?
    end

    def pending?
      trace_id.nil? && error.nil?
    end
  end
end
```

---

## Entity Relationships

```
Dataset (1) ─────────── (N) DatasetItem
    │                         │
    │                         │
    └──────── (N) DatasetRun  │
                    │         │
                    │         │
                    └──── (N) DatasetRunItem
                                │
                                ├──── (1) DatasetItem
                                ├──── (1) Trace (optional)
                                └──── (1) Observation (optional)
```

---

## Phase 2: Basic UI (Datasets & Items CRUD)

### Routes

```ruby
# In config/routes.rb
resources :datasets do
  resources :items, controller: 'dataset_items', except: [:show]
  resources :runs, controller: 'dataset_runs', only: [:index, :show, :new, :create, :destroy]
end
```

### Controllers

- `Observ::DatasetsController` - CRUD for datasets
- `Observ::DatasetItemsController` - CRUD for items within a dataset
- `Observ::DatasetRunsController` - List, show, create, delete runs

### Views

- `datasets/index.html.erb` - List all datasets
- `datasets/show.html.erb` - Dataset detail with tabs for items/runs
- `datasets/new.html.erb` / `_form.html.erb` - Create/edit dataset
- `dataset_items/index.html.erb` - List items (embedded in dataset show)
- `dataset_items/new.html.erb` / `_form.html.erb` - Create/edit item
- `dataset_runs/index.html.erb` - List runs (embedded in dataset show)
- `dataset_runs/show.html.erb` - Run detail with all run items

### Navigation

Add "Datasets" to the main nav in `app/views/layouts/observ/application.html.erb`:

```erb
<li class="observ-nav__item">
  <%= link_to "Datasets", datasets_path, class: "observ-nav__link #{controller_name == 'datasets' || controller_name == 'dataset_items' || controller_name == 'dataset_runs' ? 'observ-nav__link--active' : ''}" %>
</li>
```

---

## Phase 3: Dataset Runner Service

### Service: `Observ::DatasetRunnerService`

```ruby
# app/services/observ/dataset_runner_service.rb
module Observ
  class DatasetRunnerService
    def initialize(dataset_run)
      @dataset_run = dataset_run
      @dataset = dataset_run.dataset
    end

    def call
      @dataset_run.update!(status: :running)
      
      @dataset.active_items.find_each do |item|
        run_item = @dataset_run.run_items.find_or_create_by!(dataset_item: item)
        process_item(run_item)
      end

      @dataset_run.update_metrics!
      @dataset_run.update!(status: :completed)
    rescue StandardError => e
      @dataset_run.update!(status: :failed, metadata: @dataset_run.metadata.merge(error: e.message))
      raise
    end

    private

    def process_item(run_item)
      agent = @dataset.agent.new
      # Create session and trace for this run
      session = Observ::Session.create!(user_id: "dataset_run_#{@dataset_run.id}")
      trace = session.create_trace(
        name: "dataset_run_item",
        input: run_item.dataset_item.input,
        metadata: { dataset_run_id: @dataset_run.id, dataset_item_id: run_item.dataset_item.id }
      )

      # Execute the agent
      result = agent.call(run_item.dataset_item.input)
      trace.finalize(output: result)
      
      run_item.update!(trace: trace)
    rescue StandardError => e
      run_item.update!(error: e.message)
    end
  end
end
```

### Job: `Observ::DatasetRunnerJob`

```ruby
# app/jobs/observ/dataset_runner_job.rb
module Observ
  class DatasetRunnerJob < ApplicationJob
    queue_as :default

    def perform(dataset_run_id)
      dataset_run = Observ::DatasetRun.find(dataset_run_id)
      Observ::DatasetRunnerService.new(dataset_run).call
    end
  end
end
```

---

## Phase 4: Advanced Features (Future)

- CSV import for bulk item creation
- "Create item from trace" action on trace show page
- Run comparison view (side-by-side)
- Aggregate metrics/scores display
- Filtering and searching within datasets

---

## Files to Create

### Phase 1

| Type | Path |
|------|------|
| Migration | `db/migrate/010_create_observ_datasets.rb` |
| Migration | `db/migrate/011_create_observ_dataset_items.rb` |
| Migration | `db/migrate/012_create_observ_dataset_runs.rb` |
| Migration | `db/migrate/013_create_observ_dataset_run_items.rb` |
| Model | `app/models/observ/dataset.rb` |
| Model | `app/models/observ/dataset_item.rb` |
| Model | `app/models/observ/dataset_run.rb` |
| Model | `app/models/observ/dataset_run_item.rb` |
| Factory | `spec/factories/observ/observ_datasets.rb` |
| Spec | `spec/models/observ/dataset_spec.rb` |
| Spec | `spec/models/observ/dataset_item_spec.rb` |
| Spec | `spec/models/observ/dataset_run_spec.rb` |
| Spec | `spec/models/observ/dataset_run_item_spec.rb` |

### Phase 2

| Type | Path |
|------|------|
| Controller | `app/controllers/observ/datasets_controller.rb` |
| Controller | `app/controllers/observ/dataset_items_controller.rb` |
| Controller | `app/controllers/observ/dataset_runs_controller.rb` |
| Views | `app/views/observ/datasets/*.html.erb` |
| Views | `app/views/observ/dataset_items/*.html.erb` |
| Views | `app/views/observ/dataset_runs/*.html.erb` |
| Helper | `app/helpers/observ/datasets_helper.rb` |
| CSS | `app/assets/stylesheets/observ/datasets.css` |

### Phase 3

| Type | Path |
|------|------|
| Service | `app/services/observ/dataset_runner_service.rb` |
| Job | `app/jobs/observ/dataset_runner_job.rb` |
| Spec | `spec/services/observ/dataset_runner_service_spec.rb` |
| Spec | `spec/jobs/observ/dataset_runner_job_spec.rb` |

---

## Implementation Order

1. **Phase 1**: Create migrations, models, factories, and specs
2. **Phase 2**: Create controllers, views, routes, and navigation
3. **Phase 3**: Create runner service, job, and integrate with UI
4. **Phase 4**: Add advanced features as needed

Each phase should be completed and tested before moving to the next.
