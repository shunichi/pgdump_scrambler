## [Unreleased]

### Added

- Add zstd compression support. Use `compression` key in config to specify method (`gzip` / `zstd`) and level

### Fixed

- Fix `Dumper#initialize` not using `db_config` argument correctly

## [0.5.0] - 2024-03-01

- Resolve ERB on loading config/database.yml

## [0.4.1] - 2023-10-19

- Fix S3 upload

## [0.4.0] - 2023-10-18

- Add scramble functions
- Support ARM64 Linux/Mac

## [0.3.0] - 2023-04-13

- Prefer using YAML.safe_load over YAML.load
- Test with Rails 7.0

### Fixes

- Fix JSON number format error
