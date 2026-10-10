# North American phone numbers in E.164 form (+1XXXXXXXXXX), so the same phone
# always compares equal however it was typed.
module PhoneNumber
  # Returns nil when the value is not a full 10-digit number.
  def self.normalize(value)
    digits = value.to_s.gsub(/\D/, "")
    digits = "1#{digits}" if digits.length == 10

    "+#{digits}" if digits.length == 11 && digits.start_with?("1")
  end
end
