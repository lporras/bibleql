# frozen_string_literal: true

# Client app installations registered via the registerInstallation mutation. Revoking one
# revokes its keys and stops it from registering again.
ActiveAdmin.register Installation do
  menu priority: 4, label: "Installations"

  actions :index, :show

  scope :all, default: true
  scope :active
  scope("Revoked") { |scope| scope.where.not(revoked_at: nil) }

  filter :installation_id
  filter :platform, as: :select, collection: Installation::PLATFORMS
  filter :app_version
  filter :last_seen_at
  filter :created_at

  index do
    id_column
    column :installation_id
    column :platform
    column :app_version
    column :last_seen_at
    column :status do |installation|
      if installation.revoked?
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
      row :installation_id
      row :platform
      row :app_version
      row :last_seen_at
      row :status do |installation|
        if installation.revoked?
          status_tag "revoked (#{installation.revoked_at.strftime('%Y-%m-%d')})", class: "red"
        else
          status_tag "active", class: "green"
        end
      end
      row :created_at
    end

    panel "API Keys" do
      table_for resource.api_keys.order(created_at: :desc) do
        column(:token_prefix) { |key| link_to key.token_prefix, admin_api_key_path(key) }
        column :requests_count
        column :last_used_at
        column(:status) { |key| key.revoked? ? status_tag("revoked", class: "red") : status_tag("active", class: "green") }
        column :created_at
      end
    end

    unless resource.revoked?
      panel "Actions" do
        para do
          link_to "Revoke Installation", revoke_admin_installation_path(resource), method: :put, class: "button",
            data: { confirm: "Revoke this installation and all its keys? It will not be able to register again." }
        end
      end
    end
  end

  member_action :revoke, method: :put do
    resource.revoke!
    redirect_to admin_installation_path(resource), notice: "Installation and its keys revoked."
  end
end
