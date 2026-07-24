- Always evaluate the AGENTS.md file for the current project. Also
  notify the user if you found one or not.
- DeepL repos follow the **Golden Path for GitLab CI**
  (https://backstage.deepl.dev/docs/default/component/golden-path-ci): all
  CI under `.gitlab/ci/{components,pipelines,templates}` with the root
  `.gitlab-ci.yml` as the single import surface, one pipeline per trigger,
  `rules:` only on includes, and schedules version-controlled via schedula.
  Before editing a repo's CI, check for a `.gitlab/ci/CLAUDE.md` (or
  AGENTS.md) documenting where that repo diverges — don't "fix" a
  deliberate deviation.
