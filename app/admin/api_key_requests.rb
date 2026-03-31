# frozen_string_literal: true

ActiveAdmin.register ApiKeyRequest do
  menu priority: 2, label: "Key Requests"

  actions :index, :show

  scope :all, default: true
  scope :pending
  scope :approved
  scope :rejected

  filter :email
  filter :environment, as: :select, collection: %w[live test]
  filter :status, as: :select, collection: %w[pending approved rejected]
  filter :created_at

  index do
    selectable_column
    id_column
    column :name
    column :email
    column :environment
    column :status do |request|
      status_tag request.status, class: case request.status
                                        when "pending" then "orange"
                                        when "approved" then "green"
                                        when "rejected" then "red"
                                        end
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :name
      row :email
      row :description
      row :environment
      row :status do |request|
        status_tag request.status
      end
      row :rejection_reason
      row :api_key
      row :created_at
      row :updated_at
    end

    if resource.status == "pending"
      panel "Actions" do
        para do
          link_to "Approve", approve_admin_api_key_request_path(resource),
            method: :put, class: "button",
            data: { confirm: "Approve this request and generate an API key?" }
        end
        para do
          render "admin/api_key_requests/reject_form", api_key_request: resource
        end
      end
    end
  end

  member_action :approve, method: :put do
    api_key = resource.approve!
    ApiKeyMailer.key_approved(resource, api_key.token).deliver_later
    redirect_to admin_api_key_request_path(resource), notice: "Request approved. API key sent to #{resource.email}."
  end

  member_action :reject, method: :put do
    resource.reject!(params[:rejection_reason])
    ApiKeyMailer.key_rejected(resource).deliver_later
    redirect_to admin_api_key_request_path(resource), notice: "Request rejected."
  end

  controller do
    def scoped_collection
      super.includes(:api_key)
    end
  end
end
