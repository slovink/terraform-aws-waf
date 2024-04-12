<<p align="center"> <img src="https://user-images.githubusercontent.com/50652676/62349836-882fef80-b51e-11e9-99e3-7b974309c7e3.png" width="100" height="100"></p>


<h1 align="center">
    Terraform AWS Waf
</h1>


<p align="center">

<a href="https://www.terraform.io">
  <img src="https://img.shields.io/badge/Terraform-v1.7.0-green" alt="Terraform">
</a>
<a href="https://github.com/slovink/terraform-aws-waf/blob/dev/LICENSE">
  <img src="https://img.shields.io/badge/License-APACHE-blue.svg" alt="Licence">
</a>



</p>
<p align="center">

<a href='https://www.facebook.com/Slovink.in=https://github.com/slovink/terraform-aws-waf'>
  <img title="Share on Facebook" src="https://user-images.githubusercontent.com/50652676/62817743-4f64cb80-bb59-11e9-90c7-b057252ded50.png" />
</a>
<a href='https://www.linkedin.com/company/101534993/admin/feed/posts/=https://github.com/slovink/terraform-aws-waf'>
  <img title="Share on LinkedIn" src="https://user-images.githubusercontent.com/50652676/62817742-4e339e80-bb59-11e9-87b9-a1f68cae1049.png" />
</a>



- [Introduction](#introduction)
- [Usage](#usage)
- [Module Inputs](#module-inputs)
- [Module Outputs](#module-outputs)
- [Examples](#examples)
- [License](#license)



## Prerequisites

This module has a few dependencies:

- [Terraform 1.x.x](https://learn.hashicorp.com/terraform/getting-started/install.html)
- [Go](https://golang.org/doc/install)



## Examples
For detailed examples on how to use this module, please refer to the [Examples](https://github.com/slovink/terraform-aws-waf/tree/master/example) directory within this repository.

## License
This Terraform module is provided under the '[License Name]' License. Please see the [LICENSE](https://github.com/slovink/terraform-aws-waf/blob/master/LICENSE) file for more details.




## Examples


**IMPORTANT:** Since the `master` branch used in `source` varies based on new modifications, we suggest that you use the release versions [here](https://github.com/slovink/terraform-aws-waf/releases).


### Simple Example
Here is an example of how you can use this module in your inventory structure:
  ```hcl
module "waf" {
  source               = "https://github.com/slovink/terraform-aws-waf.git?ref=v1.0.0"
  name                 = "waf"
  environment          = "test"
  allow_default_action = true
  waf_enabled          = true
  waf_scop             = "REGIONAL"

  web_acl_association = true
  resource_arn_list   = ["arn:aws:elasticloadbalancing:eu-west-1:xxxxxxx:loadbalancer/app/alb-test/xxxxxxxxx"]

  visibility_config = {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
  }

  rules = [

    {
      name     = "rate-limit"
      priority = "1"
      action   = "block"

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "rate-limit"
        sampled_requests_enabled   = true
      }

      rate_based_statement = {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    },
    {
      name     = "allow-ip-set"
      priority = "0"
      action   = "allow"

      ip_set_reference_statement = {
        arn = module.ip_set.ip_set_arn
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "test-waf-setup-waf-ip-set-block-metrics"
        sampled_requests_enabled   = true
      }
    }
  ]


  #logs

  create_logging_configuration = false
  redacted_fields              = [
    {
      single_header = {
        name = "user-agent"
      }
    }
  ]
}
  ```



## Feedback
If you come accross a bug or have any feedback, please log it in our [issue tracker](https://github.com/slovink/terraform-aws-waf/issues), or feel free to drop us an email at [contact@slovink.com](mailto:contact@slovink.com).

If you have found it worth your time, go ahead and give us a ★ on [our GitHub](https://github.com/slovink/terraform-aws-waf)!