require "test_helper"

class Api::GroupControllerTest < ActionDispatch::IntegrationTest
  test "api#group/create" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token

    post api_group_create_url,
      params: { auth_token: auth_token, handle: "newworld", group: {
        timezone: "asia/shanghai",
        can_publish_event: "all",
        can_join_event: "all",
        can_view_event: "all",
      } }
    assert_response :success
    group = Group.find_by(handle: "newworld")
    assert group
    assert group.active?
    assert group.is_owner(profile.id)
    assert group.memberships_count == 1
  end

  test "api#group/update" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    group = Group.find_by(handle: "guild")

    post api_group_update_url,
      params: { auth_token: auth_token, id: group.id, group: {
        timezone: "asia/hongkong",
      } }
    assert_response :success
    group = Group.find_by(handle: "newworld")
    assert group.timezone == "asia/hongkong"
  end
end
