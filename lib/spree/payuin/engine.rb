module Spree
  module Payuin
    class Engine < ::Rails::Engine
      engine_name 'spree_payuin'

      config.autoload_paths += %W(#{config.root}/lib)

      config.generators do |g|
         g.test_framework :rspec
       end

      def self.activate
        Dir.glob(File.join(File.dirname(__FILE__), "../../../app/**/*_decorator*.rb")) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end

      config.to_prepare &method(:activate).to_proc

      initializer "spree_payuin.register.payment_method", :after => "spree.register.payment_methods" do |app|
        app.config.spree.payment_methods << Spree::Payuin::PaymentMethod
      end
    end
  end
end
