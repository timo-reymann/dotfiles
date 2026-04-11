# Global Instructions

## Git Commits

When creating a git commit, include a `Co-Authored-By` trailer with the model name used.

Extract the model name from your own system prompt (visible in the conversation context -- look for the model identifier provided by the runtime). Format the trailer as:

```
Co-Authored-By: MODEL_NAME <noreply@opencode.ai>
```

Replace `MODEL_NAME` with the exact model identifier from your context. For example, if the system prompt shows `minimax-m2.5`, the trailer becomes:

```
Co-Authored-By: minimax-m2.5 <noreply@opencode.ai>
```

Include this trailer in every commit, whether you are the sole author or co-authoring with a human. Place it after any `Signed-off-by` trailer but before the blank line at the end of the commit message body.
