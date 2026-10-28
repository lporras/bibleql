# frozen_string_literal: true

module Types
  class PlatformEnum < Types::BaseEnum
    description "Operating system a client installation runs on"
    value "MACOS", "macOS", value: "macos"
    value "WINDOWS", "Windows", value: "windows"
    value "LINUX", "Linux", value: "linux"
    value "IOS", "iOS / iPadOS", value: "ios"
    value "ANDROID", "Android", value: "android"
  end
end
