require_relative "version_guard"

def assert_equal(expected, actual)
  return if expected == actual

  raise "Expected #{expected.inspect}, got #{actual.inspect}"
end

assert_equal(nil, AlphaVersionGuard.error(6, []))
assert_equal(nil, AlphaVersionGuard.error(6, [4, 5]))
assert_equal(
  "versionCode 6 must be greater than live Alpha versionCode 7",
  AlphaVersionGuard.error(6, [5, 7])
)
assert_equal(
  "versionCode 6 must be greater than live Alpha versionCode 6",
  AlphaVersionGuard.error(6, [5, 6])
)

puts "Alpha version guard tests passed."
