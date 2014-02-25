#Copyright 2013 ThoughtWorks, Inc. Licensed under the Apache License, Version 2.0.
module Spree
  module Payuin
    class PaymentTransaction < ActiveRecord::Base
      self.table_name = 'spree_payuin_payment_transactions'
      belongs_to :payment_method, :class_name => 'Spree::Payuin::PaymentMethod'

      attr_accessible :status, :response, :payment_method_id, :checksum, :transaction_id

      #attr_accessor :authorization, :avs_result

      def success?
        ["in progress", "success"].include? self.status
      end

      def self.build_using order, payment_method
        Spree::Payuin::PaymentTransaction.new.tap do |t|
          t.payment_method = payment_method
          t.generate_transaction_id
          t.generate_checksum(order)
        end
      end

      def checksum_valid? checksum_data
        salt = payment_method.preferred_salt
        options = checksum_data.slice(:status,:email,:firstname,:productinfo,:amount,:txnid,:key).merge(:salt => salt)
        checksum_data[:hash] == Digest::SHA512.hexdigest(return_checksum_template(options))
      end

      def generate_checksum order
        options = {}
        options[:key] = payment_method.preferred_merchant_id
        options[:txnid] = self.transaction_id
        options[:amount] = order.total.to_f
        options[:productinfo] = order.number
        options[:firstname] = order.bill_address.firstname
        options[:email] = order.user.email
        options[:salt] = payment_method.preferred_salt
        self.checksum = Digest::SHA512.hexdigest(checksum_template(options))
      end

      def generate_transaction_id
        self.transaction_id = SecureRandom.hex(7)
      end


      def checksum_template options
        "#{options[:key]}|#{options[:txnid]}|#{options[:amount]}|#{options[:productinfo]}|#{options[:firstname]}|#{options[:email]}|||||||||||#{options[:salt]}"
      end

      def return_checksum_template options
        "#{options[:salt]}|#{options[:status]}|||||||||||#{options[:email]}|#{options[:firstname]}|#{options[:productinfo]}|#{options[:amount]}|#{options[:txnid]}|#{options[:key]}"
      end
    end
  end
end
