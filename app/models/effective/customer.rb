module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :stripe_source # This is the stripe subscription token
    attr_accessor :token # This is a convenience method so we have a place to store StripeConnect temporary access tokens

    belongs_to :user
    has_many :subscriptions, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    has_many :subscribables, through: :subscriptions, source: :subscribable

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # stripe_active_card            :string  # **** **** **** 4242 Visa 05/12
    # stripe_subscription_id        :string  # Each user gets one stripe subscription object, which can contain many items
    # stripe_connect_access_token   :string  # If using StripeConnect and this user is a connected Seller
    #
    # timestamps

    validates :user, presence: true
    validates :stripe_customer_id, if: -> { persisted? }, presence: true

    before_save(if: -> { stripe_customer_id.blank? }) do
      self.stripe_customer_id = stripe_customer.id
    end

    before_save(if: -> { stripe_source.present? }) do
      assign_card!(stripe_source)
    end

    before_save(if: -> { subscriptions.present? && stripe_subscription_id.blank? }) do
      self.stripe_subscription_id = stripe_subscription.id
    end

    before_save(if: -> { subscriptions.any? { |sub| sub.changed? } }) do
      # I'm not sure how to update! It might be a full delete and recreate as a new subscription
      #::Stripe::Subscription.create(customer: stripe_customer_id, items: subscription_items, metadata: { user_id: user.id })
    end

    def self.for_user(user)
      Effective::Customer.where(user: user).first_or_initialize
    end

    def to_s
      user.to_s.presence || 'New Customer'
    end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        Rails.logger.info "STRIPE CUSTOMER RETRIEVE: #{stripe_customer_id}"
        ::Stripe::Customer.retrieve(stripe_customer_id)
      else
        Rails.logger.info "STRIPE CUSTOMER CREATE: #{user.email} and #{user.id}"
        ::Stripe::Customer.create(email: user.email, description: "User #{user.id}", metadata: { user_id: user.id })
      end
    end

    def stripe_subscription
      @stripe_subscription ||= if stripe_subscription_id.present?
        Rails.logger.info "STRIPE SUBSCRIPTION RETRIEVE: #{stripe_subscription_id}"
        ::Stripe::Subscription.retrieve(stripe_subscription_id)
      else
        Rails.logger.info "STRIPE SUBSCRIPTION CREATE: #{stripe_customer_id}"
        ::Stripe::Subscription.create(customer: stripe_customer_id, items: subscription_items, metadata: { user_id: user.id })
      end
    end

    def stripe_source=(token)
      @stripe_source = token;
      self.updated_at = Time.zone.now if token.present?
    end

    private

    def subscription_items
      binding.pry
      # TODO the real subscriptions man.
      [{plan: 'bronze', quantity: 1}]
    end

    def assign_card!(token)
      return true unless token.present?

      stripe_customer.source = token

      Rails.logger.info "STRIPE CUSTOMER SOURCE UPDATE #{token}"
      if stripe_customer.save == false
        self.errors.add(:stripe_active_card, 'unable to update stripe active card')
        raise 'unable to update stripe active card'
      end

      if stripe_customer.default_source.present?
        card = stripe_customer.sources.retrieve(stripe_customer.default_source)
        self.stripe_active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
      end

      true
    end

    def update_card!(token)
      assign_card(token)
      save!
    end

  end
end
