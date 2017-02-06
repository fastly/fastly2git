class Fastly2Git
  require 'fastly'
  require 'rugged'
  require 'set'

  def self.versions(clioptions)
    fastly = Fastly.new(api_key: clioptions[:apikey])
    service = fastly.get_service(clioptions[:serviceid]) ||
              die("Couldn't find service #{options[:serviceid]}")

    puts "Service Name: #{service.name}" if clioptions[:verbose]
    service.versions.find_all(&:locked)
  end

  def self.local_versions(repo)
    local_versions = Set.new
    unless repo.empty?
      commit = repo.last_commit
      while commit
        local_versions.add(commit.message)
        commit = commit.parents[0]
      end
    end
    local_versions
  end

  def self.git(versions, repo, verbose)
    local_versions = local_versions(repo)
    versions.each do |version|
      options = version_to_options(repo, version)
      next if local_versions.include?(options[:message])
      puts 'Importing version...' if verbose
      begin
        vcl = version.generated_vcl
        oid = repo.write(vcl.content, :blob)
        repo.index.read_tree(repo.head.target.tree) unless repo.empty?
        repo.index.add(path: 'generated.vcl', oid: oid, mode: 0o100644)
        options[:tree] = repo.index.write_tree(repo)
      rescue Fastly::Error
        puts 'Could not fetch VCL' if verbose
      end
      Rugged::Commit.create(repo, options)
    end
    repo.checkout_head(strategy: :safe)
  end

  def self.version_to_options(repo, version)
    options = {}
    options[:tree] = repo.index.write_tree(repo)
    options[:author] = {
      email: 'user@fastly.com',
      name: 'Fastly User',
      time: Time.now
    }
    options[:committer] = {
      email: 'user@fastly.com',
      name: 'Fastly User',
      time: Time.now
    }
    options[:message] = "Version #{version.number}"
    options[:parents] = repo.empty? ? [] : [repo.head.target].compact
    options[:update_ref] = 'HEAD'
    options
  end
end
