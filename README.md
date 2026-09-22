# MT5 AI Trading Lab

**Evidence-led research for AI Trading Solutions — MT5, MQL5, account diagnostics, strategy testing, and broker education.**

Maintained by **Meshal Al-Sultan · Mask Trader**.

This repository is the source of truth for a professional and commercial transition into AI Trading Solutions. It connects reproducible experiments to technical demonstrations, portfolio case studies, broker services, and potential educational products.

> **Current status: EXP-001 empty-input review completed with limitations.**
> The review documents missing-data handling and the limits of self-audit. Populated-history diagnostic accuracy remains untested. [Read the methodology and evidence limits](experiments/EXP-001-account-diagnostic/RESULTS.md).

## Start here

1. Read the [research workflow](WORKFLOW.md).
2. Open [EXP-001 — Trading Account Diagnostic](experiments/EXP-001-account-diagnostic/README.md).
3. Record the actual MT5 build, model, permissions, demo account, and history coverage.
4. Run Tests A, B, and C; retain exact prompts, responses, and sanitized evidence.
5. Independently check the results, then complete the [daily log](reports/daily/2026-09-22.md).

## What this lab is building

| Track | Purpose | Evidence to produce |
|---|---|---|
| Career | Demonstrate AI Trading Solutions consulting capability | Reproducible demos and technical decisions |
| Authority | Build a credible portfolio | Experiments, limitations, case studies |
| B2B | Explore broker education and consulting services | Academy, diagnostic clinic, strategy lab, EA factory |
| Revenue | Explore Mask Trader products and services | Validated prompt packs, course and workshop pilots |

## For reviewers

- **CTO:** inspect data provenance, reproducibility, verification, failure handling, and future MQL5 source.
- **Recruiter:** follow the experiment-to-case-study trail and inspect the author's documented contribution.
- **Broker:** review [solution concepts](broker-solutions/README.md), deliverables, and pilot acceptance criteria.

The directories below describe intended work. Their existence does not imply a delivered product or verified capability.

## Repository map

```text
experiments/        Experiment register, reusable template, EXP-001
case-studies/       Evidence-backed portfolio narratives and template
prompts/            Versioned prompts across five research categories
mql5/               indicators/, experts/, scripts/ — source only when built
reports/            daily/ and weekly/ research records and templates
assets/             screenshots/, charts/, results/ — sanitized evidence
products/           prompt-pack/, course/, workshop/ concepts
broker-solutions/   academy/, diagnostic-clinic/, strategy-lab/, ea-factory/
.github/            Issue templates and pull-request checklist
```

## Research standards

Every material conclusion must distinguish **observed facts**, **inferences**, and **unknowns**. Record failures alongside successes. AI self-audit is useful but does not replace independent validation. Platform/model capabilities are verified in the recorded environment, never assumed from a roadmap.

Use demo environments for initial experiments. Never commit credentials, account identifiers, raw client records, or unredacted financial exports. Only sanitized material belongs in this portfolio.

## Navigation

[30-day roadmap](ROADMAP.md) · [Experiment register](experiments/README.md) · [Prompt library](prompts/README.md) · [Daily reports](reports/daily/README.md) · [Weekly reports](reports/weekly/README.md) · [Project board fallback](PROJECT.md) · [Contributing](CONTRIBUTING.md)

## License

Original repository content is available under the [MIT License](LICENSE). Third-party data and platform software retain their own terms. Research and educational artifacts are not promises of financial performance.
