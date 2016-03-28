module Spree
  module PromotionHandler
    # Used for activating promotions with shipping rules
    class FreeShipping
      attr_reader :order
      attr_accessor :error, :success

      def initialize(order)
        @order = order
      end

      def activate
        promotions.each do |promotion|
          if promotion.eligible?(order)
            promotion.activate(order: order) if (order.coupon_code == promotion.code || promotion.code.nil?)
          end
        end
      end

      private

        def promotions
          Spree::Promotion.active.where({
            :id => Spree::Promotion::Actions::FreeShipping.pluck(:promotion_id),
            :path => nil
          })
        end
    end
  end
end
