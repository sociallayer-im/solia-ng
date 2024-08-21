class Api::BadgeClassController < ApplicationController

  def create
    profile = current_profile!

     # need test
    if params[:group_id]
      @group = Group.find(params[:group_id])
      authorize @group, :manage?, policy_class: GroupPolicy
    end

    content = Sanitize.fragment(params[:content], Sanitize::Config::RELAXED)

    @badge_class = BadgeClass.new(
      name: params[:name],  # need name rule and test
      title: params[:title],
      group_id: params[:group_id], # need test
      creator_id: profile.id,
      content: content,
      metadata: params[:metadata],
      image_url: params[:image_url],
      # badge_type: params[:badge_type] || 'badge', # need test
      transferable: params[:transferable] || false, # need test
      revocable: params[:revocable] || false, # need test
      weighted: params[:weighted] || false, # need test
      encrypted: params[:encrypted] || false, # need test
    )
    # need domain
    @badge_class.save
    render json: { result: "ok", badge_class: @badge_class.as_json }
  end

end
