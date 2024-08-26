class Api::TicketController < ApiController
  def set_payment_status
      unless params[:next_token] == ENV["NEXT_TOKEN"]
        raise AppError.new("invalid next token")
      end

      profile = current_profile!
      event = Event.find(params[:id])
      participant = Participant.find_by(event_id: event.id, profile_id: profile.id)
      unless participant
        return render json: { result: "error", message: "participant not found" }
      end

      participant = Participant.find_by(event_id: event.id, profile_id: profile.id)

      participant.update(
        status: params[:status],
        payment_status: params[:payment_status],
        payment_data: params[:payment_data],
        payment_chain: params[:payment_chain],
        )
      render json: { participant: participant.as_json }
    end

    def set_ticket_payment_status
      unless params[:next_token] == ENV["NEXT_TOKEN"]
        raise AppError.new("invalid next token")
      end

      # next_token
      # chain
      # product_id - event_id
      # item_id - order_number
      # amount
      # txhash

      ticket_item = TicketItem.find_by(chain: params[:chain], event_id: params[:product_id], order_number: params[:item_id].to_s)
      if ticket_item.status == "succeeded"
        return render json: { result: "ok", message: "skip verify succeeded ticket_item" }
      end

      unless ticket_item
        return render json: { result: "error", message: "ticket_item not found" }
      end

      if params[:amount].to_i < ticket_item.amount
        return render json: { result: "error", message: "amount invalid" }
      end

      # todo : verify token_address, receiver_address, chain

      ticket_item.update(
        status: "succeeded",
        txhash: params[:txhash],
        )

      if ticket_item.participant.payment_status != "succeeded"
        ticket_item.participant.update(payment_status: "succeeded")
        if ticket_item.profile.email.present?
          ticket_item.event.send_mail_new_event(ticket_item.profile.email)
        end
      end

      render json: { participant: ticket_item.participant.as_json, ticket_item: ticket_item.as_json }
    end

    def rsvp
      profile = current_profile!
      event = Event.find(params[:id])
      status = "attending"

      if event.venue && event.venue.capacity && event.venue.capacity > 0 && event.participants_count >= event.venue.capacity
        raise AppError.new("exceed venue capacity")
      end

      ticket = Ticket.find_by(id: params[:ticket_id], event_id: event.id)
      if ticket.quantity
        raise AppError.new("run out of ticket") if ticket.quantity <= 0
        ticket.decrement!(:quantity)
      end

      participant = Participant.find_by(event_id: event.id, profile_id: profile.id)
      if !participant
        participant = Participant.create(
          profile: profile,
          event: event,
          role: "attendee",
          status: status,
          message: params[:message],
          ticket_id: ticket.id, # todo : remove ticket relation or use first success ticket relation
        )
      end

      if ticket.payment_methods.any?
        paymethod = PaymentMethod.find_by(id: params[:payment_method_id], item_type: "Ticket", item_id: ticket.id)
        unless paymethod
          return render json: { result: "error", message: "payment_method not found" }
        end
        amount = paymethod.price
        discount_value = nil
        discount_data = nil

        if params[:promo_code].present?
          pcode = PromoCode.find_by(selector_type: "code", code: params[:promo_code])
          if pcode.expiry_time > DateTime.now && pcode.max_allowed_usages > pcode.order_usage_count
            if pcode.discount_type == "ratio"
              amount = amount * pcode.discount / 10000
            elsif pcode.discount_type == "amount"
              discount = paymethod.chain == "stripe" ? discount : discount * 10000
              amount = amount - pcode.discount
            end
            discount_value = paymethod.price - amount
            discount_data = "id=#{pcode.id}|#{pcode.discount_type}|#{pcode.discount}"
            pcode.increment!(:order_usage_count)
          end
        end
        ticket_item = TicketItem.create(
          status: "pending",
          profile_id: profile.id,
          ticket_id: ticket.id,
          event_id: event.id,
          chain: paymethod.chain,
          participant_id: participant.id,
          amount: amount,
          ticket_price: paymethod.price,
          payment_method_id: params[:payment_method_id],
          )

        if amount == 0
          ticket_item.update(status: "succeeded")
        end
      else
        ticket_item = TicketItem.create(
          status: "succeeded",
          profile_id: profile.id,
          ticket_id: ticket.id,
          event_id: event.id,
          participant_id: participant.id,
          amount: 0,
          ticket_price: 0,
          )
      end

      event.increment!(:participants_count)

      ticket_item.update(
        order_number: (ticket_item.id + 1000000).to_s,
        )

      if ticket_item.status == "succeeded"
        participant.update(payment_status: "succeeded")
        if profile.email.present?
          event.send_mail_new_event(profile.email)
        end
      end

      render json: { participant: participant.as_json, ticket_item: ticket_item.as_json }
    end

    def check_promo_code
      promo_code = PromoCode.find_by(event_id: params[:event_id], code: params[:code])
      render json: { promo_code: promo_code.as_json }
    end

    def get_promo_code
      promo_code = PromoCode.find(params[:id])
      authorize promo_code.event, :update?
      render json: { promo_code_id: promo_code.id, code: promo_code.code }
    end
end
