require "timeout"
require "yaml"
require "forwardable"

$:.unshift File.join(File.dirname(__FILE__), "small_eigen_collider")

require "serialization"

class Object
  def consistent_inspect
    # The gsub is to deal with the object id portion of #<Object:0x12345678> being different each time
    # The optional 1 before the x is to handle JRuby - see JRuby bug 4977
    inspect.gsub(/01?x[0-9abcdef]+/, "0xc0ffee")
  end
end

class Enumerable::Enumerator
  def consistent_inspect
    "#<Enumerable::Enumerator>"
  end
end

class Float
  def consistent_inspect
    super[0..5]
  end
end

class Struct::Tms
  def consistent_inspect
    (["hammertime!"] * 4).inspect
  end
end

module SmallEigenCollider
end

module SmallEigenCollider::BoringInspect
  # Different from Object#consistent_inspect to avoid confusion
  def consistent_inspect
    "#<#{self.class}:0xdecafbad>"
  end
end

class IO
  include SmallEigenCollider::BoringInspect
end

class Proc
  include SmallEigenCollider::BoringInspect
end

class StringIO
  include SmallEigenCollider::BoringInspect
end

class SmallEigenCollider::Logger
  def self.new_using_filename_or_filestream(filename_or_filestream)
    if filename_or_filestream.respond_to?("gets")
      filestream = filename_or_filestream
    else
      filestream = File.open(filename_or_filestream, "w")
    end
    new(filestream)
  end

  def initialize(filestream)
    @filestream = filestream
  end

  def log_start(task_number)
    @filestream.puts "Start of task #{task_number}"
  end

  def log_input_parameters(task)
    @filestream.puts "Receiver object: " + consistently_inspect(task.receiver_object)
    @filestream.puts "Method: " + consistently_inspect(task.task_method)
    @filestream.puts "Parameters: " + consistently_inspect(task.parameter_objects)
  end

  def log_result(result)
    @filestream.puts "Result: " + consistently_inspect(result)
  end

  def log_failure(receiver_object, method, parameter_objects)
    @filestream.puts "Failure for #{[receiver_object, method, parameter_objects].map{|x| consistently_inspect(x)}.join(", ")}"
  end

  def log_end
    @filestream.puts "End"
    @filestream.puts
    @filestream.flush
  end

  def close
    @filestream.close
  end

  def consistently_inspect(object)
    begin
      return object.sort.consistent_inspect if object.is_a?(Hash)
      return ["[", object.map(&:consistent_inspect).join(","), "]"].join if object.is_a?(Array)
      object.consistent_inspect
    rescue # Unless things have really gone badly, they should be rescued here
      "Uninspectable object"
    rescue Java::JavaLang::NullPointerException
      "Uninspectable object"
    end
  end
end

module SmallEigenCollider::ConstantFinder
  # Given a list of namespaces, get all constants within them
  def get_all_constants_within_namespaces(namespaces, maximum_depth)
    current_constants = namespaces
    result = []
    (maximum_depth - 1).times do
      new_constants = []
      current_namespaces = current_constants.find_all{|c| c.is_a?(Module)}
      current_namespaces.each do |current_namespace|
        constants_within_current_namespace = current_namespace.constants.map do |const_name|
          current_namespace.const_get(const_name)
        end
        new_constants += constants_within_current_namespace
      end
      new_constants.compact!
      new_constants -= result # To avoid duplicates
      result += new_constants
      current_constants = new_constants
    end
    result.uniq!
    result
  end

  # Get the top level modules (or classes) that don't cause the program to crash
  def get_top_level_modules
    non_small_eigen_collider_constant_names = Module.constants.reject{|con| con.to_s =~ /Small/}
    possible_constants = non_small_eigen_collider_constant_names.map{|con| Kernel.const_get(con)}

    # FIXME see if some constants that I'm currently rejecting can't be allowed in future versions
    # Actually, maybe not. Classes and Modules are useful, because they can be used to create objects,
    # but other constants are probably special objects that are hard to serialize
    non_problematic_constants = (possible_constants - [Binding, STDERR]).reject{|con| con.class != Class and con.class != Module}
    non_problematic_constants
  end
end

class SmallEigenCollider::TaskCreator
  include SmallEigenCollider::ConstantFinder

  def initialize
    # FIXME make this configurable
    srand(42)

    # FIXME make an even better way of creating random objects
    @objects = []
    file = File.open("README.rdoc")
    100.times do
      @objects << file.read(rand(20))
    end
    100.times do
      @objects << rand(10)
    end
    @objects << " "
    100.times do
      @objects << File
    end
    @objects += get_top_level_modules
  end

  def create_task
    receiver_object_index = rand(@objects.size)
    num_parameters = rand(5)
    parameters_indexes = []
    num_parameters.times do
      index = rand(@objects.size)
      next if index == receiver_object_index
      next if parameters_indexes.include?(index)
      parameters_indexes << index
    end

    receiver_object = @objects[receiver_object_index]
    parameter_objects = @objects.values_at(*parameters_indexes)

    # FIXME haven't examined what methods should be excluded.
    # FIXME maybe this should be turned into a filter like with TaskList#passes_filter?
    # This is done to prevent extremely weird stuff like running Fixnum.extend(MatchData)
    # which, combined with calling String#drop(another_string) (which is bad behaviour anyway)
    # could cause a segfault in Rubinius.
    # FIXME restricting the methods use seem to make the program less likely to produce a YML output
    receiver_object_methods = receiver_object.methods - (Kernel.methods - ["to_s", :to_s])
    raise if receiver_object_methods.empty?
    method = receiver_object_methods[rand(receiver_object_methods.size)]

    task = SmallEigenCollider::Task.new(receiver_object, method, parameter_objects)
    task
  end
end

class SmallEigenCollider::TaskFilter

  def self.new_filter(filter_type)
    case filter_type
      when :success_only then SuccessTaskFilter.new
      when :implementation_dependent then ImplementationDependentTaskFilter.new_using_filenames("config/implementation_dependent_tasks.txt", "config/implementation_dependent_classes.txt")
      when :crash_inducing then ImplementationDependentTaskFilter.new_using_filenames("config/crash_inducing_tasks.txt", "config/crash_inducing_classes.txt")
      else raise "Unknown filter type"
    end
  end
end


class SmallEigenCollider::TaskFilter::ImplementationDependentTaskFilter

  def self.new_using_filenames(methods_filename, classes_filename)
    new_using_texts(File.read(methods_filename), File.read(classes_filename))
  end

  def self.new_using_texts(methods_text, classes_text)
    class_methods = []
    instance_methods = []
    method_descriptions = methods_text.split("\n").reject{|line| line =~ /^# /}.map{|line| line.split(", ")}.flatten
    method_descriptions.each do |method_description|
      case
        # FIXME this logic isn't fully unit tested
        when method_description =~ /^(\w+)#([?\w<]+[=]?)$/
          instance_methods << {:class_name => $1, :method_name => $2}
        when method_description =~ /^(\w+)\.([?\w<]+[=]?)$/
          class_methods << {:class_name => $1, :method_name => $2}
        else raise "Couldn't parse #{method_description.inspect}!"
      end
    end
    classes = classes_text.split("\n").reject{|line| line =~ /^# /}.map{|line| line.split(", ")}.flatten

    new(class_methods, instance_methods, classes)
  end

  def initialize(class_methods, instance_methods, class_names)
    @class_methods, @instance_methods, @class_names = class_methods, instance_methods, class_names
  end

  def task_passes?(task)
    return false if @instance_methods.any? do |instance_method_combination|
      next unless task.receiver_object.class.ancestors.map(&:to_s).include?(instance_method_combination.fetch(:class_name))
      task.task_method.to_s == instance_method_combination.fetch(:method_name)
    end

    return false if @class_methods.any? do |class_method_combination|
      next unless task.receiver_object.is_a?(Module)
      next unless task.receiver_object.name == class_method_combination.fetch(:class_name)
      task.task_method.to_s == class_method_combination.fetch(:method_name)
    end

    objects = [task.receiver_object] + task.parameter_objects

    # Check if any of the receivers or parameters are class or module objects
    # that exist (at least without using libraries) in a specific implementation
    objects.each do |object|
      next unless object.is_a?(Module)
      return false if @class_names.include?(object.name)
      # Exceptions aren't allowed, as different implementations have their own exception classes
      return false if object.ancestors.include?(Exception)
    end
    true
  end

  def pre_running_filter?
    true
  end
end

class SmallEigenCollider::TaskFilter::SuccessTaskFilter

  def task_passes?(task)
    task.success?
  end

  def pre_running_filter?
    false
  end
end

class SmallEigenCollider::TaskList
  extend Forwardable
  # empty? is just used for testing. Don't know whether it should be based on :@tasks or filtered_tasks
  def_delegators :@tasks, :empty?

  def self.new_using_creator(iterations)
    task_creator = SmallEigenCollider::TaskCreator.new
    tasks = iterations.times.map {task_creator.create_task}
    new(tasks)
  end

  def self.new_using_yaml(yaml_filename)
    tasks = load_tasks(File.read(yaml_filename))
    new(tasks)
  end

  # Only used in testing
  def self.new_using_yaml_string(yaml_string)
    tasks = load_tasks(yaml_string)
    new(tasks)
  end

  def self.load_tasks(yaml_string)
    tasks = YAML.load(yaml_string)
    tasks.each {|task| task.reinitialize}
    tasks
  end

  def initialize(tasks)
    @tasks = tasks
    @filters = []
  end

  def add_filter(type)
    @filters << SmallEigenCollider::TaskFilter.new_filter(type)
  end

  def passes_filters?(task)
    @filters.all? do |filter|
      filter.task_passes?(task)
    end
  end

  def pre_running_filters() @filters.find_all(&:pre_running_filter?) end
  def post_running_filters() @filters.reject(&:pre_running_filter?) end

  def passes_pre_running_filters?(task)
    pre_running_filters.all? {|filter| filter.task_passes?(task)}
  end

  def passes_post_running_filters?(task)
    post_running_filters.all? {|filter| filter.task_passes?(task)}
  end

  def filtered_tasks
    @tasks.find_all{|task| passes_filters?(task)}
  end

  def run_and_log_each_task(logger_filename_or_filestream)
    logger = SmallEigenCollider::Logger.new_using_filename_or_filestream(logger_filename_or_filestream)
    task_number = 1
    # Imperitive code written because otherwise no previous tasks would be printed if it gets printed
    @tasks.each do |task|
      next unless passes_pre_running_filters?(task)
      # Fixme if this triggers a fatal error, you can't see what triggered it
      task.run

      next unless passes_post_running_filters?(task)
      logger.log_start(task_number)
      logger.log_input_parameters(task)
      task.log_result(logger)
      logger.log_end

      task_number += 1
    end
    logger.close
  end

  def dump_tasks_to_yaml(yaml_filename)
    File.open(yaml_filename, "w") {|output_yaml_file| output_yaml_file.print(dump_tasks_to_yaml_string)}
  end

  def dump_tasks_to_yaml_string
    YAML.dump(filtered_tasks)
  end
end

# This isn't run with a $SAFE level, because it made things slower,
# and isn't guaranteed to work with all implementations of Ruby anyway.
class SmallEigenCollider::Task
  def initialize(receiver_object, method, parameter_objects)
    @original_receiver_object, @original_method, @original_parameter_objects = receiver_object, method, parameter_objects
    reinitialize
  end

  # FIXME there should be a correct name for this
  def reinitialize
    @receiver_object, @method, @parameter_objects = [@original_receiver_object, @original_method, @original_parameter_objects].map {|object| safe_dup(object)}
    @status = :not_run_yet
  end

  def safe_dup(object)
    case object
    when Numeric, Symbol, NilClass, TrueClass, FalseClass, Class, Module, IO, Binding then return object
    when Array then return object.map{|element| safe_dup(element)}
    else
      begin
        object.dup
      rescue
        STDERR.puts "Problem duplicating #{object.inspect} of class #{object.class}"
        raise
      end
    end
  end

  def run
    begin
      Timeout.timeout(0.1, IndividualTaskTimeout) do
        # In JRuby, File.open(4) seems to make errors raise when flushing the log file
        # the crash inducing tasks filter isn't currently capable of letting all calls except when the first parameter is a Fixnum
        raise if @receiver_object == File and "open" == @method.to_s and Fixnum === @parameter_objects.first

        # FIXME add a random block
        @result = @receiver_object.send(@method, *@parameter_objects) do |*block_args|
          block_args.first.consistent_inspect
        end
        @status = :success
      end
    rescue TaskListTimeout
      raise
    rescue SecurityError
      @status = :security_error
    rescue IndividualTaskTimeout
      @status = :timeout
    rescue Exception
      @status = :failure
    end
  end

  def log_result(logger)
    case @status
    when :timeout, :failure, :security_error
      logger.log_failure(@receiver_object, @method, @parameter_objects)
    when :success
      logger.log_result(@result)
    else raise
    end
  end

  def security_error?
    @status == :security_error
  end

  def success?
    @status == :success
  end

  def receiver_object
    @original_receiver_object
  end

  def task_method
    @original_method
  end

  def parameter_objects
    @original_parameter_objects
  end

  def to_yaml_properties
    hard_to_marshal_properties = %{@result}
    super.reject {|yaml_property| hard_to_marshal_properties.include?(yaml_property.to_s)}
  end
end

class IndividualTaskTimeout < Timeout::Error
end

class TaskListTimeout < Timeout::Error
end
