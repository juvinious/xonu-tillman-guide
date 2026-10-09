# Publishing and contributing

[Back to README](../README.md)

The bundle is prepared for a public repository, but has not been pushed or published. Suggested repository name: **xonu-tillman-case-study**.

## Included public material

- Setup and troubleshooting documentation, with four topology paths.
- Original field-tested persistence installer and separate new helper scripts.
- Selected sanitized evidence and offline tests.
- MIT license for original code/documentation, with upstream credits.

Review the license choice and author attribution before publication. No claim is made that third-party firmware or templates are licensed by this repository.

## Excluded private material

Raw backups, pcaps, full environment dumps, original ONT serial, router/stick MACs, personal DNS names, login prompts, account data, and full Nokia web exports are not part of the bundle. The few evidence MAC bytes needed no diagnostic interpretation and were replaced with `[REDACTED_MAC]`.

The `.gitignore` helps avoid accidents but is not a sanitizer. Device `logread`, MIB dumps, packet captures, UCI exports and configuration backups may reveal identifiers or secrets. Keep newly collected files outside this folder and review them before adding anything. A capture helper's successful exit is not permission to publish its output blindly.

## Publish from the extracted folder

Create an empty repository in your GitHub account using its web UI. Then, from this folder, run the following commands separately (fish-compatible). Replace the example remote with your own repository:

```sh
git init -b main
git add .
git diff --cached --stat
git diff --cached
git commit -m "Document tested Tillman X-ONU-SFPP setup and recovery"
git remote add origin git@github.com:YOUR_ACCOUNT/xonu-tillman-case-study.git
git push -u origin main
```

The push publishes the staged files. Review the staged diff first. If your GitHub repository already has content, use its normal clone/merge workflow instead of these empty-repository commands.

## Contributions

For another successful installation, provide the underlying fiber operator, ONT model, 8311 version/revision, gateway/NIC/switch models, host-facing handoff tag or untagged state, bridge mode, sanitized mapper/GEM relationships, reconnect/reboot outcome and counter deltas. Never submit subscriber serials, credentials or complete backups.

Mark a proposed scenario as tested only after actual hardware validation. Keep provider-side VLANs, host-facing VLAN transformations and local management/transport VLANs explicitly separated.
