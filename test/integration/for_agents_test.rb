require "test_helper"

class ForAgentsTest < ActionDispatch::IntegrationTest
  test "the key and each command for agents are blocks of their own, each with a button that copies it" do
    list = List.create!
    get "/#{list.token}"

    assert_select "#for-agents [data-controller=copy]", 6 do |blocks|
      blocks.each { assert_select it, "button[type=button][data-action='copy#copy']", 1 }
    end
    assert_select "#for-agents [data-copy-target=source]", text: list.token
    assert_select "#for-agents pre code[data-copy-target=source]",
      text: %(curl -s -H "Authorization: Bearer #{list.token}" -d name=milan http://www.example.com/reserve)
  end

  test "Claude Code's settings are given a hook that claims a name for each session as it starts" do
    list = List.create!
    get "/#{list.token}"

    settings = css_select("#for-agents pre code[data-copy-target=source]").map(&:text).find { it.include?("SessionStart") }
    assert settings, "no hook to copy"
    command = JSON.parse(settings).dig("hooks", "SessionStart", 0, "hooks", 0, "command")
    assert_includes command, %(-H "Authorization: Bearer #{list.token}")
    assert_includes command, %(-d session="$(jq -r .session_id)")
    assert_includes command, "http://www.example.com/claim"
  end
end
