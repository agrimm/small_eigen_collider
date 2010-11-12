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
