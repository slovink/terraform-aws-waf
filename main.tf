#Module      : Label
#Description : This terraform module is designed to generate consistent label names and tags
#              for resources. You can use terraform-labels to implement a strict naming
#              convention.
module "labels" {
  source = "git::git@github.com:slovink/terraform-aws-labels.git?ref=v1.0.0"

  name        = var.name
  environment = var.environment
  managedby   = var.managedby
  label_order = var.label_order
  repository  = var.repository
}

#Module      : WAF
#Description : Provides a WAFv2 IP Set Resource.
resource "aws_wafv2_ip_set" "main" {
  count = var.ip_addresses != null ? 1 : 0

  name               = format("ip-%s", module.labels.id)
  scope              = var.waf_scop
  ip_address_version = "IPV4"
  addresses          = var.ip_addresses
  tags               = module.labels.tags
}

#Module      : WAF
#Description : Terraform module to create WAF resource on AWS.
resource "aws_wafv2_web_acl" "main" {
  count       = var.waf_enabled ? 1 : 0
  name        = module.labels.id
  description = "WAFv2 ACL for ${module.labels.id}"
  scope       = var.waf_scop

  default_action {
    dynamic "allow" {
      for_each = var.allow_default_action ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.allow_default_action ? [] : [1]
      content {}
    }
  }
  dynamic "rule" {
    for_each = var.rules
    content {
      name     = lookup(rule.value, "name")
      priority = lookup(rule.value, "priority")

      # Action block is required for geo_match, ip_set, and ip_rate_based rules
      dynamic "action" {
        for_each = length(lookup(rule.value, "action", {})) == 0 ? [] : [1]
        content {
          dynamic "allow" {
            for_each = lookup(rule.value, "action", {}) == "allow" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = lookup(rule.value, "action", {}) == "count" ? [1] : []
            content {}
          }

          dynamic "block" {
            for_each = lookup(rule.value, "action", {}) == "block" ? [1] : []
            content {}
          }
        }
      }

      # Required for managed_rule_group_statements. Set to none, otherwise count to override the default action
      dynamic "override_action" {
        for_each = length(lookup(rule.value, "override_action", {})) == 0 ? [] : [1]
        content {
          dynamic "none" {
            for_each = lookup(rule.value, "override_action", {}) == "none" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = lookup(rule.value, "override_action", {}) == "count" ? [1] : []
            content {}
          }
        }
      }

      statement {

        dynamic "managed_rule_group_statement" {
          for_each = length(lookup(rule.value, "managed_rule_group_statement", {})) == 0 ? [] : [lookup(rule.value, "managed_rule_group_statement", {})]
          content {
            name        = lookup(managed_rule_group_statement.value, "name")
            vendor_name = lookup(managed_rule_group_statement.value, "vendor_name", "AWS")

            dynamic "excluded_rule" {
              for_each = length(lookup(managed_rule_group_statement.value, "excluded_rule", {})) == 0 ? [] : toset(lookup(managed_rule_group_statement.value, "excluded_rule"))
              content {
                name = excluded_rule.value
              }
            }

            dynamic "scope_down_statement" {
              for_each = length(lookup(managed_rule_group_statement.value, "scope_down_statement", {})) == 0 ? [] : [lookup(managed_rule_group_statement.value, "scope_down_statement", {})]
              content {
                # scope down byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # scope down geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                  }
                }

                # scope down NOT statements
                dynamic "not_statement" {
                  for_each = length(lookup(scope_down_statement.value, "not_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "not_statement", {})]
                  content {
                    statement {
                      # scope down NOT byte_match_statement
                      dynamic "byte_match_statement" {
                        for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                          search_string         = lookup(byte_match_statement.value, "search_string")
                          text_transformation {
                            priority = lookup(byte_match_statement.value, "priority")
                            type     = lookup(byte_match_statement.value, "type")
                          }
                        }
                      }

                      # scope down NOT geo_match_statement
                      dynamic "geo_match_statement" {
                        for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                        content {
                          country_codes = lookup(geo_match_statement.value, "country_codes")
                        }
                      }
                    }
                  }
                }

                ### scope down AND statements (Requires at least two statements)
                dynamic "and_statement" {
                  for_each = length(lookup(scope_down_statement.value, "and_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "and_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(and_statement.value, "statements", {})
                      content {
                        # Scope down AND byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down AND geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                          }
                        }

                        # Scope down AND ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                          }
                        }
                      }
                    }
                  }
                }


                ### scope down OR statements (Requires at least two statements)
                dynamic "or_statement" {
                  for_each = length(lookup(scope_down_statement.value, "or_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "or_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(or_statement.value, "statements", {})
                      content {
                        # Scope down OR byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down OR geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                          }
                        }

                        # Scope down OR ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        dynamic "byte_match_statement" {
          for_each = length(lookup(rule.value, "byte_match_statement", {})) == 0 ? [] : [lookup(rule.value, "byte_match_statement", {})]
          content {
            dynamic "field_to_match" {
              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
              content {
                dynamic "uri_path" {
                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                  content {}
                }
                dynamic "all_query_arguments" {
                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                  content {}
                }
                dynamic "body" {
                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                  content {}
                }
                dynamic "method" {
                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                  content {}
                }
                dynamic "query_string" {
                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                  content {}
                }
                dynamic "single_header" {
                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                  content {
                    name = lower(lookup(single_header.value, "name"))
                  }
                }
              }
            }
            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
            search_string         = lookup(byte_match_statement.value, "search_string")
            text_transformation {
              priority = lookup(byte_match_statement.value, "priority")
              type     = lookup(byte_match_statement.value, "type")
            }
          }
        }

        dynamic "geo_match_statement" {
          for_each = length(lookup(rule.value, "geo_match_statement", {})) == 0 ? [] : [lookup(rule.value, "geo_match_statement", {})]
          content {
            country_codes = lookup(geo_match_statement.value, "country_codes")
          }
        }

        dynamic "ip_set_reference_statement" {
          for_each = length(lookup(rule.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(rule.value, "ip_set_reference_statement", {})]
          content {
            arn = lookup(ip_set_reference_statement.value, "arn")
          }
        }

        dynamic "size_constraint_statement" {
          for_each = length(lookup(rule.value, "size_constraint_statement", {})) == 0 ? [] : [lookup(rule.value, "size_constraint_statement", {})]
          content {
            dynamic "field_to_match" {
              for_each = length(lookup(size_constraint_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(size_constraint_statement.value, "field_to_match", {})]
              content {
                dynamic "uri_path" {
                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                  content {}
                }
                dynamic "all_query_arguments" {
                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                  content {}
                }
                dynamic "body" {
                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                  content {}
                }
                dynamic "method" {
                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                  content {}
                }
                dynamic "query_string" {
                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                  content {}
                }
                dynamic "single_header" {
                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                  content {
                    name = lower(lookup(single_header.value, "name"))
                  }
                }
              }
            }
            comparison_operator = lookup(size_constraint_statement.value, "comparison_operator")
            size                = lookup(size_constraint_statement.value, "size")
            text_transformation {
              priority = lookup(size_constraint_statement.value, "priority")
              type     = lookup(size_constraint_statement.value, "type")
            }
          }
        }

        dynamic "rate_based_statement" {
          for_each = length(lookup(rule.value, "rate_based_statement", {})) == 0 ? [] : [lookup(rule.value, "rate_based_statement", {})]
          content {
            limit              = lookup(rate_based_statement.value, "limit")
            aggregate_key_type = lookup(rate_based_statement.value, "aggregate_key_type", "IP")

            dynamic "forwarded_ip_config" {
              for_each = length(lookup(rule.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(rule.value, "forwarded_ip_config", {})]
              content {
                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                header_name       = lookup(forwarded_ip_config.value, "header_name")
              }
            }

            dynamic "scope_down_statement" {
              for_each = length(lookup(rate_based_statement.value, "scope_down_statement", {})) == 0 ? [] : [lookup(rate_based_statement.value, "scope_down_statement", {})]
              content {
                # scope down byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # scope down geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(scope_down_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                  }
                }

                # scope down NOT statements
                dynamic "not_statement" {
                  for_each = length(lookup(scope_down_statement.value, "not_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "not_statement", {})]
                  content {
                    statement {
                      # scope down NOT byte_match_statement
                      dynamic "byte_match_statement" {
                        for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                        content {
                          dynamic "field_to_match" {
                            for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                            content {
                              dynamic "uri_path" {
                                for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                content {}
                              }
                              dynamic "all_query_arguments" {
                                for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                content {}
                              }
                              dynamic "body" {
                                for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                content {}
                              }
                              dynamic "method" {
                                for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                content {}
                              }
                              dynamic "single_header" {
                                for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                content {
                                  name = lower(lookup(single_header.value, "name"))
                                }
                              }
                            }
                          }
                          positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                          search_string         = lookup(byte_match_statement.value, "search_string")
                          text_transformation {
                            priority = lookup(byte_match_statement.value, "priority")
                            type     = lookup(byte_match_statement.value, "type")
                          }
                        }
                      }

                      # scope down NOT geo_match_statement
                      dynamic "geo_match_statement" {
                        for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                        content {
                          country_codes = lookup(geo_match_statement.value, "country_codes")
                        }
                      }
                    }
                  }
                }

                ### scope down AND statements (Requires at least two statements)
                dynamic "and_statement" {
                  for_each = length(lookup(scope_down_statement.value, "and_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "and_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(and_statement.value, "statements", {})
                      content {
                        # Scope down AND byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down AND geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                          }
                        }

                        # Scope down AND ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                          }
                        }
                      }
                    }
                  }
                }


                ### scope down OR statements (Requires at least two statements)
                dynamic "or_statement" {
                  for_each = length(lookup(scope_down_statement.value, "or_statement", {})) == 0 ? [] : [lookup(scope_down_statement.value, "or_statement", {})]
                  content {

                    dynamic "statement" {
                      for_each = lookup(or_statement.value, "statements", {})
                      content {
                        # Scope down OR byte_match_statement
                        dynamic "byte_match_statement" {
                          for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                          content {
                            dynamic "field_to_match" {
                              for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                              content {
                                dynamic "uri_path" {
                                  for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                                  content {}
                                }
                                dynamic "all_query_arguments" {
                                  for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                                  content {}
                                }
                                dynamic "body" {
                                  for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                                  content {}
                                }
                                dynamic "method" {
                                  for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                                  content {}
                                }
                                dynamic "query_string" {
                                  for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                                  content {}
                                }
                                dynamic "single_header" {
                                  for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                                  content {
                                    name = lower(lookup(single_header.value, "name"))
                                  }
                                }
                              }
                            }
                            positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                            search_string         = lookup(byte_match_statement.value, "search_string")
                            text_transformation {
                              priority = lookup(byte_match_statement.value, "priority")
                              type     = lookup(byte_match_statement.value, "type")
                            }
                          }
                        }

                        # Scope down OR geo_match_statement
                        dynamic "geo_match_statement" {
                          for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                          content {
                            country_codes = lookup(geo_match_statement.value, "country_codes")
                          }
                        }

                        # Scope down OR ip_set_statement
                        dynamic "ip_set_reference_statement" {
                          for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                          content {
                            arn = lookup(ip_set_reference_statement.value, "arn")
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        ### NOT STATEMENTS
        dynamic "not_statement" {
          for_each = length(lookup(rule.value, "not_statement", {})) == 0 ? [] : [lookup(rule.value, "not_statement", {})]
          content {
            statement {

              # NOT byte_match_statement
              dynamic "byte_match_statement" {
                for_each = length(lookup(not_statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "byte_match_statement", {})]
                content {
                  dynamic "field_to_match" {
                    for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                    content {
                      dynamic "uri_path" {
                        for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                        content {}
                      }
                      dynamic "all_query_arguments" {
                        for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                        content {}
                      }
                      dynamic "body" {
                        for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                        content {}
                      }
                      dynamic "method" {
                        for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                        content {}
                      }
                      dynamic "query_string" {
                        for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                        content {
                          name = lower(lookup(single_header.value, "name"))
                        }
                      }
                    }
                  }
                  positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                  search_string         = lookup(byte_match_statement.value, "search_string")
                  text_transformation {
                    priority = lookup(byte_match_statement.value, "priority")
                    type     = lookup(byte_match_statement.value, "type")
                  }
                }
              }

              # NOT geo_match_statement
              dynamic "geo_match_statement" {
                for_each = length(lookup(not_statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(not_statement.value, "geo_match_statement", {})]
                content {
                  country_codes = lookup(geo_match_statement.value, "country_codes")
                }
              }

              # NOT ip_set_statement
              dynamic "ip_set_reference_statement" {
                for_each = length(lookup(not_statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(not_statement.value, "ip_set_reference_statement", {})]
                content {
                  arn = lookup(ip_set_reference_statement.value, "arn")
                }
              }
            }
          }
        }

        ### AND STATEMENTS (Requires at least two statements)
        dynamic "and_statement" {
          for_each = length(lookup(rule.value, "and_statement", {})) == 0 ? [] : [lookup(rule.value, "and_statement", {})]
          content {

            dynamic "statement" {
              for_each = lookup(and_statement.value, "statements", {})
              content {

                # AND byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # AND geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                  }
                }

                # AND ip_set_statement
                dynamic "ip_set_reference_statement" {
                  for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                  content {
                    arn = lookup(ip_set_reference_statement.value, "arn")
                  }
                }
              }
            }
          }
        }

        ### OR STATEMENTS (Requires at least two statements)
        dynamic "or_statement" {
          for_each = length(lookup(rule.value, "or_statement", {})) == 0 ? [] : [lookup(rule.value, "or_statement", {})]
          content {

            dynamic "statement" {
              for_each = lookup(or_statement.value, "statements", {})
              content {

                # OR byte_match_statement
                dynamic "byte_match_statement" {
                  for_each = length(lookup(statement.value, "byte_match_statement", {})) == 0 ? [] : [lookup(statement.value, "byte_match_statement", {})]
                  content {
                    dynamic "field_to_match" {
                      for_each = length(lookup(byte_match_statement.value, "field_to_match", {})) == 0 ? [] : [lookup(byte_match_statement.value, "field_to_match", {})]
                      content {
                        dynamic "uri_path" {
                          for_each = length(lookup(field_to_match.value, "uri_path", {})) == 0 ? [] : [lookup(field_to_match.value, "uri_path")]
                          content {}
                        }
                        dynamic "all_query_arguments" {
                          for_each = length(lookup(field_to_match.value, "all_query_arguments", {})) == 0 ? [] : [lookup(field_to_match.value, "all_query_arguments")]
                          content {}
                        }
                        dynamic "body" {
                          for_each = length(lookup(field_to_match.value, "body", {})) == 0 ? [] : [lookup(field_to_match.value, "body")]
                          content {}
                        }
                        dynamic "method" {
                          for_each = length(lookup(field_to_match.value, "method", {})) == 0 ? [] : [lookup(field_to_match.value, "method")]
                          content {}
                        }
                        dynamic "query_string" {
                          for_each = length(lookup(field_to_match.value, "query_string", {})) == 0 ? [] : [lookup(field_to_match.value, "query_string")]
                          content {}
                        }
                        dynamic "single_header" {
                          for_each = length(lookup(field_to_match.value, "single_header", {})) == 0 ? [] : [lookup(field_to_match.value, "single_header")]
                          content {
                            name = lower(lookup(single_header.value, "name"))
                          }
                        }
                      }
                    }
                    positional_constraint = lookup(byte_match_statement.value, "positional_constraint")
                    search_string         = lookup(byte_match_statement.value, "search_string")
                    text_transformation {
                      priority = lookup(byte_match_statement.value, "priority")
                      type     = lookup(byte_match_statement.value, "type")
                    }
                  }
                }

                # OR geo_match_statement
                dynamic "geo_match_statement" {
                  for_each = length(lookup(statement.value, "geo_match_statement", {})) == 0 ? [] : [lookup(statement.value, "geo_match_statement", {})]
                  content {
                    country_codes = lookup(geo_match_statement.value, "country_codes")
                  }
                }

                # OR ip_set_statement
                dynamic "ip_set_reference_statement" {
                  for_each = length(lookup(statement.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(statement.value, "ip_set_reference_statement", {})]
                  content {
                    arn = lookup(ip_set_reference_statement.value, "arn")
                  }
                }
              }
            }
          }
        }
      }

      dynamic "visibility_config" {
        for_each = length(lookup(rule.value, "visibility_config")) == 0 ? [] : [lookup(rule.value, "visibility_config", {})]
        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = lookup(visibility_config.value, "metric_name", module.labels.id)
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }
    }
  }

  tags = module.labels.tags

  dynamic "visibility_config" {
    for_each = length(var.visibility_config) == 0 ? [] : [var.visibility_config]
    content {
      cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
      metric_name                = lookup(visibility_config.value, "metric_name", module.labels.id)
      sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
    }
  }
}

#####
# WAFv2 web acl association with ALB
#####
resource "aws_wafv2_web_acl_association" "main" {
  count = var.waf_enabled && var.web_acl_association && length(var.resource_arn_list) == 0 ? 1 : 0

  resource_arn = var.resource_arn
  web_acl_arn  = join("", aws_wafv2_web_acl.main[*].arn)

  depends_on = [aws_wafv2_web_acl.main]
}

resource "aws_wafv2_web_acl_association" "alb_list" {
  count = var.waf_enabled && var.web_acl_association && length(var.resource_arn_list) > 0 ? length(var.resource_arn_list) : 0

  resource_arn = var.resource_arn_list[count.index]
  web_acl_arn  = join("", aws_wafv2_web_acl.main[*].arn)

  depends_on = [aws_wafv2_web_acl.main]
}

#logs
# Get caller identity.
data "aws_caller_identity" "this" {
}
data "aws_region" "this" {}

#
##logs_alb
#
#S3 Bucket to store WebACL Traffic Logs. This resource is needed by Amazon Kinesis Firehose as data delivery output target.
resource "aws_s3_bucket" "webacl_traffic_information" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  bucket = format("%s-waf-logs", module.labels.id)
  tags   = module.labels.tags
}
resource "aws_s3_bucket_acl" "webacl_traffic_information" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  bucket = join("", aws_s3_bucket.webacl_traffic_information[*].id)
  acl    = "private"
}
resource "aws_s3_bucket_versioning" "webacl_traffic_information" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  bucket = join("", aws_s3_bucket.webacl_traffic_information[*].id)
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "webacl_traffic_information" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  bucket = join("", aws_s3_bucket.webacl_traffic_information[*].id)
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# AWS Glue Catalog Database. This resource is needed by Amazon Kinesis Firehose as data format conversion configuration, for transforming from JSON to Parquet.
resource "aws_glue_catalog_database" "database" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  name        = format("glue-%s", module.labels.id)
  description = "Glue Catalog Database for ${lower(module.labels.id)} WAF Logs"
}

# This table store column information that is needed by Amazon Kinesis Firehose as data format conversion configuration, for transforming from JSON to Parquet.
resource "aws_glue_catalog_table" "table" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  name          = format("glue-table-%s", module.labels.id)
  database_name = join("", aws_glue_catalog_database.database[*].name)

  description = "Table which stores schema of WAF Logs for ${lower(module.labels.id)} WebACL"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL       = "TRUE"
    classification = "Parquet"
  }

  partition_keys {
    name = "year"
    type = "int"
  }
  partition_keys {
    name = "month"
    type = "int"
  }
  partition_keys {
    name = "day"
    type = "int"
  }
  partition_keys {
    name = "hour"
    type = "int"
  }

  storage_descriptor {
    location      = "s3://${join("", aws_s3_bucket.webacl_traffic_information[*].id)}/logs"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "timestamp"
      type = "timestamp"
    }
    columns {
      name = "formatversion"
      type = "int"
    }
    columns {
      name = "webaclid"
      type = "string"
    }
    columns {
      name = "terminatingruleid"
      type = "string"
    }
    columns {
      name = "terminatingruletype"
      type = "string"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "httpsourcename"
      type = "string"
    }
    columns {
      name = "httpsourceid"
      type = "string"
    }
    columns {
      name = "rulegrouplist"
      type = "array<struct<ruleGroupId:string,terminatingRule:string,nonTerminatingMatchingRules:array<struct<action:string,ruleId:string>>,excludedRules:array<struct<exclusionType:string,ruleId:string>>>>"
    }
    columns {
      name = "ratebasedrulelist"
      type = "array<struct<rateBasedRuleId:string,limitKey:string,maxRateAllowed:int>>"
    }
    columns {
      name = "nonterminatingmatchingrules"
      type = "array<struct<action:string,ruleId:string>>"
    }
    columns {
      name = "httprequest"
      type = "struct<clientIp:string,country:string,headers:array<struct<name:string,value:string>>,uri:string,args:string,httpVersion:string,httpMethod:string,requestId:string>"
    }
  }
}

# This log group is needed by Amazon Kinesis Firehose for storing delivery error information.
resource "aws_cloudwatch_log_group" "firehose_error_logs" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  name              = "/aws/kinesisfirehose/aws-waf-logs-${lower(module.labels.id)}-WebACL"
  retention_in_days = "30"

  tags = module.labels.tags
}

# This log stream is the one which hold the information inside the log group above.
resource "aws_cloudwatch_log_stream" "firehose_error_logs" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  name           = module.labels.id
  log_group_name = join("", aws_cloudwatch_log_group.firehose_error_logs[*].name)
}

# Policy document that will allow the Firehose to assume an IAM Role.
data "aws_iam_policy_document" "firehose_assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "firehose.amazonaws.com",
      ]
    }
  }
}

# IAM Role for the Firehose, so it able to access those resources above.
resource "aws_iam_role" "firehose" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0


  name        = format("ServiceRoleForFirehose_%s_WebACL", module.labels.id)
  path        = "/service-role/firehose/"
  description = format("Service Role for %s-WebACL Firehose", module.labels.id)

  assume_role_policy    = data.aws_iam_policy_document.firehose_assume_role_policy.json
  force_detach_policies = "false"
  max_session_duration  = "43200"

  tags = module.labels.tags
}

# Policy document that will be attached to the S3 Bucket, to make the bucket accessible by the Firehose.
data "aws_iam_policy_document" "allow_s3_actions" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        join("", aws_iam_role.firehose[*].arn),
      ]
    }

    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]

    resources = [
      join("", aws_s3_bucket.webacl_traffic_information[*].arn),
      "${join("", aws_s3_bucket.webacl_traffic_information[*].arn)}/*",
    ]
  }
}

# Attach the policy above to the bucket.
resource "aws_s3_bucket_policy" "webacl_traffic_information_lb" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  bucket = join("", aws_s3_bucket.webacl_traffic_information[*].id)
  policy = data.aws_iam_policy_document.allow_s3_actions.json
}

# Policy document that will be attached to the IAM Role, to make the role able to put logs to Cloudwatch.
data "aws_iam_policy_document" "allow_put_log_events" {
  statement {
    sid = "AllowWritingToLogStreams"

    actions = [
      "logs:PutLogEvents",
    ]

    effect = "Allow"

    resources = [
      join("", aws_s3_bucket.webacl_traffic_information[*].arn),
    ]
  }
}

# Attach the policy above to the IAM Role.
resource "aws_iam_role_policy" "allow_put_log_events" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  name = "AllowWritingToLogStreams"
  role = join("", aws_iam_role.firehose[*].name)

  policy = data.aws_iam_policy_document.allow_put_log_events.json
}

# Policy document that will be attached to the IAM Role, to make the role able to get Glue Table Versions.
data "aws_iam_policy_document" "allow_glue_get_table_versions" {
  statement {
    sid = "AllowGettingGlueTableVersions"

    actions = [
      "glue:GetTableVersions",
    ]

    effect = "Allow"

    resources = [
      "arn:aws:glue:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:table/${join("", aws_glue_catalog_database.database[*].name)}/logs",
      "arn:aws:glue:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:table/${join("", aws_glue_catalog_database.database[*].name)}/${join("", aws_glue_catalog_table.table[*].name)}",
      "arn:aws:glue:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:database/${join("", aws_glue_catalog_database.database[*].name)}",
      "arn:aws:glue:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:catalog",
    ]
  }
}

# Attach the policy above to the IAM Role.
resource "aws_iam_role_policy" "allow_glue_get_table_versions" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  name = format("AllowGettingGlueTableVersions-%s", module.labels.id)
  role = join("", aws_iam_role.firehose[*].name)

  policy = data.aws_iam_policy_document.allow_glue_get_table_versions.json
}

# Creating the Firehose.
resource "aws_kinesis_firehose_delivery_stream" "waf" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  name        = format("aws-waf-logs-%s", module.labels.id)
  destination = "extended_s3"

  extended_s3_configuration {


    role_arn   = join("", aws_iam_role.firehose[*].arn)
    bucket_arn = join("", aws_s3_bucket.webacl_traffic_information[*].arn)

    buffer_size     = var.firehose_buffer_size
    buffer_interval = var.firehose_buffer_interval

    prefix              = "logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}"

    cloudwatch_logging_options {
      enabled         = "true"
      log_group_name  = join("", aws_cloudwatch_log_group.firehose_error_logs[*].name)
      log_stream_name = join("", aws_cloudwatch_log_stream.firehose_error_logs[*].name)
    }

    data_format_conversion_configuration {
      enabled = "true"

      input_format_configuration {
        deserializer {
          open_x_json_ser_de {
          }
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {
          }
        }
      }

      schema_configuration {
        role_arn      = join("", aws_iam_role.firehose[*].arn)
        database_name = join("", aws_glue_catalog_table.table[*].database_name)
        table_name    = join("", aws_glue_catalog_table.table[*].name)
        region        = data.aws_region.this.name
      }
    }
  }

  tags = module.labels.tags
}


#####
# WAFv2 web acl logging configuration with kinesis firehose
#####
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.waf_enabled && var.create_logging_configuration ? 1 : 0

  log_destination_configs = [join("", aws_kinesis_firehose_delivery_stream.waf[*].arn)]
  resource_arn            = join("", aws_wafv2_web_acl.main[*].arn)

  dynamic "redacted_fields" {
    for_each = var.redacted_fields
    content {
      dynamic "single_header" {
        for_each = length(lookup(redacted_fields.value, "single_header", {})) == 0 ? [] : [lookup(redacted_fields.value, "single_header", {})]
        content {
          name = lookup(single_header.value, "name", null)
        }
      }

      dynamic "single_query_argument" {
        for_each = length(lookup(redacted_fields.value, "single_query_argument", {})) == 0 ? [] : [lookup(redacted_fields.value, "single_query_argument", {})]
        content {
          name = lookup(single_query_argument.value, "name", null)
        }
      }
    }
  }

  dynamic "logging_filter" {
    for_each = length(var.logging_filter) == 0 ? [] : [var.logging_filter]
    content {
      default_behavior = lookup(logging_filter.value, "default_behavior", "KEEP")

      dynamic "filter" {
        for_each = length(lookup(logging_filter.value, "filter", {})) == 0 ? [] : toset(lookup(logging_filter.value, "filter"))
        content {
          behavior    = lookup(filter.value, "behavior")
          requirement = lookup(filter.value, "requirement", "MEETS_ANY")

          dynamic "condition" {
            for_each = length(lookup(filter.value, "condition", {})) == 0 ? [] : toset(lookup(filter.value, "condition"))
            content {
              dynamic "action_condition" {
                for_each = length(lookup(condition.value, "action_condition", {})) == 0 ? [] : [lookup(condition.value, "action_condition", {})]
                content {
                  action = lookup(action_condition.value, "action")
                }
              }

              dynamic "label_name_condition" {
                for_each = length(lookup(condition.value, "label_name_condition", {})) == 0 ? [] : [lookup(condition.value, "label_name_condition", {})]
                content {
                  label_name = lookup(label_name_condition.value, "label_name")
                }
              }
            }
          }
        }
      }
    }
  }
}

