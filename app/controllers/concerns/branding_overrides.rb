module BrandingOverrides
  private

  def apply_branding_overrides(config, host)
    BrandingConfigResolver.apply(config, host)
  end
end
