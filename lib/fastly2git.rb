class Fastly2Git
  require 'fastly'
  require 'rugged'
  require 'set'

  def self.versions(clioptions)
    @fastly = Fastly.new(api_key: clioptions[:apikey])
    service = @fastly.get_service(clioptions[:serviceid]) ||
        die("Couldn't find service #{options[:serviceid]}")

    puts "Service Name is: #{service.name}" if clioptions[:verbose]
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

  def self.git(versions, repo, verbose, snippets, boilerplate)
    local_versions = local_versions(repo)
    versions.each do |version|
      options = version_to_options(repo, version)
      next if local_versions.include?(options[:message])
      puts "Importing version...#{version.number}" if verbose
      begin
        vcl = version.generated_vcl
        oid = repo.write(vcl.content, :blob)
        repo.index.read_tree(repo.head.target.tree) unless repo.empty?
        repo.index.add(path: 'generated.vcl', oid: oid, mode: 0o100644)

        if boilerplate
          puts "\tAdding boilerplate to commit"
          boilerplate_to_git(repo, version)
        end

        if snippets
          puts "\tAdding snippets to commit"
          snippets_to_git(repo, version)
        end
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

  private

  def self.boilerplate_to_git(repo, version)
    # Boilerplate
    # @type [Fastly::Client]

    # There is no option to retrieve HTML responses from the API so we have to force our own
    url = "/service/#{version.service_id}/version/#{version.number}{/boilerplate"
    headers = {}
    headers['Fastly-Key'] = @fastly.client.api_key
    boilerplateResponse = @fastly.client.http.get(url, headers)
    # Always cast to strings to address "null" issues
    boilerplateContent = boilerplateResponse.body.to_s
    boilerplateOid = repo.write(boilerplateContent, :blob);
    repo.index.add(path: 'boilerplate.vcl', oid: boilerplateOid, mode: 0o100644)
  end

  def self.snippets_to_git(repo, version)
    # @type [Array<Fastly::Snippet>]
    snippets = @fastly.list_snippets(service_id: version.service_id, version: version.number)
    snippets.each do |snippet|
      # Force string conversions as sometimes these can be null
      snippetType = snippet.type.to_s
      snippetName = snippet.name.to_s
      # Make all priorities 3 digits to improve sorting
      snippetPriority = snippet.priority.to_s.rjust(3, '0')
      # Sort snippets naturally via type, priority, and then name
      snippetFilepath = "snippets/#{snippetType}_#{snippetPriority}_#{snippetName}.vcl"
      # Some snippets are null, git requires them to be an empty string
      snippetContent = snippet.content.to_s
      soid = repo.write(snippetContent, :blob)
      repo.index.add(path: snippetFilepath, oid: soid, mode: 0o100644)
    end
  end

end
