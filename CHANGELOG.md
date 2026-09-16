# Changelog

## 0.2.0

- Restore the original `AZ-TF-MOD-vnet` input names, resource addresses, complete `vnet` output, naming and generated tags.
- Restore public/private A, CNAME and apex MX records, private-zone links, custom DNS, DDoS association and both diagnostic categories.
- Remove the estate-specific diagnostic workspace default. Diagnostics now require an explicit workspace ID, with a moved block for the optional resource address.
- Fix the private-zone selector's incorrect map lookup and duplicate-link behavior.
- Require Terraform >=1.9 and AzureRM >=4.33,<5; use supported `enabled_metric` syntax.
- Add input validation, synthetic runnable examples, migration guidance and credential-free regression tests.

## 0.1.0

Initial public scaffold. Its narrowed VNet-only interface is superseded by the reviewed compatibility-focused v0.2.0 design.
