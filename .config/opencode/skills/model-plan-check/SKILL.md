---
name: model-plan-check
description: Review whether the configured OpenCode plan and build models remain the best fit for privacy, output quality, and provider rate limits. Use whenever the user asks to audit, verify, revisit, or recommend their plan/build models, including when model availability, subscriptions, provider policies, or usage limits may have changed.
---

# OpenCode plan/build model review

Evaluate the configured models for the user's two distinct workloads. The user has a strict privacy requirement: use only models whose inputs are not used for training. Treat that as an eligibility gate, not a score to trade against price, speed, or quality.

## User's workload profile

- **Plan:** high-complexity reasoning and planning sessions. Favor dependable multi-step reasoning, long-context comprehension when needed, and clear plans with useful tradeoffs.
- **Build:** high-volume coding with moderate complexity. Favor reliable tool use and code edits, throughput, latency, and sustainable rate limits without sacrificing a reasonable quality floor.
- **Privacy:** do not recommend a model unless the full serving route is affirmatively documented not to train on prompts, code, or outputs. If a term is missing, ambiguous, or only says data is not retained, mark it **unverified / not eligible** until confirmed.

At the time this skill was created, the global OpenCode config assigned `opencode-go/minimax-m3` to plan and `opencode-go/mimo-v2.6-flash` to build. Always re-read the live config; these names are just a useful starting point, not a source of truth.

## Review process

1. **Inspect the effective setup.** Read the relevant OpenCode config files and identify the `plan` and `build` model IDs, provider routes, and any model overrides. Check global and project-level config if applicable. Do not read or reveal API keys, environment files, or other credentials. If it is unclear which config is effective, say so rather than guessing.

2. **Resolve exact model routes.** Treat `provider/model` as a pair: the same underlying model through a different gateway can have different data handling, availability, and limits. Confirm current model IDs and availability from OpenCode's model catalog/provider documentation and the provider's official model list. Do not assume a model still exists because it appears in config.

3. **Verify privacy first.** Use current primary sources: the serving provider's privacy/data-use policy, applicable subscription or API terms, and OpenCode's policy when OpenCode or another gateway proxies the request. Confirm whether prompts, source code, tool outputs, and completions can be used for training or service improvement, including opt-outs, free-tier exceptions, preview programs, abuse monitoring, and subprocessors. Distinguish **no training** from **zero retention**; the user requires the former, but report retention separately. If a part of the serving chain cannot be verified, exclude that route from recommendations and explain what confirmation would resolve it. Never send private code to a model merely to test it.

4. **Check quality for each role.** Prefer recent, credible evidence relevant to agentic coding and the actual workload (tool calling, repository edits, instruction following, long-context planning, and coding benchmarks). Favor primary benchmark reports and transparent independent evaluations; note benchmark date, test setup, and limitations. Do not treat a single leaderboard or vendor claim as conclusive. Separate plan quality from build quality; a fast coding model need not be the best planner.

5. **Verify rate limits and practical capacity.** Check official provider docs and, when available, the user's account/subscription console for request/token throughput, concurrency, daily or weekly quotas, reset windows, usage caps, and overage behavior. Distinguish a hard rate limit from temporary outages and a depleted credit balance. Subscription limits are account- and plan-specific, so never invent or infer them from model specs or marketing copy. If account data is unavailable, mark limits **not verified** and ask for a redacted screenshot or the stated limits—never ask for API keys. For build, assess whether the documented capacity plausibly supports high-volume use; ask for approximate request/token volume if needed.

6. **Compare eligible candidates.** First remove privacy-ineligible or unavailable routes. Then compare current models and a small number of plausible alternatives on role-specific quality, verified throughput/quotas, latency, and cost where relevant. Cite evidence with direct links and the date checked. State clearly when evidence is missing or conflicting. Do not make a confident replacement recommendation based only on generic benchmark rank.

7. **Give a concise decision.** For each role, say **keep**, **replace**, or **not enough evidence**, with the reason and confidence. Explain the most important tradeoff and any account-specific unknown. Do not change configuration, connect providers, or run usage-consuming model tests unless the user explicitly asks and approves.

## Report format

Start with an overall verdict and the review date. Then provide a table:

| Role | Configured route | Privacy eligibility | Quality fit | Verified limits/capacity | Verdict |
|---|---|---|---|---|---|

Follow with:

- **Recommended setup:** plan and build choice, or state that no replacement is justified yet.
- **Why:** short role-specific rationale, including quality vs. rate-limit tradeoffs.
- **Unknowns to resolve:** only the facts that could change the recommendation.
- **Sources:** direct URLs, source type (official policy, account console, benchmark), and date checked.

Use explicit labels: **verified**, **unverified**, or **conflicting**. Never describe a route as privacy-safe based only on OpenCode's own privacy statement if a separate model provider/gateway also handles the request.
