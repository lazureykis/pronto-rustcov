# pronto-rustcov.gemspec
Gem::Specification.new do |spec|
  spec.name          = "pronto-rustcov"
  spec.version       = "0.1.11"
  spec.authors       = ["Pavel Lazureykis"]
  spec.email         = ["pavel@lazureykis.dev"]

  spec.summary       = "Pronto runner for Rust LCOV coverage"
  spec.description   = "This gem integrates Rust test coverage with Pronto via LCOV."
  spec.homepage      = "https://github.com/lazureykis/pronto-rustcov"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb"] + ['README.md']
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "pronto", "~> 0.11.4"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "simplecov", "~> 0.22.0"

  spec.required_ruby_version = ">= 3.2"
end
