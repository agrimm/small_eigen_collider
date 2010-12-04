require "timeout"
require "yaml"
require "forwardable"

$:.unshift File.join(File.dirname(__FILE__), "small_eigen_collider")

require "serialization"

# FIXME intended structure: 
# # A class that generates a variety of receivers, methods, parameters and blocks
# # A class representing a single action
# # Module for logging
# # A monkey-patched method that'd enable an object id and implementation-independent representation of an object

class Object
  def consistent_inspect
    inspect
  end
end

class Enumerable::Enumerator
  def consistent_inspect
    "#<Enumerable::Enumerator>"
  end
end

module SmallEigenCollider
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
    @filestream.puts "Receiver object: " + consistent_inspect(task.receiver_object)
    @filestream.puts "Method: " + consistent_inspect(task.method)
    @filestream.puts "Parameters: " + consistent_inspect(task.parameter_objects)
  end

  def log_result(result)
    @filestream.puts "Result: " + consistent_inspect(result)
  end

  def log_failure(receiver_object, method, parameter_objects)
    @filestream.puts "Failure for #{consistent_inspect([receiver_object, method, parameter_objects].map{|x| consistent_inspect(x)})}"
  end

  def log_end
    @filestream.puts "End"
    @filestream.puts
    @filestream.flush
  end

  def close
    @filestream.close
  end

  def consistent_inspect(object)
    begin
      object.consistent_inspect
    rescue
      "Uninspectable object"
    end
  end
end

class SmallEigenCollider::TaskCreator
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

    receiver_object_methods = receiver_object.methods
    method = receiver_object_methods[rand(receiver_object_methods.size)]

    task = SmallEigenCollider::Task.new(receiver_object, method, parameter_objects)
    task
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
    @filters << type
  end

  def passes_filters?(task)
    @filters.all? do |filter|
      case filter
      when :success_only
        task.success?
      when :implementation_dependent
        next false if ["hash", "public_instance_methods", "singleton_methods", "private_methods"].include?(task.method.to_s)
        true
      else raise "Unknown filter type"
      end
    end
  end

  def filtered_tasks
    @tasks.find_all{|task| passes_filters?(task)}
  end

  def run_and_log_each_task(logger_filename_or_filestream)
    logger = SmallEigenCollider::Logger.new_using_filename_or_filestream(logger_filename_or_filestream)
    task_number = 1
    # Imperitive code written because otherwise no previous tasks would be printed if it gets printed
    @tasks.each do |task|
      # Fixme if this triggers a fatal error, you can't see what triggered it
      task.run

      next unless passes_filters?(task)
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
    when Fixnum, Symbol, NilClass, TrueClass, FalseClass, Class then return object
    when Array then return object.map{|element| safe_dup(element)}
    else return object.dup
    end
  end

  def run
    begin
      Timeout.timeout(2) do
        # taguri= is inconsistent between the initial run and from yaml. Not sure why, seems to be a fairly difficult task.
        # unpack crashes older versions of ruby 1.9.2
        # raise rather than run problem methods
        problem_methods = ["taguri=", "unpack"]
        raise if problem_methods.include?(method.to_s)

        # Hack to avoid creating anonymous classes, which is tested for later on anyway.
        # This line is only required for some versions of ruby 1.9 (eg 1.9.2-p0) where it
        # prevents ruby from crashing
        raise if @receiver_object == Class and method.to_s == "new"

        # secure_thread = Thread.new do
          # $SAFE doesn't help in all implementations of ruby
          # $SAFE = 2
          # FIXME add a random block
          @result = @receiver_object.send(@method, *@parameter_objects, &:consistent_inspect)
          @status = :success
        # end
        # secure_thread.join
      end
    rescue SecurityError
      @status = :security_error
    rescue Timeout::Error
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

  def method
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
