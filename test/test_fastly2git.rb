require 'minitest/autorun'
require 'fastly2git'
require 'rugged'
require 'fileutils'

class Fastyl2GitTest < Minitest::Test
  def version1
    v1 = Minitest::Mock.new
    v1.expect :number, 1
    v1.expect :number, 1
    v1.expect :locked, true
    v1.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 1\n")
    v1
  end

  def version2
    v2 = Minitest::Mock.new
    v2.expect :number, 2
    v2.expect :number, 2
    v2.expect :locked, true
    v2.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 2\nVersion 2\n")
    v2
  end

  def version3
    v3 = Minitest::Mock.new
    v3.expect :number, 3
    v3.expect :number, 3
    v3.expect :locked, true
    v3.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 3\nVersion 3\nVersion 3\n")
    v3
  end

def test_oneshot_single_export
    dir = 'test_oneshot_single_vcl'
    FileUtils.rm_rf(dir)

    repo = Rugged::Repository.init_at(dir)

    local_versions = Fastly2Git.local_versions(repo)

    details = { 1 => "{\"foo\":\"bar\",\"version\":{\"updated_at\":\"2018-12-25T12:34:56Z\",\"comment\":\"Some details\"}}" }

    Fastly2Git.git([version1], local_versions, details, repo, false)
    repo = Rugged::Repository.new(dir)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, "Version 1\n\nSome details\n"
    assert_equal commit.author[:time], Time.parse("2018-12-25 12:34:56 +0000")
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"Some details\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\n"

    commit = commit.parents[0]
    assert_equal commit, nil

    FileUtils.rm_rf(dir)
  end

  def test_oneshot_multiple_export
    dir = 'test_oneshot_multiple_vcl'
    FileUtils.rm_rf(dir)

    repo = Rugged::Repository.init_at(dir)

    local_versions = Fastly2Git.local_versions(repo)

    details = { 1 => "{\"foo\":\"bar\",\"version\":{\"comment\":\"Some details\"}}",
                2 => "{\"foo\":\"baz\",\"version\":{\"comment\":\"\"}}",
                3 => "{\"foo\":\"bax\",\"version\":{\"comment\":\"multi\\nline\"}}" }

    Fastly2Git.git([version1, version2, version3], local_versions, details, repo, false)
    repo = Rugged::Repository.new(dir)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, "Version 3\n\nmulti\nline\n"
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"multi\\nline\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 3\nVersion 3\nVersion 3\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 2'
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 2\nVersion 2\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, "Version 1\n\nSome details\n"
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"Some details\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
 

    commit = commit.parents[0]
    assert_equal commit, nil

    FileUtils.rm_rf(dir)
  end

  def test_incremental_export
    dir = 'test_incremental_vcl'
    FileUtils.rm_rf(dir)

    repo = Rugged::Repository.init_at(dir)

    local_versions = Fastly2Git.local_versions(repo)

    details = { 1 => "{\"foo\":\"bar\",\"version\":{\"comment\":\"Some details\"}}",
                2 => "{\"foo\":\"baz\",\"version\":{\"comment\":\"\"}}" }

    Fastly2Git.git([version1, version2], local_versions, details, repo, false)
    repo = Rugged::Repository.new(dir)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 2'
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 2\nVersion 2\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, "Version 1\n\nSome details\n"
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"Some details\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\n"

    commit = commit.parents[0]
    assert_equal commit, nil

    local_versions = Fastly2Git.local_versions(repo)

    details = { 1 => "{\"foo\":\"bar\",\"version\":{\"comment\":\"Some details\"}}",
                2 => "{\"foo\":\"baz\",\"version\":{\"comment\":\"\"}}",
                3 => "{\"foo\":\"bax\",\"version\":{\"comment\":\"multi\\nline\"}}" }

    Fastly2Git.git([version1, version2, version3], local_versions, details, repo, false)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, "Version 3\n\nmulti\nline\n"
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"multi\\nline\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 3\nVersion 3\nVersion 3\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 2'
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 2\nVersion 2\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, "Version 1\n\nSome details\n"
    tree = commit.tree[0]
    assert_equal tree[:name], 'details.json'
    assert_equal repo.lookup(tree[:oid]).content, "{\n  \"comment\": \"Some details\"\n}"
    tree = commit.tree[1]
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\n"

    commit = commit.parents[0]
    assert_equal commit, nil

    FileUtils.rm_rf(dir)
  end
end
