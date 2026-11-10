# The availability zones and workspace node sizes, chosen the way saturn-aws's
# aws_config.py chooses them.

locals {
  # _build_availability_zones: intersect the zones that offer each of these
  # types in turn. A type no zone offers is skipped, and the search stops
  # before an intersection would be empty. A single zone is padded with the
  # region's first zone (the next one, if it is the same zone), and no zone at
  # all falls back to the region's first two zones.
  # Python's set order is arbitrary, so the zones are sorted here.
  zone_pick_types = ["p3.2xlarge", "g5.xlarge", "x1e.16xlarge"]
  zones_by_type = { for t in local.zone_pick_types : t => toset([
    for i, it in data.aws_ec2_instance_type_offerings.zone_pick.instance_types :
    data.aws_ec2_instance_type_offerings.zone_pick.locations[i] if it == t
  ]) }

  zone_pick_1       = local.zones_by_type["p3.2xlarge"]
  zone_pick_1_and_2 = setintersection(local.zone_pick_1, local.zones_by_type["g5.xlarge"])
  zone_pick_stopped = length(local.zone_pick_1) > 0 && length(local.zone_pick_1_and_2) == 0
  zone_pick_2 = (
    length(local.zone_pick_1) == 0 ? local.zones_by_type["g5.xlarge"] :
    local.zone_pick_stopped ? local.zone_pick_1 :
    local.zone_pick_1_and_2
  )
  zone_pick_2_and_3 = setintersection(local.zone_pick_2, local.zones_by_type["x1e.16xlarge"])
  zone_pick_3 = (
    local.zone_pick_stopped ? local.zone_pick_2 :
    length(local.zone_pick_2) == 0 ? local.zones_by_type["x1e.16xlarge"] :
    length(local.zone_pick_2_and_3) == 0 ? local.zone_pick_2 :
    local.zone_pick_2_and_3
  )

  region_zones = sort(data.aws_availability_zones.available.names)
  saturn_aws_azs = (
    length(local.zone_pick_3) == 0 ? slice(local.region_zones, 0, 2) :
    slice(distinct(concat(sort(local.zone_pick_3), local.region_zones)), 0, 2)
  )

  # asg_config, _build_spot_instance_types and instance_config: a size whose
  # instance type the worker zone does not offer is left out, and so is each
  # spot type the zone does not offer.
  size_defaults = {
    gpu               = 0
    accelerator       = ""
    min_size          = 0
    max_size          = 100
    desired_capacity  = 0
    max_pods          = 12
    reserved_memory   = "512Mi"
    enable_monitoring = false
  }
  requested_sizes = (var.instance_sizes != null ? var.instance_sizes :
  [for s in local.saturn_aws_instance_sizes : merge(local.size_defaults, s)])

  worker_zone_types = toset(data.aws_ec2_instance_type_offerings.worker_zone.instance_types)
  instance_sizes = [
    for s in local.requested_sizes : merge(s, {
      spot_instance_types = [for t in s.spot_instance_types : t if contains(local.worker_zone_types, t)]
    }) if contains(local.worker_zone_types, s.instance_type)
  ]

  # When the chosen default was left out, saturn-aws offers the first CPU or
  # GPU size that remains instead.
  instance_size_names = [for s in local.instance_sizes : s.name]
  default_cpu_size = (contains(local.instance_size_names, var.default_cpu_size) ? var.default_cpu_size :
  try([for s in local.instance_sizes : s.name if s.gpu == 0][0], ""))
  default_gpu_size = (contains(local.instance_size_names, var.default_gpu_size) ? var.default_gpu_size :
  try([for s in local.instance_sizes : s.name if s.gpu > 0][0], ""))
}

data "aws_ec2_instance_type_offerings" "zone_pick" {
  location_type = "availability-zone"
  filter {
    name   = "instance-type"
    values = local.zone_pick_types
  }
}

data "aws_ec2_instance_type_offerings" "worker_zone" {
  location_type = "availability-zone"
  filter {
    name   = "location"
    values = [local.worker_zone]
  }
}
