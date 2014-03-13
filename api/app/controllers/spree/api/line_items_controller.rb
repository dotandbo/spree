module Spree
  module Api
    class LineItemsController < Spree::Api::BaseController

      def create
        variant = Spree::Variant.find(params[:line_item][:variant_id])
        @line_item = order.contents.add(variant, params[:line_item][:quantity])
        if @line_item.save
          @order.ensure_updated_shipments
          respond_with(@line_item, status: 201, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def update
        @line_item = find_line_item
        if @line_item.update_attributes(line_item_params)
          @order.ensure_updated_shipments
          respond_with(@line_item, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def destroy
        @line_item = find_line_item
        variant = Spree::Variant.find(@line_item.variant_id)
        @order.contents.remove(variant, @line_item.quantity)
        @order.ensure_updated_shipments
        respond_with(@line_item, status: 204)
      end

      private

        def order
          @order ||= Spree::Order.includes(:line_items).find_by!(number: params[:order_id])
          authorize! :update, @order, order_token
        end

        def find_line_item
          id = params[:id].to_i
          order.line_items.detect {|line_item| line_item.id == id} or
            raise ActiveRecord::RecordNotFound
        end

        def line_item_params
          whitelisted_params = [:quantity, :variant_id]
          whitelisted_params += [:price, :estimated_ship_date] if current_api_user.admin?
          params.require(:line_item).permit whitelisted_params
        end
    end
  end
end
