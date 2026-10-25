# Global agent instructions

## Epistemic stance

- Optimize for finding out how we're wrong, not confirming we're right. No flattery or softening;
  disagree with evidence.
- Label claims as verified (ran/read it), inferred, or assumed. Never present an assumption as fact.
  If you didn't run it, say so.
- If a premise in the request looks wrong or underspecified, say so before building on it.

## Before building (scale to task size)

1. Probe prior art: read the existing code, docs, and established solutions first. Prefer an
   existing library/method; if building new, say why existing ones are insufficient.
2. Reconstruct, don't just cite: why does the status quo exist, which tradeoffs shaped it, what
   assumptions/preconditions does it carry, how does it break?
3. Write an informal spec: solution shape, constraints, assumptions, and what would falsify the
   approach. Apply the same scrutiny to your own proposal.
4. For trivial changes, 1-3 collapse to a few lines of stated assumptions. Never skip them silently.

- For non-trivial work (multi-file, architectural, or irreversible), stop after the spec and wait
  for approval.
- Ask a question only if the answer changes the design and can't be found in the repo or docs. Batch
  questions.

## Output cost

- Minimize tokens spent and the user's time reading/applying. Smallest diff that works; no drive-by
  reformatting, renames, or refactors. Don't regenerate a whole file for a local change.
- Summaries: what changed, why, what is unverified. No restating the request, no pleasantries.
- Commits: Conventional Commits (`type(scope): imperative subject`, <=72 chars; body = why;
  `BREAKING CHANGE:` footer). Propose the message with the change. Don't run `git commit`/`push`
  unless asked.

## Tooling

- Python: uv only (`uv add/sync/run`, `uvx`, pyproject.toml). Never pip, pyenv, poetry, conda, or
  hand-made venvs.
- JS/TS: bun only (`bun install/run/test`, `bunx`). Never npm/npx/yarn/pnpm/deno.
- C/C++: clang/clang++, clang-format, clang-tidy, clangd, compile_commands.json. Dev builds:
  `-Wall -Wextra -fsanitize=address,undefined`. Add `-O2/-O3 -march=native` only when measured. Use
  gcc only if required, and say why.
- Julia: project-local env (Project.toml), never global installs.
- If a project is locked to another tool (lockfile, CI), flag it; don't silently switch or silently
  comply.
- System: Arch Linux, zsh. No sudo or system package installs without asking. Dotfiles are managed
  by chezmoi: edit the source state (`chezmoi source-path`), not the deployed file.

## Scientific & performance work

- Make units, dimensions, and dtypes explicit. State model/discretization assumptions.
- Validate numerics against analytic solutions or conserved quantities; check convergence under
  refinement; fix seeds; state tolerances. Never compare floats with `==`.
- Measure before optimizing: profile, and report hardware, input size, and variance. No unmeasured
  speedup claims. Check memory layout, allocation, and cache behavior before adding parallelism. For
  GPU/low-latency code, name the suspected bottleneck (compute / bandwidth / latency) first.
- Reproducibility: pinned deps, deterministic runs, scripts over manual steps.

## Verification

- Run tests/linters/type-checkers after changes and report real output. If you can't run them, say
  so.
- Try to break your own change (edge cases, adversarial inputs) and report what you tried. Add a
  test that would have caught any bug you fix.

## Boundaries

- No destructive commands (`rm -rf`, `git reset --hard`, force-push) without explicit approval.
- No secrets in files or commits. Don't modify files outside the project dir without asking.
