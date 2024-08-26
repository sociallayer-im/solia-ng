class Api::GroupInviteController < ApiController
  def request_invite
    profile = current_profile!
    group = Group.find(params[:group_id])

    if Membership.find_by(profile_id: profile.id, target_id: group.id, role: params[:role])
      return render json: { receiver_id: receiver_id, result: "error", message: "membership exists" }
    end

    if GroupInvite.find_by(receiver_id: profile.id, group_id: group.id, role: params[:role])
      return render json: { receiver_id: receiver_id, result: "error", message: "group invite exists" }
    end

    invite = GroupInvite.create(
      receiver_id: profile.id,
      group_id: group.id,
      message: params[:message],
      role: params[:role],
      expires_at: (DateTime.now + 30.days),
      status: "requesting",
    )
    render json: { group_invite: invite }
  end

  def accept_request
    profile = current_profile!
    @group_invite = GroupInvite.find_by(id: params[:group_invite_id])
    @group = Group.find(@group_invite.group_id)
    authorize @group, :manage?, policy_class: GroupPolicy

    raise AppError.new("invalid status") unless @group_invite.status == "requesting"
    raise AppError.new("invite has been accepted") unless !@group_invite.accepted
    raise AppError.new("invite expired") unless DateTime.now < @group_invite.expires_at

    unless @group.is_owner(profile.id) && [ "member", "issuer", "manager" ].include?(@group_invite.role) || [ "member", "issuer" ].include?(@group_invite.role)
      raise AppError.new("invalid role")
    end

    @group_invite.update(status: "accepted")
    membership = Membership.find_by(profile_id: @group_invite.receiver_id, target_id: @group.id)
    if membership
      membership.update(role: @group_invite.role)
    else
      membership = Membership.create(profile_id: @group_invite.receiver_id, target_id: @group.id, role: @group_invite.role)
      @group.increment!(:memberships_count)
    end

    render json: { result: "ok", membership: membership.as_json }
  end

  # todo : should test on duplicated invite and updating existing members, downgrading members
  def send_invite
    profile = current_profile!
    @group = Group.find(params[:group_id])
    authorize @group, :manage?, policy_class: GroupPolicy
    role = params[:role]

    params[:receivers].each do |receiver|
      raise AppError.new("invalid receiver username") unless Profile.find_by(username: receiver) || Profile.find_by(address: receiver)
    end

    # unless @group.is_owner(profile.id) && ['member', 'issuer', 'manager'].include?(role) || role == 'member'
    #   raise AppError.new('invalid role')
    # end

    @group_invites = []
    params[:receivers].map do |receiver|
      receiver = Profile.find_by(address: receiver) || Profile.find_by(username: receiver)
      receiver_id = receiver.id

      membership = Membership.find_by(profile_id: receiver.id, target_id: @group.id)
      if membership && membership.role == "member"
        membership.update(role: role)
        invite = { receiver_id: receiver_id, result: "ok", message: "membership updated" }
      elsif membership
        invite = { receiver_id: receiver_id, result: "error", message: "membership exists" }
      else
        invite = GroupInvite.create(
          sender_id: profile.id,
          group_id: @group.id,
          message: params[:message],
          role: role,
          expires_at: (DateTime.now + 30.days),
          receiver_id: receiver_id,
        )
        activity = Activity.create(item: invite, initiator_id: profile.id, action: "group_invite/send", receiver_type: "id", receiver_id: receiver.id)
      end

      @group_invites << invite
    end

    render json: { group_invites: @group_invites.as_json }
  end

  def send_invite_by_email
    profile = current_profile!
    group = Group.find(params[:group_id])
    authorize group, :manage?, policy_class: GroupPolicy
    role = params[:role]

    params[:receivers].each do |receiver|
      raise AppError.new("invalid receiver email") unless receiver.include?("@")
    end

    # unless @group.is_owner(profile.id) && ['member', 'issuer', 'manager'].include?(role) || role == 'member'
    #   raise AppError.new('invalid role')
    # end

    group_invites = params[:receivers].map do |receiver|
      invite = GroupInvite.create(
        sender_id: profile.id,
        group_id: group.id,
        message: params[:message],
        role: role,
        expires_at: (DateTime.now + 30.days),
        receiver_address_type: "email",
        receiver_address: receiver,
      )

      invite
    end

    group_invites.each do |invite|
      if ENV["DO_NOT_SEND_EMAIL"].blank?
        mailer = GroupMailer.with(group_name: (group.nickname || group.username), recipient: invite.receiver_address).group_invite_email
        mailer.deliver_now!
      end
    end

    render json: { group_invites: group_invites.as_json }
  end

  def accept_invite
    profile = current_profile!
    group_invite = GroupInvite.find_by(id: params[:group_invite_id], status: "sending")
    group = Group.find(group_invite.group_id)
    authorize group_invite, :accept?
    raise AppError.new("invalid status") unless group_invite.status == "sending"
    raise AppError.new("invite has been accepted") if group_invite.accepted

    group_invite.update(status: "accepted", accepted: true)
    raise AppError.new("invite expired") unless DateTime.now < group_invite.expires_at

    # TODO: mint bage
    if Membership.find_by(profile_id: profile.id, target_id: group.id)
      render json: { result: "error", message: "membership exists" }
      return
    end
    Membership.create(profile_id: profile.id, target_id: group.id, role: group_invite.role)
    group.increment!(:memberships_count)
    render json: { result: "ok" }
  end

  def cancel_invite
    profile = current_profile!
    @group_invite = GroupInvite.find(params[:group_invite_id])
    @group = Group.find(@group_invite.group_id)
    authorize @group_invite, :accept?

    @group_invite.update(status: "cancel")
    render json: { result: "ok" }
  end

  def revoke_invite
    profile = current_profile!
    @group_invite = GroupInvite.find(params[:group_invite_id])
    @group = Group.find(@group_invite.group_id)
    authorize @group_invite, :revoke?

    @group_invite.update(status: "cancel")
    render json: { result: "ok" }
  end
end
