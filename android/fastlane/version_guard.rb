module AlphaVersionGuard
  def self.error(version_code, published_version_codes)
    latest_version_code = published_version_codes.max
    return if latest_version_code.nil? || version_code > latest_version_code

    "versionCode #{version_code} must be greater than live Alpha versionCode #{latest_version_code}"
  end
end
