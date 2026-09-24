---
description: Always automatically push fixes, updates, and debugged code to the GitHub repository.
globs: *
---

# Automatic Git Synchronization Rule

Whenever code is updated, bug fixes are applied, or debugged changes are completed:
1. Stage all changes (`git add .`).
2. Create a meaningful commit describing the change.
3. Automatically push the commit to `origin main` using `git push origin main` (bypassing sandbox if network access is required).
4. Verify the remote repository is updated before concluding the turn.
