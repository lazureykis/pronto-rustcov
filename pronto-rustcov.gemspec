# pronto-rustcov.gemspec
Gem::Specification.new do |spec|
  spec.name          = "pronto-rustcov"
  spec.version       = "0.1.7"
  spec.authors       = ["Pavel Lazureykis"]
  spec.email         = ["pavel@lazureykis.dev"]

  spec.summary       = "Pronto runner for Rust LCOV coverage"
  spec.description   = "This gem integrates Rust test coverage with Pronto via LCOV."
  spec.homepage      = "https://github.com/lazureykis/pronto-rustcov"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "pronto", ">= 0.11.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"

  spec.required_ruby_version = ">= 2.7"
end
