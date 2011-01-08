# Not very heavily tested.

class ArrayChopper
  attr_reader :minimal_failure

  def initialize(original_array, array_test)
    @original_array = original_array
    @array_test = array_test
  end

  def run
    @minimal_failure = find_minimal_failure_for(@original_array)
  end

  def find_minimal_failure_for(array)
    raise "Known bad passed" if @array_test.call(array)
    failure_deletion_parameters = success_deletion_parameters = nil
    until only_one_item_difference_between?(failure_deletion_parameters, success_deletion_parameters, array)
      new_deletion_parameters = create_deletion_parameters_given_existing_parameters(failure_deletion_parameters, success_deletion_parameters, array)
      new_array = create_array_given_deletion_parameters(array, new_deletion_parameters)
      if @array_test.call(new_array)
        success_deletion_parameters = new_deletion_parameters
      else
        failure_deletion_parameters = new_deletion_parameters
      end
    end
    return array if failure_deletion_parameters.nil? # No smaller array also had a failure in this run
    minimal_failure = create_array_given_deletion_parameters(array, failure_deletion_parameters)
    minimal_failure
  end

  def only_one_item_difference_between?(failure_deletion_parameters, success_deletion_parameters, array)
    # If we haven't found a case where there's a success, we haven't finished yet
    return false if success_deletion_parameters.nil?

    # If deleting a single item can cause a success, then we've finished
    success_deletion_length = success_deletion_parameters.fetch(:finish) - success_deletion_parameters.fetch(:start) + 1
    return true if success_deletion_length == 1

    # Otherwise, we need a case where deleting n items causes a failure, but deleting n + 1 items causes a success
    return false if failure_deletion_parameters.nil?
    failure_deletion_length = failure_deletion_parameters.fetch(:finish) - failure_deletion_parameters.fetch(:start) + 1

    return failure_deletion_length == success_deletion_length - 1
  end

  # Find something that's between failure_deletion_parameters and success_deletion_parameters
  def create_deletion_parameters_given_existing_parameters(failure_deletion_parameters, success_deletion_parameters, array)
    result = case
    when (failure_deletion_parameters.nil? and success_deletion_parameters.nil?)
      start = rand(array.length)
      finish = rand(array.length - start) + start
      {:start => start, :finish => finish}
    when failure_deletion_parameters.nil?
      start = success_deletion_parameters.fetch(:start)
      finish = start
      {:start => start, :finish => finish}
    when success_deletion_parameters.nil?
      if failure_deletion_parameters.fetch(:start) > 0
        start = rand(failure_deletion_parameters.fetch(:start))
        finish = failure_deletion_parameters.fetch(:finish)
        return {:start => start, :finish => finish}
      elsif failure_deletion_parameters.fetch(:finish) < array.length - 1
        old_finish = failure_deletion_parameters.fetch(:finish)
        start = failure_deletion_parameters.fetch(:start)
        finish = rand(array.length - old_finish) + old_finish
        return {:start => start, :finish => finish}
      else raise
      end
    else
      earlier_start = success_deletion_parameters.fetch(:start)
      later_start = failure_deletion_parameters.fetch(:start)
      earlier_finish = failure_deletion_parameters.fetch(:finish)
      later_finish = success_deletion_parameters.fetch(:finish)
      start, finish = [[earlier_start, later_start], [earlier_finish, later_finish]].map do |earlier, later|
        raise if earlier > later
        new_value = earlier + rand(later - earlier + 1)
        raise if new_value > later
        new_value
      end
      return {:start => start, :finish => finish}
    end
  end

  def create_array_given_deletion_parameters(array, deletion_parameters)
    first_part = array[0...(deletion_parameters.fetch(:start))]
    second_part = array[(deletion_parameters.fetch(:finish) + 1)..-1] || []
    first_part + second_part
  end
end
