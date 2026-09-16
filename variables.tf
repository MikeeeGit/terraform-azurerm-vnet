variable "name" {
  description = "Virtual network name. Supply the complete name; this module does not add a prefix or suffix."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}[a-zA-Z0-9_]$", var.name))
    error_message = "name must be 2-64 characters, start with an alphanumeric character, contain only alphanumeric characters, underscores, periods or hyphens, and end with an alphanumeric character or underscore."
  }
}

variable "resource_group_name" {
  description = "Name of the existing resource group in which to create the virtual network."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must not be empty or whitespace."
  }
}

variable "location" {
  description = "Azure region for the virtual network."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty or whitespace."
  }
}

variable "address_space" {
  description = "Nonempty list of distinct IPv4 or IPv6 CIDR address ranges. The caller is responsible for address planning and avoiding overlapping ranges."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.address_space) > 0 &&
      length(distinct(var.address_space)) == length(var.address_space) &&
      alltrue([for cidr in var.address_space : can(cidrhost(cidr, 0))])
    )
    error_message = "address_space must contain at least one valid CIDR range and must not contain duplicate ranges."
  }
}

variable "dns_servers" {
  description = "Custom DNS server IP addresses. An empty list uses Azure-provided DNS. Do not manage these addresses with a separate virtual_network_dns_servers resource."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for server in var.dns_servers : can(cidrhost("${server}/32", 0)) || can(cidrhost("${server}/128", 0))
    ])
    error_message = "dns_servers must contain IP addresses, without CIDR prefix lengths."
  }
}

variable "tags" {
  description = "Tags applied to the virtual network without adding or overwriting caller-supplied keys."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "ddos_protection_plan_id" {
  description = "Resource ID of an existing Azure DDoS Protection Plan to enable on this network. Null omits the association."
  type        = string
  default     = null

  validation {
    condition = var.ddos_protection_plan_id == null ? true : can(regex(
      "(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+/providers/Microsoft\\.Network/ddosProtectionPlans/[^/]+$",
      var.ddos_protection_plan_id
    ))
    error_message = "ddos_protection_plan_id must be null or a complete Azure DDoS Protection Plan resource ID."
  }
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of an existing Log Analytics workspace for VMProtectionAlerts diagnostics. Null creates no diagnostic setting. Its null/non-null value must be known during planning."
  type        = string
  default     = null

  validation {
    condition = var.log_analytics_workspace_id == null ? true : can(regex(
      "(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$",
      var.log_analytics_workspace_id
    ))
    error_message = "log_analytics_workspace_id must be null or a complete Azure Log Analytics workspace resource ID."
  }
}
