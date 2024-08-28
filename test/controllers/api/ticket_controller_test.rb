require "test_helper"

class Api::TicketControllerTest < ActionDispatch::IntegrationTest
  # group_ticket_enabled
  # group ticket
  # allow rsvp group ticket when group is closed
  test "api#event/create with tickets" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    group = Group.find_by(handle: "guildx")

    post api_event_create_url,
      params: { auth_token: auth_token, group_id: group.id, event: {
        title: "new meetup with tickets",
        start_time: DateTime.new(2024,8,8,10,20,30),
        end_time: DateTime.new(2024,8,8,12,20,30),
        location: "central park",
        display: "normal",
        event_type: "event",
        tickets_attributes: [
          {
            title: 'free', content: 'free ticket', quantity: 5,
            payment_methods_attributes: []
          },
          {
            title: 'crypto', content: 'crypto ticket', quantity: 5,
            payment_methods_attributes: [
              { chain: 'op', token_name: 'USDT', token_address: '0x1234', price: 5000000 },
              { chain: 'arb', token_name: 'USDT', token_address: '0x3456', price: 4000000 }
            ]
          },
          {
            title: 'fiat', content: 'fiat ticket', quantity: 5,
            payment_methods_attributes: [
              { chain: 'stripe', token_name: 'USD', token_address: '', price: 500 }
            ]
          }
        ]
      }}

    assert_response :success
    event = Event.find_by(title: "new meetup with tickets")
    ticket = Ticket.find_by(event: event, title: 'fiat')
    assert ticket
    assert PaymentMethod.find_by(item: ticket, chain: 'stripe', token_name: 'USD')
  end

  test "api#ticket/rsvp with free ticket" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    group = Group.find_by(handle: "guildx")

    event = events(:with_ticket)
    ticket = Ticket.find_by(event: event, title: 'free')

    post api_ticket_rsvp_url,
         params: { auth_token: auth_token, id: event.id, ticket_id: ticket.id, payment_method_id: nil }
    assert_response :success
  end

  test "api#ticket/rsvp with crypto ticket" do
    profile = Profile.find_by(handle: "cookie")
    auth_token = profile.gen_auth_token
    group = Group.find_by(handle: "guildx")

    event = events(:with_ticket)
    ticket = Ticket.find_by(event: event, title: 'crypto')
    op_paymethod = PaymentMethod.find_by(item: ticket, chain: 'op')

    post api_ticket_rsvp_url,
         params: { auth_token: auth_token, id: event.id, ticket_id: ticket.id, payment_method_id: op_paymethod.id }
    assert_response :success

    ticket_item = TicketItem.find_by(event: event)
    assert ticket_item.status == "pending"

    ENV['NEXT_TOKEN'] = "VBNM"

    post api_ticket_set_ticket_payment_status_url,
         params: { next_token: ENV['NEXT_TOKEN'], chain: ticket_item.chain, product_id: event.id, item_id: ticket_item.order_number, amount: ticket_item.amount, txhash: "0x7890"}
    assert_response :success

    ticket_item.reload
    assert ticket_item.txhash == "0x7890"
    assert ticket_item.status == "succeeded"

    # hash_diff = HashDiff::Comparison.new( ticket_item.as_json, ticket_item.reload.as_json )
    # p hash_diff.diff
  end
end

