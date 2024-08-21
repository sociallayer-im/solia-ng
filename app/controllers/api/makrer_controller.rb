class Api::MakrerController < ApplicationController

  def create
    profile = current_profile!
    group = Group.find(params[:group_id])

    params.permit(:marker_type, :category, :voucher_id, :pin_image_url, :cover_image_url,
      :title, :about, :link, :location, :formatted_address, :location_viewport, :geo_lat, :geo_lng,
      :start_time, :end_time, :highlight, :message,
    )
    marker = Marker.new(params)
    marker.update(
    owner: profile,
  	group: group,
    status: 'normal'
    )
    render json: { marker: marker.as_json }
  end

  def update
    profile = current_profile!
    marker = Marker.find(params[:id])
    authorize marker, :update?

    params.permit(:marker_type, :category, :voucher_id, :pin_image_url, :cover_image_url,
          :title, :about, :link, :location, :formatted_address, :location_viewport, :geo_lat, :geo_lng,
          :start_time, :end_time, :highlight, :message,
        )
    marker.update(
      params
    	)
    render json: { marker: marker.as_json }
  end

  def remove
    profile = current_profile!
    marker = Marker.find(params[:id])
    authorize marker, :update?

    marker.update(
    	status: 'removed',
    	)
    render json: { result: "ok" }
  end
end
