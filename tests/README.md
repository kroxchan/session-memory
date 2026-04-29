# Tests

## Setup

Install `bats-core` (Bash Automated Testing System):

```bash
# macOS
brew install bats-core

# Linux
sudo apt-get install bats

# Or from source
git clone https://github.com/bats-core/bats-core.git
./bats-core/install.sh ~/local
export PATH="$HOME/local/bin:$PATH"
```

## Run

```bash
bash tests/run.sh
```

Or directly with bats:

```bash
bats tests/sm-project-key.bats
bats tests/sm-write.bats
bats tests/sm-bootstrap.bats
bats tests/sm-recall.bats
bats tests/sm-compress.bats
```

## Coverage

| Script | Test cases | What it covers |
|--------|-----------|----------------|
| `sm-project-key.bats` | 7 | Key format, determinism, uniqueness, defaults, spaces, symlinks |
| `sm-write.bats` | 9 | File creation, append, INDEX sync, body-stdin, --current conflict, error cases |
| `sm-bootstrap.bats` | 9 | Dir creation, template rendering, skip-on-existing, output format |
| `sm-recall.bats` | 6 | Keyword search, case-insensitivity, empty results, error cases |
| `sm-compress.bats` | 5 | Filename slugification, INDEX update, error cases |
