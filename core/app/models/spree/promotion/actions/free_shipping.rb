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
            source: self,
            label: label,
          )
          true
        end

        def label
          "Promotion: " + (promotion.code ? "Free Shipping (#{promotion.code})" : "#{promotion.name}")
        end

        def compute_amount(order)
          BigDecimal(order.shipments.try(:first).try(:cost).to_s) * -1
        end

        private

        def promotion_credit_exists?(order)
          order.adjustments.exists?(source_id: self.id)
        end
      end
    end
  end
end
