module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        def perform(payload={})
          order = payload[:order]
          return true if order.shipments.empty?
          return true if promotion_credit_exists?(order)
          order.adjustments.create!(
            order: order,
            amount: compute_amount(order),
            originator_type: "Spree::ShippingMethod",
            source: promotion,
            label: label,
          )
          true
        end

        def label
          "Promotion: " + (promotion.code ? "Free Shipping (#{promotion.code})" : "#{promotion.name}")
        end

        def compute_amount(order)
          order.shipments.try(:first).try(:cost) * -1
        end

        private

        def promotion_credit_exists?(order)
          order.adjustments.exists?(source_id: promotion.id)
        end
      end
    end
  end
end
