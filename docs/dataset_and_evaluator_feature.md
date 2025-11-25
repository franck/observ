# Dataset & Evaluator System Implementation Guide

## Overview

This document provides a complete specification for implementing a dataset and evaluator system in an LLM observability tool. This system allows users to test LLM calls against predefined inputs, evaluate outputs, and track performance over time.

## High-Level Architecture

```
┌─────────────────┐
│    Dataset      │  Contains test cases (input + expected output)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Dataset Run    │  Execution of LLM against dataset items
└────────┬────────┘
         │
         ├──────────────────┐
         ▼                  ▼
┌─────────────────┐  ┌─────────────────┐
│  Trace/Span     │  │   Evaluators    │  Score the outputs
└────────┬────────┘  └────────┬────────┘
         │                     │
         ▼                     ▼
┌─────────────────────────────────┐
│          Scores                 │  Evaluation results
└─────────────────────────────────┘
```

## Core Concepts

### 1. Dataset
A collection of test cases used to evaluate LLM performance consistently.

**Purpose:**
- Create reproducible test sets
- Benchmark different prompts/models
- Track regression/improvement over time
- Enable A/B testing

**Components:**
- **Dataset**: Container for test items
- **Dataset Item**: Individual test case with input and optional expected output
- **Dataset Version**: Snapshot of dataset at a point in time (optional)

### 2. Dataset Run
An execution of your LLM against all items in a dataset.

**Purpose:**
- Link dataset items to actual LLM traces
- Group related executions
- Compare runs side-by-side

### 3. Evaluator
Code or logic that scores LLM outputs.

**Types:**
- **Manual**: Human reviews outputs in UI
- **LLM-as-Judge**: Use another LLM to score
- **Programmatic**: Custom code (regex, exact match, semantic similarity, etc.)

### 4. Score
Numerical or categorical result from an evaluator.

**Purpose:**
- Quantify output quality
- Aggregate across dataset
- Compare runs/experiments

---

## Data Models

### Dataset

```typescript
interface Dataset {
  id: string;
  name: string;
  description?: string;
  project_id: string;
  metadata?: Record<string, any>;
  created_at: timestamp;
  updated_at: timestamp;
}
```

### Dataset Item

```typescript
interface DatasetItem {
  id: string;
  dataset_id: string;
  
  // Core data
  input: any;  // JSON object with prompt variables
  expected_output?: any;  // Optional expected result
  
  // Context
  metadata?: Record<string, any>;
  source?: string;  // Where this example came from
  
  // Lifecycle
  status?: 'active' | 'archived';
  created_at: timestamp;
  updated_at: timestamp;
}
```

**Example Dataset Item:**
```json
{
  "id": "item_123",
  "dataset_id": "dataset_abc",
  "input": {
    "user_query": "Recommend articles for someone feeling anxious",
    "user_context": {
      "anxiety_level": 7,
      "previous_topics": ["breathing", "meditation"]
    },
    "available_articles": ["art_001", "art_002", "art_003"]
  },
  "expected_output": {
    "recommended_articles": ["art_001", "art_003"],
    "reasoning": "Focus on breathing techniques"
  },
  "metadata": {
    "category": "anxiety",
    "difficulty": "easy"
  }
}
```

### Dataset Run

```typescript
interface DatasetRun {
  id: string;
  dataset_id: string;
  name: string;
  description?: string;
  
  // Execution metadata
  metadata?: Record<string, any>;
  
  // Links to configuration used
  prompt_id?: string;  // If using prompt management
  prompt_version?: string;
  model_name?: string;
  model_parameters?: Record<string, any>;
  
  // Status
  status: 'running' | 'completed' | 'failed';
  
  // Timestamps
  created_at: timestamp;
  completed_at?: timestamp;
}
```

### Dataset Run Item

Links a dataset item to its execution trace.

```typescript
interface DatasetRunItem {
  id: string;
  dataset_run_id: string;
  dataset_item_id: string;
  trace_id: string;  // Link to your observability trace
  
  // Quick access to results
  output?: any;
  latency_ms?: number;
  token_count?: number;
  cost?: number;
  
  // Status
  status: 'pending' | 'success' | 'error';
  error?: string;
  
  created_at: timestamp;
}
```

### Score

```typescript
interface Score {
  id: string;
  
  // Links
  trace_id: string;
  observation_id?: string;  // Specific span/generation if nested
  dataset_run_id?: string;
  dataset_item_id?: string;
  
  // Score details
  name: string;  // e.g., "accuracy", "relevance", "hallucination"
  value: number | boolean | string;
  data_type: 'numeric' | 'boolean' | 'categorical';
  
  // Context
  source: 'manual' | 'llm_judge' | 'programmatic';
  comment?: string;
  config_id?: string;  // Link to evaluator config
  
  // For numeric scores
  min_value?: number;
  max_value?: number;
  
  created_at: timestamp;
  created_by?: string;  // User ID if manual
}
```

### Evaluator Config (Optional)

Store evaluator definitions for reuse.

```typescript
interface EvaluatorConfig {
  id: string;
  name: string;
  description?: string;
  
  // Type determines how it runs
  type: 'llm_judge' | 'programmatic' | 'webhook';
  
  // For LLM judges
  llm_config?: {
    model: string;
    prompt_template: string;
    criteria: string[];
    score_range: { min: number; max: number };
  };
  
  // For programmatic
  code?: string;  // If you support inline code
  webhook_url?: string;
  
  // Configuration
  score_name: string;
  score_data_type: 'numeric' | 'boolean' | 'categorical';
  
  created_at: timestamp;
  updated_at: timestamp;
}
```

---

## Implementation Workflow

### Phase 1: Dataset Management

#### API Endpoints

```
POST   /api/datasets
GET    /api/datasets
GET    /api/datasets/:id
PUT    /api/datasets/:id
DELETE /api/datasets/:id

POST   /api/datasets/:id/items
GET    /api/datasets/:id/items
GET    /api/datasets/:id/items/:item_id
PUT    /api/datasets/:id/items/:item_id
DELETE /api/datasets/:id/items/:item_id
```

#### Sample Implementation (Pseudo-code)

```python
# Create dataset
def create_dataset(name, description, metadata):
    dataset = Dataset(
        id=generate_id(),
        name=name,
        description=description,
        metadata=metadata,
        created_at=now()
    )
    db.save(dataset)
    return dataset

# Add items to dataset
def add_dataset_item(dataset_id, input_data, expected_output, metadata):
    item = DatasetItem(
        id=generate_id(),
        dataset_id=dataset_id,
        input=input_data,
        expected_output=expected_output,
        metadata=metadata,
        status='active',
        created_at=now()
    )
    db.save(item)
    return item

# Bulk import from existing traces
def import_from_traces(dataset_id, trace_ids):
    for trace_id in trace_ids:
        trace = db.get_trace(trace_id)
        add_dataset_item(
            dataset_id=dataset_id,
            input=trace.input,
            expected_output=trace.output,
            metadata={'source': 'trace', 'trace_id': trace_id}
        )
```

### Phase 2: Running Experiments

#### Client SDK Pattern

```python
# Python SDK example
class ObservabilityClient:
    
    def run_dataset(self, dataset_id, run_function, name=None, metadata=None):
        """
        Run a function against all items in a dataset.
        
        Args:
            dataset_id: ID of dataset to run
            run_function: Function that takes input and returns output
            name: Optional name for this run
            metadata: Optional metadata
        """
        # Create run
        run = self._create_dataset_run(
            dataset_id=dataset_id,
            name=name or f"Run {datetime.now()}",
            metadata=metadata,
            status='running'
        )
        
        # Get dataset items
        items = self._get_dataset_items(dataset_id)
        
        # Execute each item
        for item in items:
            try:
                # Create trace for this execution
                trace = self.trace(
                    name=f"dataset-run-{run.id}",
                    input=item.input,
                    metadata={
                        'dataset_run_id': run.id,
                        'dataset_item_id': item.id
                    }
                )
                
                # Run user's function
                with trace:
                    output = run_function(item.input)
                
                # Link to dataset run
                self._create_dataset_run_item(
                    dataset_run_id=run.id,
                    dataset_item_id=item.id,
                    trace_id=trace.id,
                    output=output,
                    status='success'
                )
                
            except Exception as e:
                self._create_dataset_run_item(
                    dataset_run_id=run.id,
                    dataset_item_id=item.id,
                    trace_id=trace.id if 'trace' in locals() else None,
                    status='error',
                    error=str(e)
                )
        
        # Mark run complete
        self._update_dataset_run(run.id, status='completed')
        
        return run
```

#### Usage Example

```python
from my_observability import ObservabilityClient

client = ObservabilityClient(api_key="...")

# Define your LLM function
def my_llm_call(input_data):
    response = openai.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a helpful assistant"},
            {"role": "user", "content": input_data['prompt']}
        ]
    )
    return response.choices[0].message.content

# Run against dataset
run = client.run_dataset(
    dataset_id="dataset_123",
    run_function=my_llm_call,
    name="GPT-4 baseline",
    metadata={"model": "gpt-4", "temperature": 0.7}
)
```

### Phase 3: Evaluation

#### 3.1 Programmatic Evaluators

```python
class ObservabilityClient:
    
    def score(self, trace_id, name, value, 
              data_type='numeric', 
              comment=None,
              observation_id=None,
              dataset_run_id=None,
              dataset_item_id=None):
        """Create a score for a trace."""
        score = Score(
            id=generate_id(),
            trace_id=trace_id,
            observation_id=observation_id,
            dataset_run_id=dataset_run_id,
            dataset_item_id=dataset_item_id,
            name=name,
            value=value,
            data_type=data_type,
            source='programmatic',
            comment=comment,
            created_at=now()
        )
        self._save_score(score)
        return score
    
    def evaluate_run(self, dataset_run_id, evaluator_function):
        """
        Run an evaluator against all items in a dataset run.
        
        Args:
            dataset_run_id: The run to evaluate
            evaluator_function: Function(output, expected_output, input) -> score
        """
        run_items = self._get_dataset_run_items(dataset_run_id)
        
        for run_item in run_items:
            dataset_item = self._get_dataset_item(run_item.dataset_item_id)
            trace = self._get_trace(run_item.trace_id)
            
            # Run evaluator
            score_value = evaluator_function(
                output=run_item.output,
                expected_output=dataset_item.expected_output,
                input=dataset_item.input
            )
            
            # Save score
            self.score(
                trace_id=run_item.trace_id,
                name=evaluator_function.__name__,
                value=score_value,
                dataset_run_id=dataset_run_id,
                dataset_item_id=run_item.dataset_item_id
            )
```

#### Example Evaluators

```python
# Exact match
def exact_match(output, expected_output, input):
    return 1.0 if output == expected_output else 0.0

# Contains keywords
def contains_required_keywords(output, expected_output, input):
    required = input.get('required_keywords', [])
    found = sum(1 for kw in required if kw.lower() in output.lower())
    return found / len(required) if required else 1.0

# JSON structure validation
def valid_json_structure(output, expected_output, input):
    import json
    try:
        data = json.loads(output)
        required_fields = input.get('required_fields', [])
        has_all = all(field in data for field in required_fields)
        return 1.0 if has_all else 0.0
    except:
        return 0.0

# Run evaluations
client.evaluate_run(
    dataset_run_id="run_123",
    evaluator_function=exact_match
)

client.evaluate_run(
    dataset_run_id="run_123",
    evaluator_function=contains_required_keywords
)
```

#### 3.2 LLM-as-Judge

```python
class LLMJudgeEvaluator:
    
    def __init__(self, client, model="gpt-4", criteria=None):
        self.client = client
        self.model = model
        self.criteria = criteria or ["accuracy", "relevance", "coherence"]
    
    def evaluate(self, output, expected_output, input):
        """Use LLM to judge output quality."""
        
        prompt = f"""You are an expert evaluator. Score the following output on a scale of 0-10.

Input: {input}

Expected Output: {expected_output}

Actual Output: {output}

Criteria to evaluate:
{chr(10).join(f'- {c}' for c in self.criteria)}

Provide a score from 0-10 where:
- 0-3: Poor quality
- 4-6: Acceptable
- 7-9: Good
- 10: Excellent

Return ONLY a JSON object with this format:
{{"score": <number>, "reasoning": "<explanation>"}}
"""
        
        response = openai.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0
        )
        
        import json
        result = json.loads(response.choices[0].message.content)
        return result['score'] / 10  # Normalize to 0-1
    
    def evaluate_run(self, dataset_run_id):
        """Evaluate all items in a run using LLM judge."""
        run_items = self.client._get_dataset_run_items(dataset_run_id)
        
        for run_item in run_items:
            dataset_item = self.client._get_dataset_item(run_item.dataset_item_id)
            
            score = self.evaluate(
                output=run_item.output,
                expected_output=dataset_item.expected_output,
                input=dataset_item.input
            )
            
            self.client.score(
                trace_id=run_item.trace_id,
                name="llm_judge_score",
                value=score,
                source='llm_judge',
                dataset_run_id=dataset_run_id,
                dataset_item_id=run_item.dataset_item_id
            )

# Usage
judge = LLMJudgeEvaluator(
    client=client,
    model="gpt-4",
    criteria=["accuracy", "helpfulness", "safety"]
)

judge.evaluate_run("run_123")
```

#### 3.3 Manual Evaluation

Provide UI for humans to review and score outputs.

**API Endpoints:**
```
GET  /api/dataset-runs/:run_id/items        # List items to review
POST /api/scores                            # Submit manual score
GET  /api/dataset-runs/:run_id/scores       # Get all scores for run
```

**UI Flow:**
1. Show output side-by-side with expected output
2. Display input context
3. Provide scoring interface (1-5 stars, thumbs up/down, numeric, etc.)
4. Allow comments
5. Track which items reviewed vs pending

### Phase 4: Analysis & Aggregation

#### Aggregate Scores by Run

```python
def get_run_metrics(dataset_run_id):
    """Calculate aggregate metrics for a run."""
    
    run_items = db.get_dataset_run_items(dataset_run_id)
    scores = db.get_scores(dataset_run_id=dataset_run_id)
    
    # Group scores by name
    score_groups = {}
    for score in scores:
        if score.name not in score_groups:
            score_groups[score.name] = []
        score_groups[score.name].append(score.value)
    
    # Calculate aggregates
    metrics = {
        'total_items': len(run_items),
        'completed_items': len([i for i in run_items if i.status == 'success']),
        'failed_items': len([i for i in run_items if i.status == 'error']),
        'avg_latency_ms': sum(i.latency_ms for i in run_items) / len(run_items),
        'total_tokens': sum(i.token_count for i in run_items if i.token_count),
        'total_cost': sum(i.cost for i in run_items if i.cost),
        'scores': {}
    }
    
    # Aggregate each score type
    for score_name, values in score_groups.items():
        metrics['scores'][score_name] = {
            'mean': sum(values) / len(values),
            'min': min(values),
            'max': max(values),
            'count': len(values)
        }
    
    return metrics
```

#### Compare Runs

```python
def compare_runs(run_ids):
    """Compare metrics across multiple runs."""
    
    comparison = {}
    
    for run_id in run_ids:
        run = db.get_dataset_run(run_id)
        metrics = get_run_metrics(run_id)
        
        comparison[run_id] = {
            'name': run.name,
            'created_at': run.created_at,
            'metadata': run.metadata,
            'metrics': metrics
        }
    
    return comparison

# Example output
{
    "run_abc": {
        "name": "GPT-4 baseline",
        "metrics": {
            "scores": {
                "accuracy": {"mean": 0.85, "min": 0.6, "max": 1.0},
                "relevance": {"mean": 0.92, "min": 0.8, "max": 1.0}
            },
            "avg_latency_ms": 1200,
            "total_cost": 0.45
        }
    },
    "run_xyz": {
        "name": "GPT-3.5 optimized",
        "metrics": {
            "scores": {
                "accuracy": {"mean": 0.78, "min": 0.5, "max": 0.95},
                "relevance": {"mean": 0.88, "min": 0.7, "max": 1.0}
            },
            "avg_latency_ms": 800,
            "total_cost": 0.12
        }
    }
}
```

---

## API Reference

### REST API Endpoints

```
# Datasets
POST   /api/datasets
GET    /api/datasets
GET    /api/datasets/:id
PUT    /api/datasets/:id
DELETE /api/datasets/:id

# Dataset Items
POST   /api/datasets/:id/items
GET    /api/datasets/:id/items
GET    /api/datasets/:id/items/:item_id
PUT    /api/datasets/:id/items/:item_id
DELETE /api/datasets/:id/items/:item_id
POST   /api/datasets/:id/items/bulk        # Bulk import

# Dataset Runs
POST   /api/dataset-runs
GET    /api/dataset-runs
GET    /api/dataset-runs/:id
GET    /api/dataset-runs/:id/items
GET    /api/dataset-runs/:id/metrics

# Scores
POST   /api/scores
GET    /api/scores
GET    /api/traces/:trace_id/scores
GET    /api/dataset-runs/:run_id/scores

# Evaluators
POST   /api/evaluators                     # Create evaluator config
GET    /api/evaluators
GET    /api/evaluators/:id
POST   /api/evaluators/:id/run             # Run evaluator on dataset
```

### Request/Response Examples

#### Create Dataset

```http
POST /api/datasets
Content-Type: application/json

{
  "name": "Article Recommendations Test Set",
  "description": "Test cases for article recommendation system",
  "metadata": {
    "version": "1.0",
    "category": "recommendations"
  }
}
```

Response:
```json
{
  "id": "dataset_abc123",
  "name": "Article Recommendations Test Set",
  "description": "Test cases for article recommendation system",
  "metadata": {
    "version": "1.0",
    "category": "recommendations"
  },
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

#### Add Dataset Item

```http
POST /api/datasets/dataset_abc123/items
Content-Type: application/json

{
  "input": {
    "user_query": "I'm feeling anxious about work",
    "user_context": {
      "anxiety_level": 7,
      "topics": ["work", "stress"]
    }
  },
  "expected_output": {
    "article_ids": ["art_001", "art_005"],
    "reasoning": "Work-related stress management"
  },
  "metadata": {
    "difficulty": "medium",
    "category": "work_anxiety"
  }
}
```

#### Create Dataset Run

```http
POST /api/dataset-runs
Content-Type: application/json

{
  "dataset_id": "dataset_abc123",
  "name": "GPT-4 v1 baseline",
  "metadata": {
    "model": "gpt-4",
    "temperature": 0.7,
    "prompt_version": "v1"
  }
}
```

#### Submit Score

```http
POST /api/scores
Content-Type: application/json

{
  "trace_id": "trace_xyz789",
  "dataset_run_id": "run_def456",
  "dataset_item_id": "item_ghi789",
  "name": "accuracy",
  "value": 0.85,
  "data_type": "numeric",
  "source": "programmatic",
  "comment": "Correctly identified top 2 articles"
}
```

---

## Database Schema

### PostgreSQL Example

```sql
-- Datasets
CREATE TABLE datasets (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    project_id VARCHAR(255) NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Dataset Items
CREATE TABLE dataset_items (
    id VARCHAR(255) PRIMARY KEY,
    dataset_id VARCHAR(255) NOT NULL REFERENCES datasets(id) ON DELETE CASCADE,
    input JSONB NOT NULL,
    expected_output JSONB,
    metadata JSONB,
    source VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_dataset_items_dataset_id (dataset_id),
    INDEX idx_dataset_items_status (status)
);

-- Dataset Runs
CREATE TABLE dataset_runs (
    id VARCHAR(255) PRIMARY KEY,
    dataset_id VARCHAR(255) NOT NULL REFERENCES datasets(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    metadata JSONB,
    prompt_id VARCHAR(255),
    prompt_version VARCHAR(255),
    model_name VARCHAR(255),
    model_parameters JSONB,
    status VARCHAR(50) NOT NULL DEFAULT 'running',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,
    
    INDEX idx_dataset_runs_dataset_id (dataset_id),
    INDEX idx_dataset_runs_status (status),
    INDEX idx_dataset_runs_created_at (created_at)
);

-- Dataset Run Items (links items to traces)
CREATE TABLE dataset_run_items (
    id VARCHAR(255) PRIMARY KEY,
    dataset_run_id VARCHAR(255) NOT NULL REFERENCES dataset_runs(id) ON DELETE CASCADE,
    dataset_item_id VARCHAR(255) NOT NULL REFERENCES dataset_items(id) ON DELETE CASCADE,
    trace_id VARCHAR(255) NOT NULL,  -- References your traces table
    output JSONB,
    latency_ms INTEGER,
    token_count INTEGER,
    cost DECIMAL(10, 6),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    error TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_run_items_run_id (dataset_run_id),
    INDEX idx_run_items_item_id (dataset_item_id),
    INDEX idx_run_items_trace_id (trace_id),
    UNIQUE (dataset_run_id, dataset_item_id)
);

-- Scores
CREATE TABLE scores (
    id VARCHAR(255) PRIMARY KEY,
    trace_id VARCHAR(255) NOT NULL,  -- References your traces table
    observation_id VARCHAR(255),     -- Optional: specific span
    dataset_run_id VARCHAR(255) REFERENCES dataset_runs(id) ON DELETE CASCADE,
    dataset_item_id VARCHAR(255) REFERENCES dataset_items(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    value TEXT NOT NULL,  -- Store as text, cast based on data_type
    data_type VARCHAR(50) NOT NULL,  -- 'numeric', 'boolean', 'categorical'
    source VARCHAR(50) NOT NULL,     -- 'manual', 'llm_judge', 'programmatic'
    comment TEXT,
    config_id VARCHAR(255),          -- Optional: link to evaluator config
    min_value DECIMAL(10, 4),
    max_value DECIMAL(10, 4),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by VARCHAR(255),         -- User ID if manual
    
    INDEX idx_scores_trace_id (trace_id),
    INDEX idx_scores_run_id (dataset_run_id),
    INDEX idx_scores_item_id (dataset_item_id),
    INDEX idx_scores_name (name),
    INDEX idx_scores_created_at (created_at)
);

-- Evaluator Configs (optional)
CREATE TABLE evaluator_configs (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL,  -- 'llm_judge', 'programmatic', 'webhook'
    llm_config JSONB,
    code TEXT,
    webhook_url VARCHAR(500),
    score_name VARCHAR(255) NOT NULL,
    score_data_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

---

## UI Components to Build

### 1. Dataset Management Page

**Features:**
- List all datasets
- Create new dataset
- Add/edit/delete items
- Import from traces (select traces and add to dataset)
- Bulk import via CSV/JSON
- View dataset statistics (number of items, categories, etc.)

### 2. Dataset Detail Page

**Features:**
- List all items in dataset
- Preview input/expected output
- Edit items inline
- Filter/search items
- View which runs used this dataset

### 3. Run Experiment Page

**Features:**
- Select dataset
- Choose prompt/model configuration
- Start run (shows progress)
- View real-time execution
- Cancel ongoing run

### 4. Run Results Page

**Features:**
- Overview metrics (avg scores, latency, cost)
- Item-by-item results table
  - Input | Output | Expected | Scores | Actions
- Filter by score threshold
- Manual review interface
- Export results

### 5. Compare Runs Page

**Features:**
- Select multiple runs
- Side-by-side comparison table
- Score distribution charts
- Statistical significance testing
- Item-level diff view

### 6. Evaluator Management

**Features:**
- List evaluators
- Create/edit evaluator configs
- Test evaluator on single item
- Run evaluator on past runs
- View evaluator performance history

---

## Implementation Priorities

### Phase 1: MVP (Minimum Viable Product)
1. Dataset CRUD operations
2. Dataset Item CRUD operations
3. Basic SDK method to run dataset
4. Link traces to dataset items
5. Programmatic score submission
6. Basic run metrics aggregation
7. Simple UI to view results

### Phase 2: Enhanced Evaluation
1. LLM-as-judge evaluator
2. Manual review UI
3. Evaluator configs
4. Compare runs UI
5. Score analytics/charts

### Phase 3: Advanced Features
1. Dataset versioning
2. Webhook evaluators
3. A/B test mode
4. Regression detection
5. Cost optimization suggestions
6. Export/import datasets

---

## Key Implementation Notes

### 1. Async Processing
Dataset runs can take a long time. Consider:
- Background job queue for run execution
- WebSocket for real-time progress updates
- Ability to pause/resume runs
- Error handling and retry logic

### 2. Performance
- Index heavily on `dataset_run_id`, `trace_id`, `dataset_item_id`
- Consider partitioning scores table if high volume
- Cache aggregate metrics
- Paginate large result sets

### 3. Security
- Validate dataset inputs (prevent injection)
- Rate limit LLM-as-judge calls
- Sandbox programmatic evaluators (if running user code)
- Audit log for manual scores

### 4. Extensibility
- Allow custom score types beyond numeric/boolean/categorical
- Support multiple evaluators per run
- Enable evaluator chaining (one evaluator's output feeds another)
- Plugin system for custom evaluators

### 5. Cost Management
- Track LLM-as-judge costs separately
- Provide cost estimates before running
- Allow budget limits per run
- Optimize by caching judge responses for identical inputs

---

## Example Use Cases

### Use Case 1: Prompt Optimization

```python
# Test 3 different prompts
prompts = [
    "You are a helpful assistant. {query}",
    "You are an expert. Be concise. {query}",
    "Think step by step. {query}"
]

for i, prompt_template in enumerate(prompts):
    def llm_call(input_data):
        return call_llm(prompt_template.format(query=input_data['query']))
    
    run = client.run_dataset(
        dataset_id="my_dataset",
        run_function=llm_call,
        name=f"Prompt v{i+1}"
    )
    
    # Evaluate
    client.evaluate_run(run.id, accuracy_evaluator)
    client.evaluate_run(run.id, conciseness_evaluator)

# Compare results
comparison = compare_runs([run1.id, run2.id, run3.id])
best_run = max(comparison.items(), key=lambda x: x[1]['metrics']['scores']['accuracy']['mean'])
print(f"Best prompt: {best_run[1]['name']}")
```

### Use Case 2: Model Selection

```python
# Compare GPT-4 vs Claude vs Gemini
models = ["gpt-4", "claude-3-opus", "gemini-pro"]

runs = []
for model in models:
    def llm_call(input_data):
        return call_model(model, input_data['prompt'])
    
    run = client.run_dataset(
        dataset_id="comparison_dataset",
        run_function=llm_call,
        name=f"{model} test",
        metadata={"model": model}
    )
    runs.append(run)
    
    # Evaluate
    judge = LLMJudgeEvaluator(client)
    judge.evaluate_run(run.id)

# Analyze cost vs quality tradeoff
for run in runs:
    metrics = get_run_metrics(run.id)
    print(f"{run.name}: Quality={metrics['scores']['llm_judge']['mean']:.2f}, Cost=${metrics['total_cost']:.4f}")
```

### Use Case 3: Regression Testing

```python
# Run daily regression tests
def daily_regression_test():
    dataset_id = "regression_suite"
    
    run = client.run_dataset(
        dataset_id=dataset_id,
        run_function=production_llm_call,
        name=f"Regression {date.today()}"
    )
    
    # Evaluate
    client.evaluate_run(run.id, accuracy_evaluator)
    
    # Check for regressions
    metrics = get_run_metrics(run.id)
    baseline_metrics = get_run_metrics("baseline_run_id")
    
    if metrics['scores']['accuracy']['mean'] < baseline_metrics['scores']['accuracy']['mean'] - 0.05:
        send_alert("REGRESSION DETECTED: Accuracy dropped!")
    
    return metrics

# Schedule this to run daily
```

---

## Testing Checklist

- [ ] Create dataset via API
- [ ] Add items to dataset
- [ ] Run dataset with SDK
- [ ] Link traces to dataset items
- [ ] Submit programmatic scores
- [ ] Calculate aggregate metrics
- [ ] Compare two runs
- [ ] Manual score submission
- [ ] LLM-as-judge evaluation
- [ ] Handle failed runs gracefully
- [ ] Test with large datasets (1000+ items)
- [ ] Concurrent run execution
- [ ] Export results to CSV

---

## References & Inspiration

This design is inspired by:
- **Langfuse**: Pioneered datasets + evaluators in LLM observability
- **MLflow**: Traditional ML experiment tracking
- **Weights & Biases**: Visualization and comparison tools
- **HuggingFace Evaluate**: Diverse evaluator library

## Conclusion

This implementation provides a complete system for testing and evaluating LLM applications. The key is flexibility - support multiple evaluation methods (manual, LLM, programmatic) and make it easy to iterate on prompts and models.

Start with the MVP (basic dataset runs + programmatic scores), then layer on advanced features based on user needs.
