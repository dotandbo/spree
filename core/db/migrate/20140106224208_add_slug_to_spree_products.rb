class AddSlugToSpreeProducts < ActiveRecord::Migration
  def change
    add_column :spree_products, :slug, :string
  end
end
