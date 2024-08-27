class Api::EventController < ApiController
  def create
    profile = current_profile!
    group = Group.find(params[:group_id])

    status = "published"
    @send_approval_email_to_manager = false
    if params[:venue_id]
      venue = Venue.find_by(id: params[:venue_id], group_id: group.id)
      raise AppError.new("group venue not exists") unless venue

      if venue.require_approval && !group.is_manager(profile.id)
        status = "pending"
        @send_approval_email_to_manager = true
      end
    end

    if params[:badge_class_id]
      badge_class = BadgeClass.find(params[:badge_class_id])
      authorize badge_class, :send?
    end

    event = Event.new(event_params)
    event.update(
      owner: profile,
      group: group,
    )

    group.increment!(:events_count)

    if @send_approval_email_to_manager && ENV["DO_NOT_SEND_EMAIL"].blank?
      Membership.includes(:profile).where(target_id: group.id, role: [ "owner", "manager" ]).each do |membership|
        if membership.cap.present? && membership.cap.include?("venue") && membership.profile.email.present?
          mailer = GroupMailer.with(group_name: (group.nickname || group.username), event_id: event.id, recipient: membership.profile.email).venue_review_email
          mailer.deliver_now!
        end
      end
    end

    render json: { result: "ok", event: event.as_json }
  end

  def send_badge
    profile = current_profile!
    event = Event.find(params[:id])
    badge_class = event.badge_class
    raise AppError.new("event badge_class not set") unless badge_class

    authorize event, :update?

    vouchers = event.participants.where(status: "checked", voucher_id: nil).map do |participant|
      receiver = participant.profile
      voucher = Voucher.new(
        sender: profile,
        badge_class: badge_class,
        # need test
        message: params[:message],
        strategy: "event",
        counter: 1,
        receiver_address_type: "id",
        receiver_id: receiver.id,
        # need test
        expires_at: (params[:expires_at] || DateTime.now + 90.days),
      )
      voucher.save
      participant.update(voucher_id: voucher.id)
      activity = Activity.create(item: badge_class, initiator_id: profile.id, action: "voucher/send_event_badge")

      voucher
    end

    render json: { vouchers: vouchers.as_json }
  end

  def update
    profile = current_profile!

    event = Event.find(params[:id])
    authorize event, :update?

    if params[:event][:venue_id] && params[:event][:venue_id] != event.venue_id
      venue = Venue.find_by(id: params[:venue_id], group_id: group.id)
      raise AppError.new("group venue not exists") unless venue

      if venue.require_approval && !group.is_manager(profile.id)
        status = "pending"
        @send_approval_email_to_manager = true
      end
    end

    old_start_time = event.start_time
    old_end_time = event.end_time
    old_location = event.location

    event.update(event_params)

    if old_start_time != event.start_time || old_end_time != event.end_time || old_location != event.location
      event.participants.each do |participant|
        if participant.profile.email.present?
          recipient = participant.profile.email
          event.send_mail_update_event(recipient)
        end
      end
    end

    render json: { result: "ok", event: event.as_json }
  end

  def unpublish
    profile = current_profile!

    event = Event.find(params[:id])
    authorize event, :update?

    event.update(status: "cancelled")
    event.group.decrement!(:events_count)

    event.participants.each do |participant|
      participant.email_notify!(:cancel)
    end

    render json: { result: "ok", event: event.as_json }
  end

  def check_group_permission
    profile = current_profile!
    event = Event.find(params[:id])
    group = event.group
    tz = group.timezone

    if !group.group_ticket_enabled
      return render json: { result: "ok", check: true, message: "action allowed" }
    end

    if event.owner_id == profile.id || group.is_manager(profile.id) ||
        EventRole.find_by(event_id: event.id, profile_id: profile.id) ||
        EventRole.find_by(event_id: event.id, email: profile.email)

      return render json: { result: "ok", check: true, message: "action allowed" }
    end

    event_period = (event.start_time.in_time_zone(tz).to_date..event.end_time.in_time_zone(tz).to_date)

    TicketItem.where(ticket_type: "group", group_id: group.id, profile_id: profile.id).each do |ticket_item|
      ticket = ticket_item.ticket
      ok = false

      if ticket.start_date.present?
        ok = (ticket.start_date..ticket.end_date).overlaps?(event_period)
      elsif ticket.days_allowed.present?
        ok = ticket.days_allowed.any? { |day| event_period.include?(day) }
      else
        ok = true
      end

      ok = if ticket.tracks_allowed.present?
        ok && ticket.tracks_allowed.intersect?(event.tags)
      else
        ok
      end

      return render json: { result: "ok", check: true, message: "action allowed" } if ok
    end

    render json: { result: "ok", check: false, message: "action not allowed" } if ok
  end

  def join
    profile = current_profile!
    event = Event.find(params[:id])
    status = "attending"

    if event.venue && event.venue.capacity && event.venue.capacity > 0 && event.participants_count >= event.venue.capacity
      raise AppError.new("exceed venue capacity")
    end

    if event.tickets.present?
      raise AppError.new("need processing tickets, use rsvp instead")
    end

    participant = Participant.find_by(event_id: event.id, profile_id: profile.id)
    if !participant
      # return render json: { participant: participant.as_json }
      participant = Participant.new(
        profile: profile,
        event: event,
        status: status,
      )
    end

    participant.save

    event.increment!(:participants_count)

    # if profile.email.present?
    #   recipient = profile.email
    #   event.send_mail_new_event(recipient)
    # end

    render json: { participant: participant.as_json }
  end

  def check
    profile = current_profile!
    event = Event.find(params[:id])

    participant = Participant.find_by(event_id: params[:id], profile_id: params[:profile_id])
    authorize event, :update?
    participant.status = "checked"
    participant.check_time = DateTime.now
    participant.save

    render json: { participant: participant.as_json }
  end

  def cancel
    profile = current_profile!
    event = Event.find(params[:id])

    participant = Participant.find_by(event_id: params[:id], profile_id: profile.id)
    authorize participant, :update?

    # todo : refund or require more action when cancelling paid participants
    participant.update(status: "cancelled")
    event.decrement!(:participants_count)

    if profile.email.present?
      # event.notify_event_registration(profile.email, "You have calcelled an event")
    end

    render json: { participant: participant.as_json }
  end

  private

  def event_params
    params.require(:event).permit(
      :title, :start_time, :end_time, :timezone, :meeting_url, :external_url,
      :venue_id, :location, :formatted_address, :location_viewport, :geo_lat, :geo_lng, :event_type,
      :cover_url, :require_approval, :extra, :content, :notes, :display, :tags, :operators, :max_participant, :min_participant,
      tickets: [
        :title, :content, :check_badge_class_id, :quantity, :end_time, :need_approval, :status,
        :payment_chain, :payment_token_name, :payment_token_address,
        :payment_target_address, :payment_token_price, :payment_metadata, :_destroy,
        payment_methods_attributes: [ :id, :chain, :kind, :token_name, :token_address, :receiver_address, :price, :_destroy ] ],
      promo_codes: [ :id, :selector_type, :label, :code, :receiver_address, :discount_type, :discount, :applicable_ticket_ids, :ticket_item_ids, :expiry_time, :max_allowed_usages, :order_usage_count, :_destroy ],
      event_roles: [ :id, :role, :group_id, :event_id, :profile_id, :email, :nickname, :image_url, :_destroy ],
      )
  end
end
