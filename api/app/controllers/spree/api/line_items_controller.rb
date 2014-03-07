module Spree
  module Api
    class LineItemsController < Spree::Api::BaseController
      respond_to :json

      def create
        authorize! :read, order
        @line_item = order.line_items.build(params[:line_item], :as => :api)
        if @line_item.save
          @order.ensure_updated_shipments
          respond_with(@line_item, :status => 201, :default_template => :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def update
        authorize! :read, order
        @line_item = find_line_item
        if @line_item.update_attributes(params[:line_item], :as => :api)
          @order.ensure_updated_shipments
          respond_with(@line_item, :default_template => :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def destroy
        authorize! :read, order
        @line_item = find_line_item
        @line_item.destroy
        respond_with(@line_item, :status => 204)
      end

      private

      def order
        @order ||= Order.find_by_number!(params[:order_id])
      end

      def find_line_item
        order.line_items.detect{|line_item| line_item.id == params[:id].to_i} ||
          raise(ActiveRecord::RecordNotFound, "Could not find line item with id=#{params[:id]}")
      end
    end
  end
end
