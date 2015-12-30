module EffectiveOrders
  module Generators
    class UpgradeFrom17xGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc 'Upgrade effective_orders from the 1.7.x branch'

      source_root File.expand_path('../../templates', __FILE__)

      def self.next_migration_number(dirname)
        if not ActiveRecord::Base.timestamped_migrations
          Time.new.utc.strftime('%Y%m%d%H%M%S')
        else
          '%.3d' % (current_migration_number(dirname) + 1)
        end
      end

      def create_migration_file
        @orders_table_name = ':' + EffectiveOrders.orders_table_name.to_s
        @order_items_table_name = ':' + EffectiveOrders.order_items_table_name.to_s
        @carts_table_name = ':' + EffectiveOrders.carts_table_name.to_s
        @cart_items_table_name = ':' + EffectiveOrders.cart_items_table_name.to_s
        @customers_table_name = ':' + EffectiveOrders.customers_table_name.to_s
        @subscriptions_table_name = ':' + EffectiveOrders.subscriptions_table_name.to_s
        @custom_products_table_name = ':' + EffectiveOrders.custom_products_table_name.to_s

        migration_template '../../../db/upgrade/03_upgrade_effective_orders_from17x.rb.erb', 'db/migrate/upgrade_effective_orders_from17x.rb'
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end
    end
  end
end