require "test_helper"

class PhoneNumberTest < ActiveSupport::TestCase
  test "normalises the common ways of writing a number to one form" do
    [ "2025550101", "(202) 555-0101", "202.555.0101", "1-202-555-0101", "+1 202 555 0101" ].each do |written|
      assert_equal "+12025550101", PhoneNumber.normalize(written), written
    end
  end

  test "returns nil for anything that is not a full number" do
    [ nil, "", "555-0101", "abc", "442079460000", "20255501011" ].each do |written|
      assert_nil PhoneNumber.normalize(written), written.inspect
    end
  end
end
