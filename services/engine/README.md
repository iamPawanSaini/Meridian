# services/engine

Python package `meridian_engine`. Empty until T13.

Planned modules: `config`, `data`, `scoring`, `llm`, `risk`, `simulation`, `store`,
`publish`, `cli`. Also planned: tests, a Dockerfile and Alembic migrations.

**Simulation only:** no broker SDK may be imported, and T18 adds a test that enforces this.
