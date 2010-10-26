require "timeout"

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
  def self.new_using_filename(filename)
    filestream = File.open(filename, "w")
    new(filestream)
  end

  def initialize(filestream)
    @filestream = filestream
  end

  def log_start
    @filestream.puts "Start"
  end

  def log_input_parameters(task)
    @filestream.puts "Receiver object: " + task.receiver_object.inspect
    @filestream.puts "Method: " + task.method.inspect
    @filestream.puts "Parameters: " + task.parameter_objects.inspect
  end

  def log_result(result)
    @filestream.puts "Result: " + result.consistent_inspect
  end

  def log_failure(receiver_object, method, parameter_objects)
    @filestream.puts "Failure for #{[receiver_object, method, parameter_objects].inspect}"
  end

  def log_end
    @filestream.puts "End"
    @filestream.puts
  end

  def close
    @filestream.close
  end
end

class SmallEigenCollider::TaskCreator
  def initialize
    # FIXME make this configurable
    srand(42)

    # FIXME make a better way of creating random objects
    @objects = []
    file = File.open("random_text.txt")
    100.times do
      @objects << file.read(rand(20))
    end
    100.times do
      @objects << rand(10)
    end
    @objects << " "

    # FIXME replace this whitelist of non-risky (I hope!) methods with something more flexible.
    # I can get the list of methods using reflection, but how do I ensure that any operations won't delete the root directory?
    @methods = (["insert", "include?", "gsub", "size", "replace", "to_i", "chomp!", "succ", "oct", "to_s", "rstrip", "taguri=", "lines", "capitalize!", "hash", "capitalize", "center", "*", "index", "crypt", "+", "=~", "strip", "each_byte", "gsub!", "count", "delete!", "upcase", "ljust", "delete", "is_binary_data?", "upcase!", "rstrip!", "sum", "eql?", "start_with?", "to_sym", "length", "chop", "to_yaml", "to_f", "tr!", "to_str", "[]", "unpack", "tr", "inspect", "bytes", "strip!", "[]=", "slice!", "split", "sub", "each", "empty?", "swapcase!", "<<", "casecmp", "swapcase", "rindex", "intern", "rpartition", "reverse!", "next!", "lstrip", "hex", "chop!", "match", "each_char", "downcase!", "rjust", "downcase", "squeeze", "squeeze!", "concat", "upto", "end_with?", "slice", "chomp", "<=>", "bytesize", "sub!", "succ!", "each_line", "dump", "==", "scan", "tr_s", "tr_s!", "partition", "is_complex_yaml?", "next", "%", "reverse", "lstrip!", "chars", "taguri"] + ["%", "odd?", "prec_i", "<<", "div", "&", ">>", "lcm", "power!", "to_sym", "*", "ord", "+", "next", "round", "prec_f", "-", "even?", "denominator", "singleton_method_added", "divmod", "/", "integer?", "downto", "gcdlcm", "|", "gcd", "size", "truncate", "~", "to_i", "modulo", "zero?", "times", "to_r", "rdiv", "^", "+@", "-@", "quo", "**", "upto", "to_f", "<", "step", "numerator", "<=>", "between?", "remainder", ">", "to_int", "nonzero?", "pred", "coerce", "rpower", "floor", "succ", ">=", "prec", "<=", "fdiv", "abs", "chr", "id2name", "ceil", "[]"]).uniq
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
    method = @methods[rand(@methods.size)]

    receiver_object = @objects[receiver_object_index]
    parameter_objects = @objects.values_at(*parameters_indexes)

    task = SmallEigenCollider::Task.new(receiver_object, method, parameter_objects)
    task
  end
end

class SmallEigenCollider::Task
  attr_reader :receiver_object, :method, :parameter_objects

  def initialize(receiver_object, method, parameter_objects)
    @receiver_object, @method, @parameter_objects = receiver_object, method, parameter_objects
    @status = :not_run_yet
  end

  def run
    begin
      Timeout.timeout(2) do
        secure_thread = Thread.new do
          $SAFE = 2
          # FIXME add a random block
          @result = @receiver_object.send(@method, *@parameter_objects, &:consistent_inspect)
          @status = :success
        end
        secure_thread.join
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
end
