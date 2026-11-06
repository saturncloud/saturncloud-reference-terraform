variable domain {
  type = string
  description = "Domain of the certificate. May contain wildcards."
}

variable tags {
  type = map
  default = {}
  description = "Tags to add to every resource"
}
