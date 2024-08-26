require "test_helper"

class Api::EventControllerTest < ActionDispatch::IntegrationTest
  # with venue
  # with venue#require_approval
  # with badge_class
  # email notify
  # invite guest
  # event roles
  # event roles of email
  # ticket
  # promo code
  # group member only
  # group manager only
  # private event
  # private track
  test "api#event/create for group" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    group = Group.find_by(handle: "guild")

    post api_event_create_url,
      params: { auth_token: auth_token, group_id: group.id, event: {
        title: "new meetup",
        tags: %w[live art],
        start_time: DateTime.new(2024,8,8,10,20,30),
        end_time: DateTime.new(2024,8,8,12,20,30),
        location: "central park",
        content: "wonderful",
        display: "normal",
        event_type: "event"
      }}
    assert_response :success
    assert Event.find_by(title: "new meetup")
    assert Event.find_by(title: "new meetup").status == "published"
    assert Event.find_by(title: "new meetup").display == "normal"
    assert Event.find_by(title: "new meetup").owner == profile
    assert (Group.find_by(handle: "guild").events_count - group.events_count) == 1
  end

  test "api#event/unpublish" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    group = Group.find_by(handle: "guild")
    event = Event.find_by(title: "my meetup")

    post api_event_unpublish_url,
      params: { auth_token: auth_token, id: event.id}
    assert_response :success
    assert Event.find_by(title: "my meetup").status == "cancelled"
  end

  test "api#event/join" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    attendee = Profile.find_by(handle: "mooncake")
    attendee_auth_token = profile.gen_auth_token

    group = Group.find_by(handle: "guild")
    event = Event.find_by(title: "my meetup")

    post api_event_join_url,
      params: { auth_token: attendee_auth_token, id: event.id}
    assert_response :success
    assert Participant.find_by(event: event).status == "attending"

    post api_event_check_url,
      params: { auth_token: auth_token, id: event.id, profile_id: profile.id}
    assert_response :success
    assert Participant.find_by(event: event).status == "checked"
  end

  test "api#event/cancel" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    attendee = Profile.find_by(handle: "mooncake")
    attendee_auth_token = profile.gen_auth_token

    group = Group.find_by(handle: "guild")
    event = Event.find_by(title: "my meetup")

    post api_event_join_url,
      params: { auth_token: attendee_auth_token, id: event.id}
    assert_response :success
    assert Participant.find_by(event: event).status == "attending"

    post api_event_cancel_url,
      params: { auth_token: auth_token, id: event.id, profile_id: profile.id}
    assert_response :success
    assert Participant.find_by(event: event).status == "cancelled"

  end
end
