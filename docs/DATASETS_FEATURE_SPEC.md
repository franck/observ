# Datasets Feature Specification

## Overview

The Datasets feature provides a structured way to evaluate LLM applications by running them against curated test cases and tracking results over time. It enables teams to benchmark performance, compare different configurations, and ensure quality through repeatable evaluations.

---

## Core Concepts

### Dataset

A named collection of test cases belonging to a project. Think of it as a "test suite" for your LLM application.

### Dataset Item

An individual test case within a dataset containing:

- **Input**: The test data to feed into your LLM application
- **Expected Output**: The ground truth or ideal response (optional, used for comparison)
- **Metadata**: Additional context or tags for organizing items

### Dataset Run

A single evaluation execution against a dataset. Each time you run your application against the dataset's items, a new run is created. Runs are named and can be compared against each other.

### Dataset Run Item

Links an individual dataset item to its execution result. Records which trace/observation was produced when running a specific input.

---

## Data Model

```
┌─────────────────────────────────────────────────────────────────┐
│                           Dataset                                │
├─────────────────────────────────────────────────────────────────┤
│ id              │ Primary key                                    │
│ project_id      │ FK to projects                                 │
│ name            │ Unique name within project                     │
│ description     │ Optional description                           │
│ metadata        │ JSON - arbitrary key/value pairs               │
│ created_at      │ Timestamp                                      │
│ updated_at      │ Timestamp                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Dataset Item                              │
├─────────────────────────────────────────────────────────────────┤
│ id              │ Primary key                                    │
│ project_id      │ FK to projects                                 │
│ dataset_id      │ FK to datasets                                 │
│ status          │ Enum: active, archived                         │
│ input           │ JSON - the test input                          │
│ expected_output │ JSON - ground truth (optional)                 │
│ metadata        │ JSON - arbitrary key/value pairs               │
│ source_trace_id │ FK to traces (optional) - if created from trace│
│ created_at      │ Timestamp                                      │
│ updated_at      │ Timestamp                                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        Dataset Run                               │
├─────────────────────────────────────────────────────────────────┤
│ id              │ Primary key                                    │
│ project_id      │ FK to projects                                 │
│ dataset_id      │ FK to datasets                                 │
│ name            │ Unique name within dataset (e.g., "v1.2-gpt4") │
│ description     │ Optional description                           │
│ metadata        │ JSON - arbitrary key/value pairs               │
│ created_at      │ Timestamp                                      │
│ updated_at      │ Timestamp                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Dataset Run Item                             │
├─────────────────────────────────────────────────────────────────┤
│ id              │ Primary key                                    │
│ project_id      │ FK to projects                                 │
│ dataset_run_id  │ FK to dataset_runs                             │
│ dataset_item_id │ FK to dataset_items                            │
│ trace_id        │ FK to traces - the execution result            │
│ observation_id  │ FK to observations (optional)                  │
│ created_at      │ Timestamp                                      │
│ updated_at      │ Timestamp                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Entity Relationships

```
Dataset (1) ─────────── (N) Dataset Items
    │
    └──────── (N) Dataset Runs
                    │
                    └──── (N) Dataset Run Items ──── (1) Trace
                                   │
                                   └──── (1) Dataset Item
```

---

## User Workflow

### 1. Create a Dataset

User creates a named dataset to hold their test cases.

### 2. Add Items to Dataset

Items can be added via:

- **Manual entry**: User enters input/expected output directly
- **CSV import**: Bulk upload from spreadsheet
- **From existing trace**: Convert a production trace into a test case

### 3. Run Evaluation

User executes their LLM application against all items in the dataset:

- Each item's input is processed
- The resulting trace is linked back to the dataset item
- A named "run" groups all executions together

### 4. Review & Compare Results

User can:

- View individual run results
- Compare multiple runs side-by-side
- See aggregate metrics (scores, latency, cost) per run
- Track improvement over time

---

## UI Components Needed

### Dataset List Page

- Table showing all datasets in a project
- Columns: Name, Description, Item Count, Run Count, Last Run Date
- Actions: Create, Edit, Delete, Duplicate

### Dataset Detail Page (Runs View)

- List of all runs for this dataset
- Columns: Run Name, Created At, Item Count, Aggregate Scores
- Actions: View Run, Delete Run, Compare Runs

### Dataset Items View

- Table of all items in the dataset
- Columns: Input (preview), Expected Output (preview), Status, Created At
- Actions: Add Item, Edit Item, Archive Item, Delete Item

### Single Item Detail

- Full view of input and expected output
- List of all runs this item participated in
- Actual outputs from each run for comparison

### Run Detail Page

- All run items with their results
- Columns: Input, Expected Output, Actual Output, Scores, Latency
- Aggregate metrics at the top

### Run Comparison Page

- Side-by-side comparison of 2+ runs
- Each row is a dataset item
- Columns show actual output from each run
- Highlight differences or score changes

### Forms

- Create/Edit Dataset form (name, description, metadata)
- Create/Edit Dataset Item form (input, expected output, metadata)
- CSV Import wizard with preview

---

## Key Features

### Item Status

Items can be **active** or **archived**. Archived items are excluded from new runs but historical data is preserved.

### Metadata

All entities support arbitrary JSON metadata for:

- Tagging and filtering
- Storing configuration used during a run
- Custom attributes specific to your use case

### Source Trace Linking

When creating items from existing traces, maintain the link for traceability. This allows users to understand where test cases originated.

### Scores Integration

Run items should link to your existing scoring system:

- Attach scores to individual run items (per-trace evaluation)
- Aggregate scores at the run level for comparison
- Support multiple score types (accuracy, latency, cost, custom)

---

## Suggested Database Migrations

```ruby
# Migration 1: Create datasets table
create_table :datasets do |t|
  t.references :project, null: false, foreign_key: true
  t.string :name, null: false
  t.text :description
  t.jsonb :metadata, default: {}
  t.timestamps

  t.index [:project_id, :name], unique: true
end

# Migration 2: Create dataset_items table
create_table :dataset_items do |t|
  t.references :project, null: false, foreign_key: true
  t.references :dataset, null: false, foreign_key: true
  t.integer :status, default: 0, null: false  # enum: active, archived
  t.jsonb :input
  t.jsonb :expected_output
  t.jsonb :metadata, default: {}
  t.references :source_trace, foreign_key: { to_table: :traces }
  t.timestamps

  t.index [:dataset_id, :status]
end

# Migration 3: Create dataset_runs table
create_table :dataset_runs do |t|
  t.references :project, null: false, foreign_key: true
  t.references :dataset, null: false, foreign_key: true
  t.string :name, null: false
  t.text :description
  t.jsonb :metadata, default: {}
  t.timestamps

  t.index [:dataset_id, :name], unique: true
end

# Migration 4: Create dataset_run_items table
create_table :dataset_run_items do |t|
  t.references :project, null: false, foreign_key: true
  t.references :dataset_run, null: false, foreign_key: true
  t.references :dataset_item, null: false, foreign_key: true
  t.references :trace, null: false, foreign_key: true
  t.references :observation, foreign_key: true
  t.timestamps

  t.index [:dataset_run_id, :dataset_item_id], unique: true
end
```

---

## Notes

- **Project scoping**: All queries should be scoped to the current project
- **Soft delete consideration**: Consider soft deletes for datasets/items to preserve historical run data
- **Performance**: For large datasets, paginate items and consider async processing for runs
- **Permissions**: Dataset management should follow your existing RBAC patterns
