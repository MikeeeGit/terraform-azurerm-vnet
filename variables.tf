variable "resource_group_name" {
  description = "Existing resource group for the VNet, DNS zones and diagnostics."
  type        = string
  nullable    = false
  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must not be empty."
  }
}

variable "label" {
  description = "Naming prefix. The VNet name is <label>-<vnet_suffix>."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}[A-Za-z0-9_]$", "${var.label}-${var.vnet_suffix}"))
    error_message = "The composed VNet name must be 2-64 Azure-compatible characters, start with an alphanumeric and end with an alphanumeric or underscore."
  }
}

variable "location" {
  description = "Azure region for the virtual network."
  type        = string
  nullable    = false
  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "vnet_ip_range" {
  description = "Distinct IPv4 or IPv6 CIDR ranges for the virtual network. Address planning and overlap checks remain the caller's responsibility."
  type        = list(string)
  nullable    = false
  validation {
    condition     = length(var.vnet_ip_range) > 0 && length(distinct(var.vnet_ip_range)) == length(var.vnet_ip_range) && alltrue([for cidr in var.vnet_ip_range : can(cidrhost(cidr, 0))])
    error_message = "vnet_ip_range must contain at least one valid CIDR and no duplicates."
  }
}

variable "tags" {
  description = "Resource tags; the original module's generated Name tag is retained on the VNet and DNS zones."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "dns_servers" {
  description = "Custom DNS server IPs. Empty uses Azure-provided DNS; do not also manage these with virtual_network_dns_servers."
  type        = list(string)
  default     = []
  nullable    = false
  validation {
    condition     = alltrue([for ip in var.dns_servers : can(cidrhost("${ip}/32", 0)) || can(cidrhost("${ip}/128", 0))])
    error_message = "dns_servers must contain IP addresses without CIDR suffixes."
  }
}

variable "vnet_suffix" {
  description = "Suffix appended to label. The original leaf default is vnet01; the wrapper/root explicitly choose their suffix."
  type        = string
  default     = "vnet01"
  nullable    = false
}

variable "ddos_plan_id" {
  description = "Existing Azure DDoS Protection Plan resource ID; an empty string omits the association."
  type        = string
  default     = ""
  nullable    = false
  validation {
    condition     = var.ddos_plan_id == "" || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/ddosProtectionPlans/[^/]+$", var.ddos_plan_id))
    error_message = "ddos_plan_id must be empty or a DDoS Protection Plan resource ID."
  }
}

variable "diag_log_workspace" {
  description = "Existing Log Analytics workspace ID for VMProtectionAlerts and AllMetrics. Null disables diagnostics; null/non-null must be known during planning."
  type        = string
  default     = null
  validation {
    condition     = var.diag_log_workspace == null ? true : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.diag_log_workspace))
    error_message = "diag_log_workspace must be null or a Log Analytics workspace resource ID. Empty strings are not workspace IDs."
  }
}

variable "dns_zone_name" {
  description = "Optional legacy selector for a zone in private_dns. That zone receives the named <label>-dns-zone-private link instead of a second duplicate link."
  type        = string
  default     = ""
  nullable    = false
  validation {
    condition     = var.dns_zone_name == "" || contains([for zone in var.private_dns : zone.zone_name], var.dns_zone_name)
    error_message = "dns_zone_name must be empty or exactly match a zone_name in private_dns."
  }
}

variable "dns" {
  description = "Public DNS zones and records. A and CNAME records are keyed by zone and record name; MX records are at the zone apex. TTL is 300 seconds."
  type = list(object({
    zone_name = string
    a_records = optional(list(object({
      name = string
      ip   = string
    })), [])
    cname_records = optional(list(object({
      name   = string
      target = string
    })), [])
    mx_records = optional(list(object({
      preference = number
      exchange   = string
    })), [])
  }))
  default  = []
  nullable = false

  validation {
    condition = length(distinct([for zone in var.dns : lower(zone.zone_name)])) == length(var.dns) && alltrue([
      for zone in var.dns : try(
        length(zone.zone_name) <= 253 && length(split(".", zone.zone_name)) >= 2 &&
        alltrue([for label in split(".", zone.zone_name) : can(regex("^[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?$", label))]),
      false)
    ])
    error_message = "dns zones must have unique domain names with at least two valid labels."
  }
  validation {
    condition = alltrue(flatten([
      for zone in var.dns : concat(
        [for record in zone.a_records : try(length(trimspace(record.name)) > 0 && can(cidrnetmask("${record.ip}/32")), false)],
        [for record in zone.cname_records : try(length(trimspace(record.name)) > 0 && length(trimspace(record.target)) > 0, false)],
        [for record in zone.mx_records : try(record.preference >= 0 && record.preference <= 65535 && floor(record.preference) == record.preference && length(trimspace(record.exchange)) > 0, false)]
      )
    ]))
    error_message = "dns records need nonempty names/targets, IPv4 A addresses, and integer MX preferences from 0 to 65535."
  }
  validation {
    condition = alltrue([
      for zone in var.dns :
      length(distinct([for record in zone.a_records : lower(record.name)])) == length(zone.a_records) &&
      length(distinct([for record in zone.cname_records : lower(record.name)])) == length(zone.cname_records) &&
      length(setintersection(toset([for record in zone.a_records : lower(record.name)]), toset([for record in zone.cname_records : lower(record.name)]))) == 0
    ])
    error_message = "dns must not repeat an A/CNAME name or assign both an A and CNAME record to the same name."
  }
}

variable "private_dns" {
  description = "Private DNS zones and records. A and CNAME records are keyed by zone and record name; MX records are at the zone apex. TTL is 300 seconds."
  type = list(object({
    zone_name = string
    a_records = optional(list(object({
      name = string
      ip   = string
    })), [])
    cname_records = optional(list(object({
      name   = string
      target = string
    })), [])
    mx_records = optional(list(object({
      preference = number
      exchange   = string
    })), [])
  }))
  default  = []
  nullable = false

  validation {
    condition = length(distinct([for zone in var.private_dns : lower(zone.zone_name)])) == length(var.private_dns) && alltrue([
      for zone in var.private_dns : try(
        length(zone.zone_name) <= 253 && length(split(".", zone.zone_name)) >= 2 &&
        alltrue([for label in split(".", zone.zone_name) : can(regex("^[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?$", label))]),
      false)
    ])
    error_message = "private_dns zones must have unique domain names with at least two valid labels."
  }
  validation {
    condition = alltrue(flatten([
      for zone in var.private_dns : concat(
        [for record in zone.a_records : try(length(trimspace(record.name)) > 0 && can(cidrnetmask("${record.ip}/32")), false)],
        [for record in zone.cname_records : try(length(trimspace(record.name)) > 0 && length(trimspace(record.target)) > 0, false)],
        [for record in zone.mx_records : try(record.preference >= 0 && record.preference <= 65535 && floor(record.preference) == record.preference && length(trimspace(record.exchange)) > 0, false)]
      )
    ]))
    error_message = "private_dns records need nonempty names/targets, IPv4 A addresses, and integer MX preferences from 0 to 65535."
  }
  validation {
    condition = alltrue([
      for zone in var.private_dns :
      length(distinct([for record in zone.a_records : lower(record.name)])) == length(zone.a_records) &&
      length(distinct([for record in zone.cname_records : lower(record.name)])) == length(zone.cname_records) &&
      length(setintersection(toset([for record in zone.a_records : lower(record.name)]), toset([for record in zone.cname_records : lower(record.name)]))) == 0
    ])
    error_message = "private_dns must not repeat an A/CNAME name or assign both an A and CNAME record to the same name."
  }
}
