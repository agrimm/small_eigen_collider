$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require "small_eigen_collider"
require "test/unit"

class TestSecurity < Test::Unit::TestCase

  # This fails under JRuby, for any level of $SAFE
  # This fails under Rubinius, for any level of $SAFE
  # This probably fails under other platforms as well
  def test_deletion_security
    deletion_task = SmallEigenCollider::Task.new(File, :delete, "nosuchfile.txt")
    deletion_task.run
    assert deletion_task.security_error?, "#{deletion_task.inspect} attempts to delete a file"
  end
end

class TestProgramWorks < Test::Unit::TestCase
  def test_program_works
    addition_task = SmallEigenCollider::Task.new(1, "+", [1])
    addition_task.run
    assert addition_task.success?, "Can't add 1 and 1 together"
  end
end

class TestRoundtripping < Test::Unit::TestCase
  def test_roundtripping_works
    side_effective_task = SmallEigenCollider::Task.new("a", "<<", "b")
    side_effective_task.run
    first_yaml = YAML.dump(side_effective_task)
    yaml_created_task = YAML.load(first_yaml)
    yaml_created_task.reinitialize
    yaml_created_task.run
    second_yaml = YAML.dump(yaml_created_task)
    assert_equal first_yaml, second_yaml, "Side effects seem to be preventing a certain yaml being converted into an object that creates the same yaml"
  end
end
