# Contributing

Thank you for your interest in contributing! This document outlines the process and guidelines for
contributing to this project.

## Testing Changes

Suggested method for testing changes to these scripts:

- Modify `bootstrap.sh` to `git clone` your fork and branch of bonfire.
- Open a PR in a repo using bonfire pr_checks and the relevant scripts, modifying `pr_check` script
  to clone your fork and branch of bonfire.
- Observe modified scripts running in the relevant CI/CD pipeline.

## Getting Started

- Fork the repository
- Read the [project README][readme] and any additional documentation files for guidance on setting
  up the project locally
- Create a feature branch off the default branch with a descriptive name

## Opening a Pull Request

- Ensure your PR title is descriptive and summarizes the change
- Include a clear description of what the PR does and why the change is needed
- If your work is based on or co-authored with another contributor, credit them using the git
  co-author trailer format:

  ```text
  Co-authored-by: Name <email@example.com>
  ```

  This trailer should be added to the commit message itself, not the PR description

## Commit Messages

Write clear, descriptive commit messages that follow these guidelines:

- Use the imperative mood in the subject line (e.g., "Add feature" instead of "Added feature")
- Keep the subject line to 72 characters or less
- Separate the subject from the body with a blank line
- In the commit body, explain *what* changed and *why* it changed (not how)
- Reference relevant issues or discussions when applicable

## Signing Commits

All commits must be signed with a GPG or SSH key to verify your identity and ensure commit
integrity.

To enable signing for all commits on your machine:

```sh
git config --global commit.gpgSign true
```

For detailed setup instructions, refer to the
[git-commit signing documentation][git-commit-signing].

## AI-Assisted Commit Messages

If you use an AI agent or tool to generate or refine your commit message, the following rules apply:

1. **Author responsibility:** You must read, understand, and edit the AI-generated message before
   committing. The final commit message is your responsibility, and you must ensure it accurately
   describes your changes.

1. **Disclose the tool:** Add a `Co-authored-by:` trailer to the commit to credit the AI tool used.
   Example:

   ```text
   Co-authored-by: Claude Sonnet 4.6 <noreply@anthropic.com>
   ```

## Code Style

This library follows [Google's Shell style guide][shell-style-guide]. Functions are namespaced to
their module using the format `cicd::library::function`. ShellCheck is enforced on `./src` in CI —
ensure your changes pass ShellCheck before opening a PR.

## Code Review

All contributions go through code review. Be prepared to:

- Respond to feedback promptly
- Make requested changes in new commits (avoid force-pushing unless asked)
- Discuss design decisions and tradeoffs openly

Thank you for contributing!

[readme]: ./README.md
[git-commit-signing]: https://git-scm.com/docs/git-commit#Documentation/git-commit.txt--S
[shell-style-guide]: https://google.github.io/styleguide/shellguide.html
