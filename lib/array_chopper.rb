# Not very heavily tested.

class ArrayChopper
  attr_reader :minimal_failure

  def initialize(original_array, array_test)
    @original_array = original_array
    @array_test = array_test
  end
 
  def run
    minimal_failure, maximal_success = find_minimal_and_maximal_given(@original_array, [])
    @minimal_failure = minimal_failure
  end

  def find_minimal_and_maximal_given(known_failure, known_success)
    return known_failure, known_success if known_failure.length - 1 == known_success.length
    raise "success for known failure" if @array_test.call(known_failure)
    raise "failure for known success #{known_success.inspect}" unless @array_test.call(known_success)
    # Very naive algorithm
    medium = find_medium_between(known_failure, known_success)
    if @array_test.call(medium)
      find_minimal_and_maximal_given(known_failure, medium)
    else
      find_minimal_and_maximal_given(medium, known_success)
    end
  end

  def find_medium_between(longer_array, shorter_array)
    length_difference = longer_array.length - shorter_array.length
    raise NotImplementedError, "Too lazy to handle nils" if longer_array.any?{|element| element.nil?}
    raise ArgumentError, "You can't find a medium with between longer array #{longer_array.inspect} and shorter array #{shorter_array.inspect}" unless length_difference > 1
    throwaway_variable, aligned_shorter_array = align_two_arrays(longer_array, shorter_array)
    raise unless aligned_shorter_array.length == longer_array.length
    difference_indexes = find_difference_indexes_for(longer_array, aligned_shorter_array)
    raise unless difference_indexes.length == length_difference
    indexes_to_add_to_shorter = choose_items_from_array(difference_indexes, length_difference / 2)
    result = add_indexes_to_shorter(longer_array, shorter_array, indexes_to_add_to_shorter)
    result
  end
  
  def align_two_arrays(longer_array, shorter_array)
    raise if (longer_array.empty? and not shorter_array.empty?)
    return longer_array, shorter_array if longer_array.empty?
    if longer_array.first == shorter_array.first
      temp_variable = align_two_arrays(longer_array[1..-1], shorter_array[1..-1])
      raise unless temp_variable[0].length == temp_variable[1].length
      return ([longer_array.first] + temp_variable[0]), ([shorter_array.first] + temp_variable[1])
    else
      temp_variable = align_two_arrays(longer_array[1..-1], shorter_array)
      raise unless temp_variable[0].length == temp_variable[1].length
      return ([longer_array.first] + temp_variable[0]), ([nil] + temp_variable[1])
    end
  end # Up to here

  def find_difference_indexes_for(longer_array, aligned_shorter_array)
    raise if aligned_shorter_array.find_all{|element| element.nil?}.empty?
    raise unless longer_array.length == aligned_shorter_array.length
    result = []
    longer_array.each_index do |i|
      result << i if aligned_shorter_array.fetch(i).nil?
    end
    result
  end

  def choose_items_from_array(array, number_items)
    raise "Trying to pick #{number_items} items from #{array.inspect}" if number_items > array.length
    return [] if number_items == 0
    random_index = rand(array.length)
    random_item = array.fetch(random_index)
    return [random_item] + choose_items_from_array(array[0...random_index] + array[(random_index + 1)..-1], number_items - 1)
  end    

  def add_indexes_to_shorter(longer_array, shorter_array, indexes_to_add_to_shorter)
    throwaway_result, aligned_shorter_array = align_two_arrays(longer_array, shorter_array)
    indexes_to_add_to_shorter.each do |index|
      aligned_shorter_array[index] = longer_array[index]
    end
    aligned_shorter_array.find_all {|element| not element.nil?}
  end
end
