Spree::Core::Engine.routes.append do
  #match "checkout/gateway/payuin/callback" => 'checkout#callback', :via => [:post], :as => :gateway_payuin_callback
end
