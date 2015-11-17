class Fastly2Git
  require 'fastly';
  require 'rugged';

  def self.versions(clioptions)
    fastly = Fastly.new(api_key: clioptions[:apikey])
    service = fastly.get_service(clioptions[:serviceid]) || die("Couldn't find service #{options[:serviceid]}")

    if clioptions[:verbose]
      puts "Service ID: #{service.id}"
      puts "Service Name: #{service.name}"
    end

    return service.versions
  end

  def self.git(versions, repo, verbose)
    versions.each do |version|
      puts "Importing version..." if verbose

      begin
        vcl = version.generated_vcl
      rescue Fastly::Error
        options = self.version_to_options(repo, version)
        Rugged::Commit.create(repo, options)
        next
      end

      oid = repo.write(vcl.content, :blob)
      if (!repo.empty?)
        repo.index.read_tree(repo.head.target.tree)
      end
      repo.index.add(:path => "generated.vcl", :oid => oid, :mode => 0100644)
      options = self.version_to_options(repo, version)
      Rugged::Commit.create(repo, options)
    end
    repo.checkout_head(:strategy => :safe)
  end

  def self.version_to_options(repo, version)
    options = {}
    options[:tree] = repo.index.write_tree(repo)
    options[:author] = { :email => "user@fastly.com", :name => 'Fastly User', :time => Time.now }
    options[:committer] = { :email => "user@fastly.com", :name => 'Fastly User', :time => Time.now }
    options[:message] ||= "Version #{version.number}"
    options[:parents] = repo.empty? ? [] : [ repo.head.target ].compact
    options[:update_ref] = 'HEAD'
    return options
  end
end
