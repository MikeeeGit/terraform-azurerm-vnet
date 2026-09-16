# The original module always created this setting. Preserve its address when
# callers explicitly retain their existing workspace while upgrading.
moved {
  from = azurerm_monitor_diagnostic_setting.vnet
  to   = azurerm_monitor_diagnostic_setting.vnet[0]
}
