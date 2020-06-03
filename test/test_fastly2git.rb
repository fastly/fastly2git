require 'minitest/autorun'
require 'fastly2git'
require 'rugged'
require 'fileutils'

class Fastyl2GitTest < Minitest::Test
  def version1
    v1 = Minitest::Mock.new
    v1.expect :number, 1
    v1.expect :locked, true
    v1.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 1\n")
    v1
  end

  def version2
    v2 = Minitest::Mock.new
    v2.expect :number, 2
    v2.expect :locked, true
    v2.expect :generated_vcl,
              (Minitest::Mock.new.expect :content, "Version 2\nVersion 2\n")
    v2
  end

  def version3
    v3 = Minitest::Mock.new
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

    Fastly2Git.git([version1], repo, false, false, false)
    repo = Rugged::Repository.new(dir)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 1'
    tree = commit.tree.first
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

    Fastly2Git.git([version1, version2, version3], repo, false, false, false)
    repo = Rugged::Repository.new(dir)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 3'

    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 3\nVersion 3\nVersion 3\n"
    commit = commit.parents[0]

    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 2'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 2\nVersion 2\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 1'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\n"

    commit = commit.parents[0]
    assert_equal commit, nil

    FileUtils.rm_rf(dir)
  end

  def test_incremental_export
    dir = 'test_incremental_vcl'
    FileUtils.rm_rf(dir)

    repo = Rugged::Repository.init_at(dir)

    Fastly2Git.git([version1, version2], repo, false, false, false)
    repo = Rugged::Repository.new(dir)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 2'

    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 2\nVersion 2\n"
    commit = commit.parents[0]

    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 1'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\n"

    Fastly2Git.git([version1, version2, version3], repo, false, false, false)

    ref = repo.head
    assert_equal ref.name, 'refs/heads/master'
    target_id = ref.target_id

    commit = repo.lookup(target_id)
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 3'

    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 3\nVersion 3\nVersion 3\n"
    commit = commit.parents[0]

    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 2'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 2\nVersion 2\n"

    commit = commit.parents[0]
    assert_equal commit.type, :commit
    assert_equal commit.message, 'Version 1'
    tree = commit.tree.first
    assert_equal tree[:name], 'generated.vcl'
    assert_equal repo.lookup(tree[:oid]).content, "Version 1\n"

    commit = commit.parents[0]
    assert_equal commit, nil

    FileUtils.rm_rf(dir)
  end
end
