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
  def assert_roundtrips(receiver_object, method_name, parameters, yaml_dump_filename)
    File.delete(yaml_dump_filename) if File.exist?(yaml_dump_filename)

    first_mock_filestream = StringIO.new
    task = SmallEigenCollider::Task.new(receiver_object, method_name, parameters)
    task_list = SmallEigenCollider::TaskList.new([task])
    task_list.run_and_log_each_task(first_mock_filestream)
    yaml_string = task_list.dump_tasks_to_yaml_string
    task_list.dump_tasks_to_yaml(yaml_dump_filename)

    second_mock_filestream = StringIO.new
    yaml_created_task_list = SmallEigenCollider::TaskList.new_using_yaml(yaml_dump_filename)
    yaml_created_task_list.run_and_log_each_task(second_mock_filestream)
    second_yaml_string = yaml_created_task_list.dump_tasks_to_yaml_string
    assert_equal yaml_string, second_yaml_string, "Side effect problems"
    assert_equal first_mock_filestream.string, second_mock_filestream.string, "Side effect problems"
  end

  def test_roundtripping_works
    assert_roundtrips("a", "<<", "b", "test/data/simple_roundtrip.yml")
  end
end
