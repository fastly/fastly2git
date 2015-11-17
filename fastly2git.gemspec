Gem::Specification.new do |s|
  s.name         = 'fastly2git'
  s.version      = '0.1.0'
  s.licenses     = 'MIT'
  s.summary      = 'fastly2git'
  s.description  = 'Create a git repository from Fastly service generated VCL'
  s.authors      = ['Leon Brocard']
  s.email        = ['lbrocard@fastly.com']
  s.files        = ['bin/fastly2git', 'lib/fastly2git.rb', 'test/test_fastly2git.rb']
  s.homepage     = 'https://github.com/fastly/fastly2git'
  s.add_development_dependency 'minitest', '>= 5.8.2'
  s.add_runtime_dependency     'fastly', '>= 1.2.0'
  s.add_runtime_dependency     'rugged', '>= 0.23.3'
  s.bindir       = 'bin'
  s.executables  = 'fastly2git'
  s.requirements << 'git'
end
