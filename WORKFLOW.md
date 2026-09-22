# Research and delivery workflow

**Learn → Test → Build → Validate → Document → Demonstrate → Publish → Monetize**

| Stage | Action | Exit evidence |
|---|---|---|
| Learn | Define the problem, user, and relevant concepts | Objective, hypothesis, sources and unknowns |
| Test | Freeze inputs and run a baseline | Exact prompts, environment, outputs, evidence |
| Build | Develop the smallest useful improvement | Versioned prompt, workflow, or MQL5 source |
| Validate | Recalculate and attempt to disprove conclusions | Independent checks, mismatches and limitations |
| Document | Record success, failure and provenance | Complete experiment and daily log |
| Demonstrate | Reproduce the useful behavior | Demo script and linked evidence |
| Publish | Review claims and sanitize material | Reviewed case study or portfolio artifact |
| Monetize | Test a service or product hypothesis | Pilot scope, feedback, actual leads/revenue if known |

## Daily operating cycle

Suggested Kuwait-time schedule; adapt to actual availability.

| Time | Work | Output |
|---|---|---|
| 09:00–09:30 | Daily brief | One question, issue and acceptance criteria |
| 09:30–11:30 | Lab | Baseline and controlled test runs |
| 11:30–12:00 | Capture | Responses, evidence IDs, immediate observations |
| 12:00–13:30 | Build | Smallest useful artifact |
| 15:00–16:30 | Validate | Independent calculations and edge cases |
| 16:30–17:30 | Document | Experiment, prompt changes, daily report |
| 17:30–18:30 | Commercial assessment | Service/product hypothesis; no invented outcomes |
| Final 15 min | Daily close | Commit, issue status, next action |

Every day ends with a concrete artifact, including a documented failed test.

## Experiment lifecycle

Planned → Running → Validated / Inconclusive / Failed → Archived.
Use Blocked when missing data or access prevents execution. A negative result may be a completed experiment. Validated describes the scoped observation, not universal platform reliability or profitability.

1. Copy the experiment template and allocate the next unused EXP ID.
2. Declare expected outputs and checks before execution.
3. Freeze prompt version, date range, timezone, dataset and settings.
4. Save each run separately. Never overwrite inconvenient evidence.
5. Independently validate metrics against the input export or terminal.
6. Record discrepancies, limitations and actual business implications.
7. Update registers, report and issue; close only when evidence is documented.

## Evidence and publication

Name evidence `EXP001-01-AI-Settings.png`, `EXP001-02-Data-Access.png`, etc.
Include the run ID and timestamp in the evidence index. Distinguish observed, AI-generated, manually calculated, and synthetic material. Keep original sensitive exports outside Git; publish only sanitized derivatives.

Before publishing: inspect every staged file and screenshot, remove identifiers/secrets, check relative links, and ensure every outcome claim has evidence. Gitignore is not a privacy guarantee and does not untrack files.

## Definition of done

- Objective, environment, date range and inputs recorded.
- Exact prompt versions and responses retained.
- Acceptance criteria evaluated (pass, fail, blocked or inconclusive).
- Independent validation documented.
- Failures and limitations disclosed.
- Evidence sanitized and linked.
- Daily report, experiment register, issue and next action updated.
