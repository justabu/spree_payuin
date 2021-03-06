Spree::CheckoutController.class_eval do
  skip_before_filter :verify_authenticity_token,:ensure_valid_state, :only=> [:callback]

  def callback
    @order = Spree::Order.find_by_number params[:productinfo]
    payment = @order.payment
    record_transaction payment
    p "callback" * 80
    p "#{params[:status]}"*80
    payment.source.update_attributes!(:status => params[:status])
    verify_checksum params
    status_callback
  end

  def before_external_payment
    order = Spree::Order.find_by_id(session[:order_id], :include => :adjustments)
    order.payments.destroy_all
    payment_method = Spree::PaymentMethod.find_by_type "Spree::Payuin::PaymentMethod"
    order.payments.build(:amount => order.total, :payment_method_id => payment_method.id)
    payment = Spree::Payuin::PaymentTransaction.build_using order, payment_method
    order.payment.source = payment
    order.state = "external_payment"
    order.save!
  end

  def state_callback(before_or_after = :before)
      method_name = :"#{before_or_after}_#{@order.state}"
      p "calling #{method_name}"*80
      send(method_name) if respond_to?(method_name, true)
  end
  

  def before_complete
    unless @order.payment.source.success?
      flash[:error] = t(:payment_processing_failed)
      redirect_to spree.edit_order_path(@order)
    end
  end

  private
 # def ensure_valid_state

 #   unless skip_state_validation?
 #     if (params[:state] && !@order.has_checkout_step?(params[:state])) ||
 #       (!params[:state] && !@order.has_checkout_step?(@order.state))

 #       @order.state = 'cart'
 #       redirect_to checkout_state_path(@order.checkout_steps.first)
 #     end
 #   end

 # end
      def ensure_valid_state
        unless skip_state_validation?
          if (params[:state] && !@order.has_checkout_step?(params[:state])) ||
             (!params[:state] && !@order.has_checkout_step?(@order.state))

            @order.state = 'cart'
            redirect_to checkout_state_path(@order.checkout_steps.first)
          end
        end

        # Fix for #4117
        # If confirmation of payment fails, redirect back to payment screen
        #if params[:state] == "confirm" && @order.payment_required? && @order.payments.valid.empty?
        #  flash.keep
        #  redirect_to checkout_state_path("payment")
        #end
      end



  def status_callback
    callback_method = "#{params[:status]}_callback".gsub(/\s/,'_')
    unless verify_response_status(callback_method)
      @order.payment.source.update_attributes(:status => 'failure')
      flash[:error] = "#{t(:payment_processing_failed)}. Unknown status response from the gateway"
      redirect_to spree.checkout_state_path(@order) and return
    end
    self.send(callback_method)
  end

  def verify_response_status callback_method
    ['success_callback', 'failure_callback', 'cancel_callback', 'in_progress_callback'].include? callback_method
  end

  def verify_checksum params
    valid = @order.payment.source.checksum_valid?(params)
    unless valid
      @order.payment.source.update_attributes(:status => 'failure')
      flash[:error] = t(:payment_processing_failed)
      redirect_to spree.checkout_state_path(@order)
    end
  end

  def success_callback
    if @order.next
      state_callback(:after)
    else
      flash[:error] = t(:payment_processing_failed)
      redirect_to spree.checkout_state_path(@order) and return
    end

    if @order.state == "complete" || @order.completed?
      flash[:notice] = t(:order_processed_successfully)
      redirect_to spree.order_path(@order, { :checkout_complete => true }) and return
    else
      redirect_to spree.checkout_state_path(@order) and return
    end
  end

  def failure_callback
    @order.state = "cart"
    @order.save!
    flash[:error] = t(:payment_processing_failed)
    redirect_to spree.edit_order_path(@order)
  end

  def cancel_callback
    @order.state = "cart"
    @order.save!
    flash[:notice] = t(:payment_processing_cancelled)
    redirect_to spree.edit_order_path(@order)
  end

  def record_transaction payment
    payu_response = params.slice("mihpayid", "mode","unmappedstatus","txnid", "hash","PG_TYPE","bank_ref_num","bankcode","error","cardhash")
    log_entry = payment.log_entries.build
    log_entry.details = payu_response.to_json
    log_entry.save!
  end

  alias_method :in_progress_callback, :success_callback
end
