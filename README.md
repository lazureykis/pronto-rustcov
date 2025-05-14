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
