require "test_helper"

class ForAgentsTest < ActionDispatch::IntegrationTest
  test "the key and each command for agents are blocks of their own, each with a button that copies it" do
    list = List.create!
    get "/#{list.token}"

    assert_select "#for-agents [data-controller=copy]", 5 do |blocks|
      blocks.each { assert_select it, "button[type=button][data-action='copy#copy']", 1 }
    end
    assert_select "#for-agents [data-copy-target=source]", text: list.token
    assert_select "#for-agents pre code[data-copy-target=source]",
      text: %(curl -s -H "Authorization: Bearer #{list.token}" -d name=milan http://www.example.com/reserve)
  end
end
