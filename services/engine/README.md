# services/engine

Python package `meridian_engine`. Empty until T13.

Runs in the DDEV container `meridian-engine` (Python 3.12, from T06). Use `ddev engine <command>`.
T13 replaces the stock image with `services/engine/Dockerfile`.

Planned modules: `config`, `data`, `scoring`, `llm`, `risk`, `simulation`, `store`,
`publish`, `cli`. Also planned: tests, a Dockerfile and Alembic migrations.

**Simulation only:** no broker SDK may be imported, and T18 adds a test that enforces this.
