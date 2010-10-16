require "timeout"

# FIXME intended structure: 
# # A class that generates a variety of receivers, methods, parameters and blocks
# # A class representing a single action
# # Module for logging
# # A monkey-patched method that'd enable an object id and implementation-independent representation of an object

# FIXME make this configurable
srand(42)

# FIXME make a better way of creating random objects
objects = []
file = File.open("random_text.txt")
100.times do
  objects << file.read(rand(20))
end
100.times do
  objects << rand(10)
end
objects << " "

# FIXME make a better way to log things
if defined?(RUBY_ENGINE)
  output_filename = "#{RUBY_ENGINE}_#{RUBY_VERSION}_output.txt"
else
  output_filename = "#{RUBY_VERSION}_output.txt"
end
output_file = File.open(output_filename, "w")

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

# FIXME replace this whitelist of non-risky (I hope!) methods with something more flexible.
# I can get the list of methods using reflection, but how do I ensure that any operations won't delete the root directory?
methods = ["insert", "include?", "gsub", "size", "replace", "to_i", "chomp!", "succ", "oct", "to_s", "rstrip", "taguri=", "lines", "capitalize!", "hash", "capitalize", "center", "*", "index", "crypt", "+", "=~", "strip", "each_byte", "gsub!", "count", "delete!", "upcase", "ljust", "delete", "is_binary_data?", "upcase!", "rstrip!", "sum", "eql?", "start_with?", "to_sym", "length", "chop", "to_yaml", "to_f", "tr!", "to_str", "[]", "unpack", "tr", "inspect", "bytes", "strip!", "[]=", "slice!", "split", "sub", "each", "empty?", "swapcase!", "<<", "casecmp", "swapcase", "rindex", "intern", "rpartition", "reverse!", "next!", "lstrip", "hex", "chop!", "match", "each_char", "downcase!", "rjust", "downcase", "squeeze", "squeeze!", "concat", "upto", "end_with?", "slice", "chomp", "<=>", "bytesize", "sub!", "succ!", "each_line", "dump", "==", "scan", "tr_s", "tr_s!", "partition", "is_complex_yaml?", "next", "%", "reverse", "lstrip!", "chars", "taguri"]
100.times do
  receiver_object_index = rand(objects.size)
  num_parameters = rand(5)
  parameters_indexes = []
  num_parameters.times do
    index = rand(objects.size)
    next if index == receiver_object_index
    next if parameters_indexes.include?(index)
    parameters_indexes << index
  end
  method = methods[rand(methods.size)]

  receiver_object = objects[receiver_object_index]
  parameter_objects = objects.values_at(*parameters_indexes)
  # FIXME add a random block

  # FIXME rather than using Object#inspect, I have to create a method whose output doesn't vary depending on object id
  # or ruby implementation

  output_file.puts "Start"
  output_file.puts "Receiver object: " + receiver_object.inspect
  output_file.puts "Method: " + method.inspect
  output_file.puts "Parameters: " + parameter_objects.inspect
begin
  Timeout.timeout(2) do
    output_file.puts "Result: " + receiver_object.send(method, *parameter_objects, &:consistent_inspect).consistent_inspect
  end
rescue Exception => e
  output_file.puts "Failure for #{[receiver_object, method, parameter_objects].inspect}"
end
  output_file.puts "End"
  output_file.puts
end
output_file.close