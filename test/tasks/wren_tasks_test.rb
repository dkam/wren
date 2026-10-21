require "test_helper"
require "rake"

class WrenTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @env = ENV.to_h
  end

  teardown { ENV.replace(@env) }

  def run_task(name, **env)
    env.each { |k, v| ENV[k.to_s] = v }
    Rake::Task["wren:#{name}"].reenable
    out, err = capture_io do
      Rake::Task["wren:#{name}"].invoke
    rescue SystemExit
      # abort has already written its message to stderr
    end
    [ out.strip, err.strip ]
  end

  test "new, claim, claim again, list, release" do
    token, = run_task(:new, TITLE: "local")
    list = List.find_by!(token:)
    assert_equal List::DEFAULT_NAMES.size, list.names.count

    name, = run_task(:claim, SESSION: "s1", NOTE: "pi")
    assert_includes List::DEFAULT_NAMES, name.downcase
    assert_equal [ name, "" ], run_task(:claim, SESSION: "s1")

    out, = run_task(:list)
    assert_match(/#{name} .* live .* pi/, out)

    assert_equal [ "released #{name}", "" ], run_task(:release, NAME: name)
    assert_equal [ "", "wren: #{name} is not claimed" ], run_task(:release, NAME: name)
  end

  test "reserve, and a taken name refused" do
    List.create!
    assert_equal [ "Wren", "" ], run_task(:reserve, NAME: "wren")
    assert_equal [ "", "wren: wren is taken" ], run_task(:reserve, NAME: "wren")
  end

  test "with more than one list, LIST says which" do
    a = List.create!(title: "a")
    b = List.create!(title: "b")
    b.add_names("bram")
    _, err = run_task(:claim, SESSION: "s1")
    assert_match(/which list\?.*#{a.token}.*#{b.token}/m, err)
    assert_equal [ "Bram", "" ], run_task(:claim, SESSION: "s1", LIST: b.token)
  end

  test "claim needs a session" do
    List.create!
    ENV.delete("SESSION")
    assert_equal [ "", "wren: SESSION is required" ], run_task(:claim)
  end
end
