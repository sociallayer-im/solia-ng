class Api::ServiceController < ApiController

  def send_email
    code = rand(10_000..100_000)
    token = ProfileToken.create(context: params[:context], sent_to: params[:email], code: code)
    # if ENV["DO_NOT_SEND_EMAIL"].blank?
    #   mailer = SigninMailer.with(code: code, recipient: params[:email]).signin_email
    #   mailer.deliver_now!
    # end

    render json: { result: "ok", email: params[:email] }
  end

  def stats
      group = Group.find(params[:group_id])
      group_id = group.id
      days = params[:days].to_i

      total_events = Event.where(group_id: group_id, status: "open").where("start_time >= ?", DateTime.now - days.day).count
      total_event_hosts = Event.where(group_id: group_id, status: "open").where("start_time >= ?", DateTime.now - days.day).pluck(:owner_id).uniq.count
      total_participants = Participant.where(event: Event.where(group_id: group_id, status: "open").where("start_time >= ?", DateTime.now - days.day)).count
      total_issued_badges = Participant.where(event: Event.where(group_id: group_id, status: "open").where("start_time >= ?", DateTime.now - days.day)).pluck(:badge_id).select { |x| x }.count

      render json: {
        total_events: total_events,
        total_event_hosts: total_event_hosts,
        total_participants: total_participants,
        total_issued_badges: total_issued_badges
      }
    end
end
