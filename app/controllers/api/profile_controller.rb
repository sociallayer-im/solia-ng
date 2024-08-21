class Api::ProfileController < ApplicationController
  def current
    @profile = current_profile!
    render json: @profile
  end

  def nonce
    render json: { nonce: rand(100_000_000_000_000_000).to_s(16) }
  end

  def verify
    begin
      signature = params[:signature]
      message = Siwe::Message.from_message params[:message]
      message.verify(signature, message.domain, message.issued_at, message.nonce)
      address = message.address

      profile = Profile.find_or_create_by(address: address)

      SigninActivity.create(
        app: params[:app],
        address: address,
        address_type: 'eth_wallet',
        address_source: params[:address_source],
        profile_id: profile.id,
        locale: params[:locale],
        lang: params[:lang],
        remote_ip: request.remote_ip,
        )
      if params[:app] == "seedao.sola.day" || params[:app] == "seedaobeta.sola.day"
        seedao_group_name = params[:app].sub(".sola.day","")
        seedao_group = Group.find_by(username: seedao_group_name)
        data = RestClient.get("https://sola.deno.dev/seedao/getname/#{address}")
        domain = JSON.parse(data.body)["domain"]
        if domain.present? && seedao_group
          membership = Membership.find_by(profile_id: profile.id, target_id: seedao_group.id)
          if !membership
            Membership.create(profile_id: profile.id, target_id: seedao_group.id, role: "member", status: "normal")
          end
        end
      end
      render json: { result: "ok", auth_token: profile.gen_auth_token, address: address, id: profile.id }
    rescue Siwe::ExpiredMessage
      render json: { result: "error", message: "Siwe::ExpiredMessage" }
    rescue Siwe::NotValidMessage
      render json: { result: "error", message: "Siwe::NotValidMessage" }
    rescue Siwe::InvalidSignature
      render json: { result: "error", message: "Siwe::InvalidSignature" }
    end
  end

  def signin_with_phone
    vcode = MailToken.find_by(email: params[:phone], code: params[:code])
    return render json: { result: "error", message: "PhoneSignIn::InvalidEmailOrCode" } unless vcode
    return render json: { result: "error", message: "PhoneSignIn::Expired" } unless DateTime.now < (vcode.created_at + 30.minute)
    return render json: { result: "error", message: "PhoneSignIn::CodeIsUsed" } if vcode.verified

    vcode.update(verified: true)

    profile = Profile.find_or_create_by(phone: params[:phone])

    SigninActivity.create(
      app: params[:app],
      address: params[:phone],
      address_type: 'phone',
      address_source: params[:address_source],
      profile_id: profile.id,
      locale: params[:locale],
      lang: params[:lang],
      remote_ip: request.remote_ip,
      )
    render json: { result: "ok", auth_token: profile.gen_auth_token, phone: params[:phone], id: profile.id, address_type: "phone" }
  end

  def signin_with_email
    token = MailToken.find_by(email: params[:email], code: params[:code])
    return render json: { result: "error", message: "EMailSignIn::InvalidEmailOrCode" } unless token
    return render json: { result: "error", message: "EMailSignIn::Expired" } unless DateTime.now < (token.created_at + 30.minute)
    return render json: { result: "error", message: "EMailSignIn::CodeIsUsed" } if token.verified

    token.update(verified: true)

    profile = Profile.find_or_create_by(email: params[:email])

    SigninActivity.create(
      app: params[:app],
      address: params[:email],
      address_type: 'email',
      address_source: params[:address_source],
      profile_id: profile.id,
      locale: params[:locale],
      lang: params[:lang],
      remote_ip: request.remote_ip,
      )
    render json: { result: "ok", auth_token: profile.gen_auth_token, email: params[:email], id: profile.id, address_type: "email" }
  end

  def signin_with_multi_zupass
    unless params[:next_token] == ENV['NEXT_TOKEN']
      raise AppError.new("invalid next token")
    end

    zupass_list = params[:zupass_list]
    first_pass = zupass_list.first
    profile = Profile.find_or_create_by(email: params[:email])
    profile.update(
      zupass: "#{first_pass[:zupass_event_id]}:#{first_pass[:zupass_product_id]}",
      )

    has_edge_zupass = zupass_list.any? { |e| e[:zupass_event_id] == "21c7db2e-08e3-4234-9a6e-386a592d63c8" || e[:zupass_event_id] == "63502757-b6fc-4a98-8bbb-76cb901d63fe" }
      membership = Membership.find_by(profile_id: profile.id, target_id: edge_group_id)
      if !membership
        Membership.create(profile_id: profile.id, target_id: edge_group_id, role: "member", status: "normal")
      end
    end

    SigninActivity.create(
      app: params[:app],
      address: params[:email],
      address_type: 'zupass',
      address_source: params[:address_source],
      data: "zupass:#{first_pass[:zupass_event_id]}:#{first_pass[:zupass_product_id]}",
      profile_id: profile.id,
      locale: params[:locale],
      lang: params[:lang],
      remote_ip: request.remote_ip,
      )
    render json: { result: "ok", auth_token: profile.gen_auth_token, email: params[:email], id: profile.id, address_type: "zupass" }
  end

  def signin_with_zupass
    unless params[:next_token] == ENV['NEXT_TOKEN']
      raise AppError.new("invalid next token")
    end

    profile = Profile.find_or_create_by(email: params[:email])
    profile.update(
      zupass: "#{params[:zupass_event_id]}:#{params[:zupass_product_id]}",
      )

    SigninActivity.create(
      app: params[:app],
      address: params[:email],
      address_type: 'zupass',
      address_source: params[:address_source],
      data: "zupass:#{params[:zupass_event_id]}:#{params[:zupass_product_id]}",
      profile_id: profile.id,
      locale: params[:locale],
      lang: params[:lang],
      remote_ip: request.remote_ip,
      )
    render json: { result: "ok", auth_token: profile.gen_auth_token, email: params[:email], id: profile.id, address_type: "zupass" }
  end

  def signin_with_solana
    unless params[:next_token] == ENV['NEXT_TOKEN']
      raise AppError.new("invalid next token")
    end

    profile = Profile.find_or_create_by(sol_address: params[:sol_address])

    SigninActivity.create(
      app: params[:app],
      address: params[:email],
      address_type: 'solana_wallet',
      address_source: params[:address_source],
      profile_id: profile.id,
      locale: params[:locale],
      lang: params[:lang],
      remote_ip: request.remote_ip,
      )
    render json: { result: "ok", auth_token: profile.gen_auth_token, email: params[:email], id: profile.id, address_type: "solana_wallet" }
  end

  def signin_with_farcaster
    unless params[:next_token] == ENV['NEXT_TOKEN']
      raise AppError.new("invalid next token")
    end

    profile = Profile.find_or_create_by(far_fid: params[:far_fid])
    profile.update(far_address: params[:far_address])

    SigninActivity.create(
      app: params[:app],
      address: params[:email],
      address_type: 'farcaster',
      address_source: params[:address_source],
      profile_id: profile.id,
      locale: params[:locale],
      lang: params[:lang],
      remote_ip: request.remote_ip,
      )
    render json: { result: "ok", auth_token: profile.gen_auth_token, email: params[:email], id: profile.id, address_type: "farcaster" }
  end

  def set_verified_email
    profile = current_profile!

    if Profile.find_by(email: params[:email])
      render json: { result: "error", message: "profile with the same email exists" }
      return
    end

    if profile.email
      render json: { result: "error", message: "profile email exists" }
      return
    end

    token = MailToken.find_by(email: params[:email], code: params[:code])
    return render json: { result: "error", message: "EMailSignIn::InvalidEmailOrCode" } unless token
    return render json: { result: "error", message: "EMailSignIn::Expired" } unless DateTime.now < (token.created_at + 30.minute)
    return render json: { result: "error", message: "EMailSignIn::CodeIsUsed" } if token.verified

    token.update(verified: true)

    profile.update(email: params[:email])

    render json: { result: "ok", email: params[:email], id: profile.id }
  end

  def set_verified_address
    profile = current_profile!

    begin
      signature = params[:signature]
      message = Siwe::Message.from_message params[:message]
      message.verify(signature, message.domain, message.issued_at, message.nonce)

      address = message.address

      if Profile.find_by(address: address)
        render json: { result: "error", message: "profile with the same address already exists" }
        return
      end

      if profile.address
        render json: { result: "error", message: "profile address exists" }
        return
      end

      profile.update(address: address)

      render json: { result: "ok", email: profile.email, address: message.address, id: profile.id }
    rescue Siwe::ExpiredMessage
      render json: { result: "error", message: "Siwe::ExpiredMessage" }
    rescue Siwe::NotValidMessage
      render json: { result: "error", message: "Siwe::NotValidMessage" }
    rescue Siwe::InvalidSignature
      render json: { result: "error", message: "Siwe::InvalidSignature" }
    end
  end

  def create
    username = params[:username]
    unless check_profile_username_and_length(username)
      render json: { result: "error", message: "invalid username" }
      return
    end

    @profile = current_profile
    unless @profile
      render json: { result: "error", message: "profile not exists" }
      return
    end

    if @profile.username
      render json: { result: "error", message: "profile username is already set" }
      return
    end

    if Profile.find_by(username: username) || Group.find_by(username: username)
      render json: { result: "error", message: "profile username exists" }
      return
    end

    @profile.update(username: username)
    render json: { result: "ok" }
  end

  def update
    @profile = current_profile!
    @profile.update(
      nickname: params[:nickname],
      image_url: params[:image_url],
      twitter: params[:twitter],
      github: params[:github],
      discord: params[:discord],
      telegram: params[:telegram],
      farcaster: params[:farcaster],
      ens: params[:ens],
      lens: params[:lens],
      nostr: params[:nostr],
      website: params[:website],
      location: params[:location],
      about: params[:about],
    )
    render json: { result: "ok" }
  end

  def get_by_email
    profile = Profile.find_by(email: params[:email])
    render json: { profile: profile.as_json }
  end

  def follow
    profile = current_profile!
    target = Profile.find(params[:target_id])

    if profile.id == target.id
      render json: { result: "error", message: "can not follow yourself" }
      return
    end

    if Following.find_by(profile_id: profile.id, target_id: target.id, role: "follower")
      render json: { result: "error", message: "follow exists" }
      return
    end
    Following.create(profile_id: profile.id, target_id: target.id, role: "follower")
    render json: { result: "ok" }
  end

  def unfollow
    profile = current_profile!
    target = Profile.find(params[:target_id])

    results = Following.where(profile_id: profile.id, target_id: params[:target_id], role: "follower").delete_all
    render json: { result: "ok" }
  end

  def me
    profile = current_profile!
    render json: { profile: profile.as_json }
  end

  def get_edge
    profile = current_profile!
    email = profile.email
    if email.blank?
      return render json: { balance: 0 }
    end

    begin
      url='https://edges.radicalxchange.org/api/auth/account'
      resp = RestClient.get(url, {params: {email: email, 'secret' => ENV['EDGE_SECRET']}})
      balance = JSON.parse(resp.body)["account"]["balance"]
      return render json: { balance: balance, email: email }
    rescue StandardError => e
      return render json: { balance: 0 }
    end
  end

end
