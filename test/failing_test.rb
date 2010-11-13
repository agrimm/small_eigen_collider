$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require "small_eigen_collider"
# This isn't using test/unit, as this messes up the taguri task testing

failure_messages = []
mock_log_filestream = StringIO.new

yaml_filename = "test/data/taguri_task.yml"

task_list = SmallEigenCollider::TaskList.new_using_yaml(yaml_filename)
task_list.run_and_log_each_task(mock_log_filestream)
failure_messages << "taguri= doesn't work" if mock_log_filestream.string.include?"Failure"

unless failure_messages.empty?
  puts failure_messages.join("\n\n")
  exit 1
end

# You are winner! Exit without error.
