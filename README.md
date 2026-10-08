# Repos Map

A workspace for investigating repositories and deciding what fits your project.

| Path | Contents |
| --- | --- |
| `compare-agents.sh` | Runs two Claude sessions in parallel |
| `.claude/agents/repo-reader.md` | A read-only subagent with the same tools as `compare-agents.sh` |
| `repos/` | Cloned repositories, ignored by Git |
| `notes/` | Your findings and project decisions |
| `results/` | Answers, token usage, elapsed time, and cost estimates |

Run a comparison with Opus 5.5 at medium effort:

```sh
bash compare-agents.sh repos/<candidate> "What does this repository do? Cite local files."
```

To choose another model, add its name between the repository path and the question.

Licensed under [MIT](LICENSE). Cloned repositories keep their own licenses.
