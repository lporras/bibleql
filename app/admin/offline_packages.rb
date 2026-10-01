# frozen_string_literal: true

# Lists translations with their offline package status and lets an admin flag a
# translation as redistributable and (re)generate its package.
ActiveAdmin.register Translation, as: "Offline Package" do
  menu priority: 3, label: "Offline Packages"

  actions :index, :show

  config.sort_order = "identifier_asc"

  scope :all, default: true
  scope("Downloadable") { |translations| translations.offline_downloadable }
  scope("Not exported") { |translations| translations.offline_downloadable.where.missing(:offline_packages) }

  filter :identifier
  filter :language
  filter :offline_downloadable

  batch_action :generate_offline_packages, confirm: "Generate offline packages for the selected translations?" do |ids|
    translations = Translation.where(id: ids)
    downloadable = translations.select(&:offline_downloadable?)

    if !OfflinePackages.configured?
      redirect_to collection_path, alert: "Offline storage is not configured."
    else
      downloadable.each { |translation| ExportOfflinePackageJob.perform_later(translation.id, force: true) }
      skipped = translations.size - downloadable.size
      notice = "Enqueued #{downloadable.size} export(s)."
      notice += " Skipped #{skipped} not flagged offline-downloadable." if skipped.positive?
      redirect_to collection_path, notice: notice
    end
  end

  index title: "Offline Packages" do
    selectable_column
    column :identifier do |translation|
      link_to translation.identifier, admin_offline_package_path(translation)
    end
    column :name
    column :language
    column :note do |translation|
      translation.note.to_s.truncate(40)
    end
    column "Downloadable", :offline_downloadable do |translation|
      status_tag translation.offline_downloadable? ? "yes" : "no",
        class: translation.offline_downloadable? ? "green" : nil
    end
    column "Package" do |translation|
      package = translation.offline_packages.find { |p| p.schema_version == OfflinePackages::Builder::SCHEMA_VERSION }
      if package
        link_to number_to_human_size(package.size_bytes), package.url
      else
        "—"
      end
    end
    column "Exported at" do |translation|
      translation.offline_packages.map(&:updated_at).max
    end
    actions defaults: false do |translation|
      if translation.offline_downloadable?
        link_to "Generate", generate_admin_offline_package_path(translation), method: :put, class: "member_link"
      end
    end
  end

  show title: :identifier do
    attributes_table do
      row :identifier
      row :name
      row :language
      row :language_name
      row :note
      row :offline_downloadable do |translation|
        status_tag translation.offline_downloadable? ? "yes" : "no"
      end
      row("Verses") { |translation| translation.verses.count }
    end

    panel "Published packages" do
      if resource.offline_packages.any?
        table_for resource.offline_packages.order(:schema_version) do
          column :schema_version
          column("Download") { |package| link_to number_to_human_size(package.size_bytes), package.url }
          column("Uncompressed") { |package| number_to_human_size(package.uncompressed_size_bytes) }
          column :verse_count
          column :sha256
          column :updated_at
        end
      else
        para "No package has been exported yet."
      end
    end

    panel "Actions" do
      unless OfflinePackages.configured?
        para "Offline storage is not configured (#{OfflinePackages::CONFIG_ENV.values.join(', ')})."
      end

      if resource.offline_downloadable?
        para do
          link_to "Generate offline package", generate_admin_offline_package_path(resource),
            method: :put, class: "button",
            data: { confirm: "Build and upload a new offline package for #{resource.identifier}?" }
        end
        para do
          link_to "Mark as not downloadable", toggle_downloadable_admin_offline_package_path(resource),
            method: :put, class: "button",
            data: { confirm: "Stop offering #{resource.identifier} for offline download? Existing packages stay published." }
        end
      else
        para "Only mark this translation downloadable if its license allows redistribution. API access is not redistribution rights."
        para do
          link_to "Mark as offline-downloadable", toggle_downloadable_admin_offline_package_path(resource),
            method: :put, class: "button",
            data: { confirm: "Confirm that #{resource.identifier} (#{resource.note.presence || 'no license note'}) may be redistributed." }
        end
      end
    end
  end

  member_action :generate, method: :put do
    if !resource.offline_downloadable?
      redirect_back_or_to admin_offline_package_path(resource), alert: "#{resource.identifier} is not flagged offline-downloadable."
    elsif !OfflinePackages.configured?
      redirect_back_or_to admin_offline_package_path(resource), alert: "Offline storage is not configured."
    else
      ExportOfflinePackageJob.perform_later(resource.id, force: true)
      redirect_back_or_to admin_offline_package_path(resource),
        notice: "Export of #{resource.identifier} enqueued. Refresh in a minute to see the package."
    end
  end

  member_action :toggle_downloadable, method: :put do
    resource.update!(offline_downloadable: !resource.offline_downloadable?)
    redirect_to admin_offline_package_path(resource),
      notice: "#{resource.identifier} is #{resource.offline_downloadable? ? 'now' : 'no longer'} offline-downloadable."
  end

  controller do
    def scoped_collection
      super.includes(:offline_packages)
    end
  end
end
