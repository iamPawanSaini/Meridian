# Fixture only: partial data model, the checker must FAIL it on the missing parts
## Drupal content model
### Decision
| Field | Type | Validation | Indexed | Visible to |
|---|---|---|---|---|
| external_id | string | unique; regex ^dec-.+ | yes | all |
| symbol | string | regex ^[A-Z]+$ | yes | all |
| raw_llm_output | text | max 20000 | no | administrator |
## Postgres schema
### decisions
| Column | Type | Null |
|---|---|---|
| inputs_snapshot | jsonb | NOT NULL |
Primary key id. UNIQUE (trade_date, symbol, mode). index idx_a
