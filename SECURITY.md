# Security

- No GitHub passwords, personal access tokens, OAuth secrets or ChatGPT cookies are accepted or saved.
- GitHub CLI manages authorization. Switching users changes the globally selected gh login on this machine.
- Git is invoked with OS.execute and literal argument arrays, without a command shell.
- The local configuration file stores only usernames, remote names, filesystem paths and executable paths.
- The mirror operation requires confirmation; before push it validates the primary origin, requires a clean checkout and exact local/origin branch SHAs.
- Git pushes never use --force and only target explicitly configured mirrors. A non-fast-forward mirror fails rather than being overwritten.
- Mirrored Actions workflows may have separate secrets, deploy permissions and billing effects. Administer mirrors independently.
- Do not commit local checkouts, credential files, private source or local configuration.
- In a production worker implement process timeouts, cancellation, output filtering, background execution, per-repository authentication isolation and audit logging.
- Automatic quota circumvention or use of unauthorized identities is not a supported workflow.
