# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{cap-ext-parallelize}
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mathias Meyer"]
  s.date = %q{2009-03-19}
  s.email = %q{meyer@paperplanes.de}
  s.files = ["Rakefile", "README.md", "VERSION.yml", "lib/cap_ext_parallelize.rb", "lib/capistrano", "lib/capistrano/configuration", "lib/capistrano/configuration/extensions", "lib/capistrano/configuration/extensions/actions", "lib/capistrano/configuration/extensions/actions/invocation.rb", "lib/capistrano/configuration/extensions/connections.rb", "lib/capistrano/configuration/extensions/execution.rb", "test/parallel_invocation_test.rb", "test/utils.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/mattmatt/cap-ext-parallelize}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{A drop-in replacement for Capistrano to fire off Webistrano deployments transparently without losing the joy of using the cap command.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<capistrano>, [">= 0"])
    else
      s.add_dependency(%q<capistrano>, [">= 0"])
    end
  else
    s.add_dependency(%q<capistrano>, [">= 0"])
  end
end
