$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require "small_eigen_collider"
require "test/unit"

class TestSecurity < Test::Unit::TestCase

  # Detection of security breaches would fail under JRuby, for any level of $SAFE
  # and under Rubinius, for any level of $SAFE
  # and it probably fails under other platforms as well
  def test_lack_of_deletion_security
    deletion_task = SmallEigenCollider::Task.new(File, :delete, "nosuchfile.txt")
    deletion_task.run
    assert_equal false, deletion_task.security_error?, "#{deletion_task.inspect} is checking for insecure operations"
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
    # FIXME gsubs are to avoid irrelevant details from producing false claims of difference.
    # The optional 1 before the x is to handle JRuby - see JRuby bug 4977
    assert_equal first_mock_filestream.string.gsub(/01?x[0-9abcdef]+/, "0xc0ffee"), second_mock_filestream.string.gsub(/01?x[0-9abcdef]+/, "0xc0ffee"), "Side effect problems"
  end

  def test_roundtripping_works
    assert_roundtrips("a", "<<", "b", "test/data/simple_roundtrip.yml")
  end

  # tag_uri doesn't roundtrip. This test just demonstrates that I can't do this using test/unit yet. See test/failing_test.rb for the real story.
  def test_taguri_roundtrips
    assert_roundtrips(" affectin", "taguri=", ["metho"], "test/data/taguri_roundtrip.yml")
  end

  def test_class_roundtrips
    assert_roundtrips(File, "read", ["README.rdoc", 10], "test/data/file_roundtrip.yml")
  end

  def test_anonymous_class_roundtrips
    assert_roundtrips(Class, "new", [], "test/data/anonymous_class_roundtrip.yml")
  end

  def test_class_duplication_doesnt_cause_crashing
    assert_roundtrips(File, "dup", [], "test/data/class_duplication_roundtrip.yml")
  end
end

class TestFilter < Test::Unit::TestCase
  def create_single_item_task_list(receiver_object, method_name, parameters)
    raise ArgumentError unless parameters.is_a? Array
    task = SmallEigenCollider::Task.new(receiver_object, method_name, parameters)
    task_list = SmallEigenCollider::TaskList.new([task])
    task_list
  end

  def task_list_output_empty?(task_list)
    log_output_filestream = StringIO.new
    task_list.run_and_log_each_task(log_output_filestream)
    log_output_filestream.string.empty?
  end

  def task_yaml_output_empty?(task_list)
    task_list_yaml = task_list.dump_tasks_to_yaml_string
    yaml_created_task_list = SmallEigenCollider::TaskList.new_using_yaml_string(task_list_yaml)
    yaml_created_task_list.empty?
  end

  def test_filter
    bogus_task_task_list = create_single_item_task_list(1, "+", ["a"])
    bogus_task_task_list.add_filter(:success_only)
    assert_equal true, task_list_output_empty?(bogus_task_task_list), "Can't filter tasks"
    assert_equal true, task_yaml_output_empty?(bogus_task_task_list), "Can't filter tasks"
  end

  def test_filter_only_when_unsuccessful
    legit_task_task_list = create_single_item_task_list(1, "+", [1])
    legit_task_task_list.add_filter(:success_only)
    assert_equal false, task_list_output_empty?(legit_task_task_list), "Filters legit tasks"
    assert_equal false, task_yaml_output_empty?(legit_task_task_list), "Filters legit tasks"
  end
end
