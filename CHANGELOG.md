# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- `use ImmuTable` now automatically includes `use Ecto.Schema`, simplifying schema definitions

### Fixed

- Move inline test schemas to test/support to eliminate Inspect protocol consolidation warnings

## [0.5.2] - 2026-01-17

### Added

- SQLite compatibility with no-op advisory locks

## [0.5.1] - 2026-01-12

### Fixed

- Resolve join binding issue with `get_current/1`

## [0.5.0] - 2025-12-30

### Added

- UUIDv7 1.0 support
- Mix generators for ImmuTable schemas (`mix immutable.gen.schema`, `mix immutable.gen.migration`, `mix immutable.gen.context`)
- Hide row `id` from Inspect output by default (use `show_row_id: true` to override)
- Phoenix LiveView demo application
- Immutable associations (`immutable_belongs_to`, `immutable_has_many`, `immutable_has_one`)
- `ImmuTable.Multi` for composing operations within Ecto.Multi transactions
- Ergonomic query functions and pipe-friendly CRUD operations
- Hex package and ex_doc configuration

### Fixed

- Ensure ecto_sql 3.10+ compatibility

## [0.1.0] - 2025-12-02

### Added

- Initial release
- `immutable_schema` macro with automatic field injection (id, entity_id, version, valid_from, deleted_at)
- CRUD operations: `insert`, `update`, `delete`, `undelete`
- Query helpers: `get_current`, `include_deleted`, `history`, `at_time`, `all_versions`
- Blocking for direct `Repo.update` and `Repo.delete` operations
- Advisory locks for optimistic concurrency control
- Changeset filtering for protected fields

[Unreleased]: https://github.com/ckochx/immu_table/compare/v0.5.2...HEAD
[0.5.2]: https://github.com/ckochx/immu_table/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/ckochx/immu_table/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/ckochx/immu_table/compare/v0.1.0...v0.5.0
[0.1.0]: https://github.com/ckochx/immu_table/releases/tag/v0.1.0
