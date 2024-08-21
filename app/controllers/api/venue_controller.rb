class Api::VenueController < ApplicationController

  def create
    profile = current_profile!
    group = Group.find(params[:group_id])

    params.permit(
      :title, :location, :about, :link, :capacity, :formatted_address, :location_viewport, :geo_lat, :geo_lng, :start_date, :end_date, :timeslots, :overrides, :require_approval, :visibility, :tags,
      :venue_overrides => [:id, :group_id, :venue_id, :day, :disabled, :start_at, :end_at, :_destroy],
      :venue_timeslots => [:id, :group_id, :venue_id, :day_of_week, :disabled, :start_at, :end_at, :_destroy])

    venue = Venue.new(params)
    venue.update(
      owner: profile,
      group: group,
    )
    render json: { venue: venue.as_json }
  end

  def update
    profile = current_profile!
    venue = Venue.find(params[:id])
    authorize venue.group, :manage_venue?

    params.permit(
          :title, :location, :about, :link, :capacity, :formatted_address, :location_viewport, :geo_lat, :geo_lng, :start_date, :end_date, :timeslots, :overrides, :require_approval, :visibility, :tags,
          :venue_overrides => [:id, :group_id, :venue_id, :day, :disabled, :start_at, :end_at, :_destroy],
          :venue_timeslots => [:id, :group_id, :venue_id, :day_of_week, :disabled, :start_at, :end_at, :_destroy])
    venue.update(params)

    render json: { venue: venue.as_json }
  end

  def remove
    profile = current_profile!
    venue = Venue.find(params[:id])
    authorize venue.group, :manage_venue?

    venue.update(visibility: 'none')

    render json: { venue: venue.as_json }
  end

end
