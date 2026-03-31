# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    panel "Pending Requests" do
      para "#{ApiKeyRequest.pending.count} requests awaiting review"
      table_for ApiKeyRequest.pending.order(created_at: :desc).limit(5) do
        column :name
        column :email
        column :environment
        column(:submitted) { |r| time_ago_in_words(r.created_at) + " ago" }
        column("") { |r| link_to "Review", admin_api_key_request_path(r) }
      end
    end

    panel "API Keys Overview" do
      para "#{ApiKey.active.live.count} active live keys"
      para "#{ApiKey.active.test_env.count} active test keys"
      para "#{ApiKey.where.not(revoked_at: nil).count} revoked keys"
    end
  end
end
