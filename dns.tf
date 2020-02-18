variable "dns" {
  default = "aa.dekker-and.digital"
}

resource "aws_route53_zone" "main" {
  name = var.dns
}

output "main_name_servers" {
  value = aws_route53_zone.main.name_servers
}

resource "aws_route53_record" "main-txt" {
  zone_id = aws_route53_zone.main.id
  name = var.dns
  type = "TXT"
  records = [
    "test=abc", # more text records can be added below
  ]
  ttl = 900
}

resource "aws_route53_record" "alex-zone" {
  name = join(".", ["alex", var.dns])
  zone_id = aws_route53_zone.main.id
  type = "NS"
  ttl = 900
  records = [
    "ns-1205.awsdns-22.org",
    "ns-156.awsdns-19.com",
    "ns-2027.awsdns-61.co.uk",
    "ns-711.awsdns-24.net",
  ]
}

resource "aws_route53_record" "alex-zone" {
  name = "sarang.${var.dns}"
  zone_id = aws_route53_zone.main.id
  type = "NS"
  ttl = 900
  records = [
    "ns-1126.awsdns-12.org",
    "ns-1858.awsdns-40.co.uk",
    "ns-477.awsdns-59.com",
    "ns-808.awsdns-37.net",
  ]
}

