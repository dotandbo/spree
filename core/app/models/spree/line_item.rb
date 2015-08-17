module Spree
  class LineItem < Spree::Base
    before_validation :adjust_quantity
    belongs_to :order, class_name: "Spree::Order", inverse_of: :line_items, touch: false
    belongs_to :variant, class_name: "Spree::Variant", inverse_of: :line_items
    belongs_to :tax_category, class_name: "Spree::TaxCategory"

    has_one :product, through: :variant

    has_many :adjustments, as: :adjustable, dependent: :destroy
    has_many :inventory_units, inverse_of: :line_item

    before_validation :copy_price
    before_validation :copy_tax_category

    validates :variant, presence: true
    validates :quantity, numericality: {
      only_integer: true,
      greater_than: -1,
      message: Spree.t('validation.must_be_int')
    }
    validates :price, numericality: true
    validates_with Stock::AvailabilityValidator, unless: ->{ order.can_ship? }

    validate :ensure_proper_currency
    before_destroy :update_inventory
    before_destroy :destroy_inventory_units
    before_save :touch_parent
    after_save :update_inventory
    after_save :update_adjustments

    after_create :update_tax_charge

    delegate :name, :description, :sku, :should_track_inventory?, to: :variant

    attr_accessor :target_shipment

    self.whitelisted_ransackable_associations = ['variant']
    self.whitelisted_ransackable_attributes = ['variant_id']

    def copy_price
      if variant
        self.price = variant.price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = variant.currency if currency.nil?
      end
    end

    def copy_tax_category
      if variant
        self.tax_category = variant.tax_category
      end
    end

    def amount
      price * quantity
    end
    alias subtotal amount


    # A little hacky way to work around known issue on spree 2.2 https://github.com/spree/spree/issues/4760
    # We want to spread order-level adjustment across line_items
    # If there is order-level discount/promotions,
    # Weigh it properly and spread the promotion across the line_items
    def promo_amount
      promo = order.promotions
      return promo_total unless promo
      order_total = order.line_items_total_without_gift_cards
      return 0.0 unless order_total != 0.0
      (order.promo_total * amount) / order_total
    end

    def discounted_amount
      return amount if self.is_gift_card #No discount for giftcards
      amount + promo_amount #discounted_amount = original_amount + (promo_amount) where promoamount is neg. value
    end

    # def discounted_amount
    #   amount + promo_total
    # end

    def final_amount
      amount + adjustment_total.to_f
    end
    alias total final_amount

    def single_money
      Spree::Money.new(price, { currency: currency })
    end
    alias single_display_amount single_money

    def money
      Spree::Money.new(amount, { currency: currency })
    end
    alias display_total money
    alias display_amount money

    def adjust_quantity
      self.quantity = 0 if quantity.nil? || quantity < 0
    end

    def sufficient_stock?
      Stock::Quantifier.new(variant).can_supply? quantity
    end

    def insufficient_stock?
      !sufficient_stock?
    end

    # Remove product default_scope `deleted_at: nil`
    def product
      variant.product
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    private
      def update_inventory
        if (changed? || target_shipment.present?)
          Spree::OrderInventory.new(self.order, self).verify(target_shipment)
        end
      end

      def destroy_inventory_units
        inventory_units.destroy_all
      end

      def update_adjustments
        if quantity_changed?
          update_tax_charge # Called to ensure pre_tax_amount is updated. 
          recalculate_adjustments
        end
      end

      def recalculate_adjustments
        Spree::ItemAdjustments.new(self).update
      end

      def update_tax_charge
        Spree::TaxRate.adjust(order.tax_zone, [self])
      end

      def ensure_proper_currency
        unless currency == order.currency
          errors.add(:currency, :must_match_order_currency)
        end
      end

      def touch_parent
        order.touch if changed?
      end
  end
end
