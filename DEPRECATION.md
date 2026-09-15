# Legacy Platform Deprecation Record

`C:\Users\Hokaido\.agents\` is the sole canonical global platform as of 2026-09-15.

`C:\Users\Hokaido\.agents-global\` remains on disk only as a deprecated historical record. Its shared PostgreSQL policy was compared byte-for-byte with the canonical policy before deprecation; its remaining synchronizer is retired and must not write configuration. Canonical synchronization originates only from `C:\Users\Hokaido\.agents\scripts\sync-agent-platform.ps1`.
