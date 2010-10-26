$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require "small_eigen_collider"
require "test/unit"

class TestSecurity < Test::Unit::TestCase

  def test_deletion_security
    deletion_task = SmallEigenCollider::Task.new(File, :delete, "nosuchfile.txt")
    deletion_task.run
    assert deletion_task.security_error?, "#{deletion_task.inspect} attempts to delete a file"
  end
end
