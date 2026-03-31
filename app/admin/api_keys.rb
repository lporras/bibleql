# frozen_string_literal: true

ActiveAdmin.register ApiKey do
  menu priority: 3, label: "API Keys"

  actions :index, :show

  scope :all, default: true
  scope :active
  scope :live
  scope("Test") { |scope| scope.test_env }

  filter :email
  filter :name
  filter :token_prefix
  filter :environment, as: :select, collection: %w[live test]
  filter :created_at

  index do
    selectable_column
    id_column
    column :token_prefix
    column :name
    column :email
    column :environment
    column :requests_count
    column :last_used_at
    column :status do |key|
      if key.revoked?
        status_tag "revoked", class: "red"
      else
        status_tag "active", class: "green"
      end
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :token_prefix
      row :name
      row :email
      row :environment
      row :requests_count
      row :last_used_at
      row :daily_limit
      row :status do |key|
        if key.revoked?
          status_tag "revoked (#{key.revoked_at.strftime('%Y-%m-%d')})", class: "red"
        else
          status_tag "active", class: "green"
        end
      end
      row :created_at
      row :updated_at
    end

    unless resource.revoked?
      panel "Actions" do
        para do
          link_to "Regenerate & Resend", regenerate_admin_api_key_path(resource),
            method: :put, class: "button",
            data: { confirm: "This will revoke the current key, generate a new one, and email it to #{resource.email}. Continue?" }
        end
        para do
          link_to "Revoke Key", revoke_admin_api_key_path(resource),
            method: :put, class: "button",
            data: { confirm: "Revoke this API key? This cannot be undone." }
        end
      end
    end
  end

  member_action :regenerate, method: :put do
    new_key = resource.regenerate!
    ApiKeyMailer.key_approved(new_key, new_key.token).deliver_later
    redirect_to admin_api_key_path(new_key), notice: "New key generated and sent to #{new_key.email}."
  end

  member_action :revoke, method: :put do
    resource.revoke!
    redirect_to admin_api_key_path(resource), notice: "API key revoked."
  end
end
