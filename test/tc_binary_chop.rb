$:.unshift File.join(File.dirname(__FILE__), "..", "lib", "small_eigen_collider")
require "test/unit"
require "array_chopper"

class TestBinaryChop < Test::Unit::TestCase
  def do_binary_chop(original_array, array_test)
    current_minimal_failure = Array(original_array)
    100.times do
      array_chopper = ArrayChopper.new(current_minimal_failure, array_test)
      array_chopper.run
      current_minimal_failure = array_chopper.minimal_failure
    end
    current_minimal_failure
  end

  def test_binary_chop
    original_array = [:bad, :bad, :good, :good, :good, :good, :bad]
    expected_array = [:bad, :bad, :bad]
    array_test = Proc.new {|array| array.find_all{|element| element == :bad}.length < 3}
    actual_array = do_binary_chop(original_array, array_test)
    assert_equal expected_array, actual_array, "Can't do a binary chop"
  end
end
