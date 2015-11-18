require 'minitest/autorun'
require 'fastly2git'
require 'rugged'
require 'fileutils'

class Fastyl2GitTest < Minitest::Test
  def test_export
    dir = 'test_vcl'
    FileUtils.remove_dir(dir) if Dir.exist?(dir)
    repo = Rugged::Repository.init_at(dir)

    v1 = Minitest::Mock.new
    v1.expect :number, 1
    v1.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 1\n")
    v2 = Minitest::Mock.new
    v2.expect :number, 2
    v2.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 1\nVersion 2\n")
    v3 = Minitest::Mock.new
    v3.expect :number, 3
    v3.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 3\nVersion 3\n")

    Fastly2Git.git([v1, v2, v3], repo, false)

    repo = Rugged::Repository.new(dir)
    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 3'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 3\nVersion 3\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 2'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\nVersion 2\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 1'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\n"

    commit = commit.parents[0]
    assert_equal commit, nil

    FileUtils.remove_dir(dir) if Dir.exist?(dir)
  end
end
