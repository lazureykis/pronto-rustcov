# pronto-rustcov

⚡ A [Pronto](https://github.com/prontolabs/pronto) runner that highlights **uncovered Rust lines** in GitHub pull requests using LCOV reports from [`cargo llvm-cov`](https://github.com/taiki-e/cargo-llvm-cov).

## 🔧 Installation

Add to your `Gemfile` in the `:development` group:

```ruby
gem 'pronto-rustcov', group: :development
```

Then install:

```bash
bundle install
```

Alternatively, install the gem globally:

```bash
gem install pronto-rustcov
```

## 🚀 Usage

Make sure you've generated an LCOV file using `cargo llvm-cov`:

```bash
cargo install cargo-llvm-cov
cargo llvm-cov clean
cargo llvm-cov --no-report
cargo llvm-cov report --lcov > target/lcov.info
```


## Github Actions Example

```yaml
name: Tests

permissions:
  contents: read
  pull-requests: write
  checks: write
  statuses: write

on:
  pull_request:
    branches:
      - main

jobs:
  tests:
    runs-on: ubuntu-latest

    steps:
      - name: Rust Toolchain Setup
        uses: actions-rust-lang/setup-rust-toolchain@v1
        with:
          components: llvm-tools-preview

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Install rustup component
        uses: taiki-e/install-action@cargo-llvm-cov

      - name: Run Tests
        run: |
          cargo llvm-cov clean
          cargo llvm-cov --no-report --workspace --no-cfg-coverage --remap-path-prefix
          cargo llvm-cov report --html
          cargo llvm-cov report --lcov > target/lcov.info

      - name: Run Pronto
        env:
          PRONTO_PULL_REQUEST_ID: ${{ github.event.pull_request.number }}
          PRONTO_GITHUB_ACCESS_TOKEN: "${{ github.token }}"
          PRONTO_RUSTCOV_FILES_LIMIT: 3
          PRONTO_RUSTCOV_MESSAGES_PER_FILE_LIMIT: 3
          PRONTO_RUSTCOV_LCOV_PATH: target/lcov.info
        run: |
          gem install pronto pronto-rustcov
          pronto run -f github_status github_pr -c origin/${{ github.base_ref }}
```

## 📝 License

MIT
