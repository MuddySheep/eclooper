# Repo navigation

This repository implements **ecloop**, a C-based tool for exploring the secp256k1 elliptic curve. It can brute-force or search private keys and is provided for educational use only.

## Structure
- `main.c` – command line entry point and search logic.
- `lib/` – cryptographic implementations (ECC, SHA-256, RIPEMD-160, utilities).
- `data/` – example hash lists and ranges for Bitcoin puzzles.
- `Makefile` – build rules and preset search examples.
- `_check.py` – optional script for remote verification across hosts.
- `to_hash.py` – convert Bitcoin addresses to hash160 format.

## Building
Run `make build` (uses `cc` by default). Use `make fmt` to format C code via `clang-format`.

## Quick commands
- `make add` – sequential search example. Should report ~9 keys.
- `make mul` – multiplication mode example with sample data.
- `make rnd` – random range search example.
- `make blf` – create and test a bloom filter from sample hashes.

Use `_check.py` to run the above commands on remote hosts: `python3 _check.py`.

## Ethical notice
Searching for private keys without permission may be illegal and unethical. This project is intended to study elliptic curves. Use it only on data and ranges you are authorized to examine. The authors and maintainers disclaim liability for misuse.

## Contribution guidelines
- Ensure code builds on macOS and Linux with `cc` or `clang`.
- Keep functions portable; avoid OS-specific code.
- Document any new options or changes in `readme.md`.
