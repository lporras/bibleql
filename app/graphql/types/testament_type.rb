# frozen_string_literal: true

module Types
  class TestamentType < Types::BaseEnum
    description "Which half of the canon: Old or New Testament"
    value "OLD", "Old Testament (Genesis–Malachi)", value: "OT"
    value "NEW", "New Testament (Matthew–Revelation)", value: "NT"
  end
end
