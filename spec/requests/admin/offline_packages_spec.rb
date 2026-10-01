require "rails_helper"

RSpec.describe "Admin::OfflinePackages", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:admin) { create(:admin_user, email: "admin@example.com", password: "password") }
  let(:translation) { create(:translation, offline_downloadable: true) }

  before do
    sign_in admin
    allow(OfflinePackages).to receive(:configured?).and_return(true)
  end

  describe "GET /admin/offline_packages" do
    it "lists translations with their package" do
      create(:offline_package, translation: translation, size_bytes: 2_500_000)
      create(:translation, identifier: "eng-niv", name: "NIV")

      get admin_offline_packages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("eng-web", "eng-niv", "2.38 MB")
    end
  end

  describe "GET /admin/offline_packages/:id" do
    it "shows the generate button for a downloadable translation" do
      get admin_offline_package_path(translation)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Generate offline package", "Mark as not downloadable")
    end

    it "lists the published packages" do
      create(:offline_package, translation: translation, size_bytes: 2_500_000, uncompressed_size_bytes: 7_500_000,
        sha256: "a" * 64)

      get admin_offline_package_path(translation)

      expect(response.body).to include("2.38 MB", "7.15 MB", "a" * 64)
      expect(response.body).not_to include("No package has been exported yet.")
    end

    it "says when no package has been exported" do
      get admin_offline_package_path(translation)
      expect(response.body).to include("No package has been exported yet.")
    end

    it "offers to flag a translation that is not downloadable, with a licensing warning" do
      translation.update!(offline_downloadable: false)

      get admin_offline_package_path(translation)

      expect(response.body).to include("Mark as offline-downloadable", "API access is not redistribution rights")
      expect(response.body).not_to include("Generate offline package")
    end

    it "warns when storage is not configured" do
      allow(OfflinePackages).to receive(:configured?).and_return(false)

      get admin_offline_package_path(translation)
      expect(response.body).to include("Offline storage is not configured")
    end
  end

  describe "PUT /admin/offline_packages/:id/generate" do
    it "enqueues a forced export" do
      expect { put generate_admin_offline_package_path(translation) }
        .to have_enqueued_job(ExportOfflinePackageJob).with(translation.id, force: true)
      expect(flash[:notice]).to include("enqueued")
    end

    it "refuses a translation that is not offline-downloadable" do
      translation.update!(offline_downloadable: false)

      expect { put generate_admin_offline_package_path(translation) }.not_to have_enqueued_job(ExportOfflinePackageJob)
      expect(flash[:alert]).to include("not flagged")
    end

    it "refuses when storage is not configured" do
      allow(OfflinePackages).to receive(:configured?).and_return(false)

      expect { put generate_admin_offline_package_path(translation) }.not_to have_enqueued_job(ExportOfflinePackageJob)
      expect(flash[:alert]).to include("not configured")
    end
  end

  describe "PUT /admin/offline_packages/:id/toggle_downloadable" do
    it "turns the licensing flag off" do
      put toggle_downloadable_admin_offline_package_path(translation)

      expect(translation.reload.offline_downloadable).to be(false)
      expect(response).to redirect_to(admin_offline_package_path(translation))
      expect(flash[:notice]).to eq("eng-web is no longer offline-downloadable.")
    end

    it "turns the licensing flag on" do
      translation.update!(offline_downloadable: false)

      put toggle_downloadable_admin_offline_package_path(translation)

      expect(translation.reload.offline_downloadable).to be(true)
      expect(flash[:notice]).to eq("eng-web is now offline-downloadable.")
    end
  end

  describe "batch generate" do
    it "enqueues only the downloadable translations" do
      other = create(:translation, identifier: "eng-niv", name: "NIV")

      expect {
        post batch_action_admin_offline_packages_path,
          params: { batch_action: "generate_offline_packages", collection_selection: [ translation.id, other.id ] }
      }.to have_enqueued_job(ExportOfflinePackageJob).exactly(:once).with(translation.id, force: true)
      expect(flash[:notice]).to include("Skipped 1")
    end

    it "refuses when storage is not configured" do
      allow(OfflinePackages).to receive(:configured?).and_return(false)

      expect {
        post batch_action_admin_offline_packages_path,
          params: { batch_action: "generate_offline_packages", collection_selection: [ translation.id ] }
      }.not_to have_enqueued_job(ExportOfflinePackageJob)
      expect(flash[:alert]).to include("not configured")
    end
  end
end
