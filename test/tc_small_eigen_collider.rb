$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require "small_eigen_collider"
require "test/unit"

module TestSmallEigenColliderHelper
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
end

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

  def test_task_list_timeout_works
    task = SmallEigenCollider::Task.new(nil, "raise", [TaskListTimeout])
    failure_message = "Swallows up the task list timeout exception when it should float up"
    assert_raise(TaskListTimeout, failure_message) do
      task.run
    end
  end
end

class TestRoundtripping < Test::Unit::TestCase
  include TestSmallEigenColliderHelper

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

  def test_module_duplication_doesnt_cause_crashing
    assert_roundtrips(Kernel, "Float", [5], "test/data/module_roundtrip.yml")
  end

  def test_float_duplication_doesnt_cause_crashing
    assert_roundtrips(0.1, "+", [0.1], "test/data/float_roundtrip.yml")
  end

  def test_uninspectable_objects_dont_cause_crashing
    buster = Object.new
    def buster.inspect() raise "This inspect is busted!" end
    task_list = create_single_item_task_list(buster, "class", [])
    assert_nothing_raised do
      task_list.run_and_log_each_task(StringIO.new)
    end
  end

  def test_object_uninspectable_by_jruby_dont_cause_crashing
    task_list = create_single_item_task_list(Dir, "allocate", [])
    assert_nothing_raised("Can't handle java exceptions while inspecting") do
      task_list.run_and_log_each_task(StringIO.new)
    end
  end
end

class TestFilter < Test::Unit::TestCase
  include TestSmallEigenColliderHelper

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

  def test_filter_implementation_dependent
    implementation_dependent_task_task_list = create_single_item_task_list(42, "hash", [])
    implementation_dependent_task_task_list.add_filter(:implementation_dependent)
    assert_equal true, task_list_output_empty?(implementation_dependent_task_task_list), "Fails to filter implementation dependent tasks"
  end

  def test_filter_class_method_defined_as_class_hash_foo
    task_list = create_single_item_task_list(Time, "allocate", [])
    task_list.add_filter(:implementation_dependent)
    assert_equal true, task_list_output_empty?(task_list), "Fails to filter implementation dependent class methods"
  end

  def test_filter_class_method_defined_as_foo_dot_bar
    task_list = create_single_item_task_list(GC, "count", [])
    task_list.add_filter(:implementation_dependent)
    assert_equal true, task_list_output_empty?(task_list), "Fails to filter implementation dependent class methods defined as Foo.bar()"
  end

  def test_detect_implementation_dependent_class
    require "thread"
    task_list = create_single_item_task_list(Queue, "new", [])
    task_list.add_filter(:implementation_dependent)
    assert_equal true, task_list_output_empty?(task_list), "Fails to filter implementation dependent classes"
  end

  # Testing existing functionality
  def test_filter_gc_stress
    task_list = create_single_item_task_list(GC, "stress=", [true])
    task_list.add_filter(:success_only)
    task_list.add_filter(:crash_inducing)
    assert_equal true, task_list_output_empty?(task_list), "Fails to filter crash inducing methods"
    assert_equal false, GC.stress, "Fails to filter crash inducing methods before they happen"
  end
end

class TestObjectGeneration < Test::Unit::TestCase
  module NAMESPACED_CONSTANT
  end
  NAMESPACED_CONSTANT::SUB = 2
  include SmallEigenCollider::ConstantFinder

  def test_constant_finding_works
    namespaces = [self.class]
    modules_found = get_all_constants_within_namespaces(namespaces, 5)
    assert modules_found.include?(NAMESPACED_CONSTANT::SUB), "Can't find constants within a namespace"
  end
end
