class Fastly2Git
  require 'fastly'
  require 'rugged'
  require 'set'
  require 'net/http'
  require 'json'
  require 'time'

  def self.versions(clioptions)
    fastly = Fastly.new(api_key: clioptions[:apikey])
    service = fastly.get_service(clioptions[:serviceid]) ||
              die("Couldn't find service #{options[:serviceid]}")

    puts "Service Name: #{service.name}" if clioptions[:verbose]
    service.versions.find_all(&:locked)
  end

  def self.details(versions, local_versions, clioptions)
    details = {}

    # Setup HTTP client because Fastly gem doesn't support parameters on service.details
    url = URI.parse("https://api.fastly.com")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    headers = { "Fastly-Key" => clioptions[:apikey] }

    versions.each do |version|
      vnumber = version.number
      commitmsg = "Version #{vnumber}"
      next if local_versions.include?(commitmsg)
      puts "Importing version #{vnumber} details" if clioptions[:verbose]
      resp = http.get("/service/#{version.service_id}/details?version=#{version.number}", headers)
      if resp.kind_of?(Net::HTTPSuccess)
        details[vnumber] = resp.body
      else
        puts 'Could not fetch service details' if clioptions[:verbose]
      end
    end
    details
  end

  def self.local_versions(repo)
    local_versions = Set.new
    unless repo.empty?
      commit = repo.last_commit
      while commit
        local_versions.add(commit.message.lines.first.strip)
        commit = commit.parents[0]
      end
    end
    local_versions
  end

  def self.git(versions, local_versions, details, repo, verbose)
    versions.each do |version|
      vnumber = version.number
      options = version_to_options(repo, version)
      next if local_versions.include?(options[:message])
      repo.index.read_tree(repo.head.target.tree) unless repo.empty?
      puts "Importing version #{vnumber} VCL" if verbose
      begin
        vcl = version.generated_vcl
        oid = repo.write(vcl.content, :blob)
        repo.index.add(path: 'generated.vcl', oid: oid, mode: 0o100644)
      rescue Fastly::Error
        puts 'Could not fetch VCL' if verbose
      end
      if details[vnumber]
        json = JSON.parse(details[vnumber])
        node = json["version"]
        updated_at = node["updated_at"]
        node.delete("updated_at");
        node.delete("created_at");
        node.delete("deleted_at");
        node.delete("deployed");
        node.delete("locked");
        node.delete("active");
        node.delete("testing");
        node.delete("staging");
        comment = node["comment"]
        if comment and comment != ""
          options[:message] << "\n\n#{comment}\n"
        end
        if updated_at
          options[:author][:time] = Time.parse(updated_at)
          options[:committer][:time] = Time.parse(updated_at)
        end
        oid = repo.write(JSON.pretty_generate(node), :blob)
        repo.index.add(path: 'details.json', oid: oid, mode: 0o100644)
      end
      options[:tree] = repo.index.write_tree(repo)
      Rugged::Commit.create(repo, options)
    end
    repo.checkout_head(strategy: :safe)
  end

  def self.version_to_options(repo, version)
    options = {}
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
