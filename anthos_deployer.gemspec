
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'anthos_deployer/version'

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name          = 'anthos_deployer'
  spec.version       = AnthosDeployer::VERSION
  spec.authors       = ['Devops Developer']
  spec.email         = ['test@domain.com']

  spec.summary       = 'Anthos Deployer'
  spec.description   = 'Used to deploy anthos using helm charts'
  spec.homepage      = 'https://xyz.io'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'active_interaction', '~> 3.6'
  spec.add_dependency 'activesupport', '>= 4.2'
  spec.add_dependency 'awesome_print'
  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'colorize', '~> 0.8'
  spec.add_dependency 'figaro', '~> 1.1'
  spec.add_dependency 'googleauth', '>= 0.5'
  spec.add_dependency 'json'
  spec.add_dependency 'kubeclient', '~> 3.0'
  spec.add_dependency 'kubernetes-deploy', '0.20.1'
  spec.add_dependency 'rest-client', '>= 1.7' # Minimum required by kubeclient. Remove when kubeclient releases v3.0.
  spec.add_dependency 'statsd-instrument', '~> 2.1'
  spec.add_dependency 'parallel'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'minitest-stub-const', '~> 0.6'
  spec.add_development_dependency 'mocha', '~> 1.1'
  spec.add_development_dependency 'rake', '~> 10.5'
  spec.add_development_dependency 'webmock', '~> 3.0'
end
