# -------------------------------------------------------------
#  Deploy Elastic Cloud
# -------------------------------------------------------------
data "ec_stack" "latest" {
  version_regex = "latest"
  region        = var.mapped_elastic_region[var.elastic_region]
}

resource "ec_deployment" "elastic_deployment" {
  name                    = var.elastic_deployment_name
  region                  = var.mapped_elastic_region[var.elastic_region]
  version                 = var.elastic_version == "latest" ? data.ec_stack.latest.version : var.elastic_version
  deployment_template_id  = var.elastic_deployment_template_id
  elasticsearch {
    autoscale = "true"

    topology {
      id = "cold"
    }

    topology {
      id = "frozen"
    }

    topology {
      id   = "hot_content"
    }

   topology {
      id = "ml"
      size = "1g"
      autoscaling {
        min_size = "1g"
        max_size = "8g"
      }
    }

    topology {
      id = "warm"
    }

    
  }
  kibana {}
  integrations_server {}
}

output "elastic_cluster_id_aws" {
  value = ec_deployment.elastic_deployment.id
}

output "elastic_cluster_alias_aws" {
  value = ec_deployment.elastic_deployment.name
}

output "elastic_endpoint_aws" {
  value = ec_deployment.elastic_deployment.kibana[0].https_endpoint
}

output "elastic_cloud_id_aws" {
  value = ec_deployment.elastic_deployment.elasticsearch[0].cloud_id
}

output "elastic_username_aws" {
  value = ec_deployment.elastic_deployment.elasticsearch_username
}

output "elastic_password" {
  value = ec_deployment.elastic_deployment.elasticsearch_password
  sensitive = true
}


# -------------------------------------------------------------
#  Load Policy
# -------------------------------------------------------------

data "external" "elastic_create_policy" {
  query = {
    kibana_endpoint  = ec_deployment.elastic_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_json_body = templatefile("${path.module}/../json_templates/default-policy.json", {"policy_name": "AWS"})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/kb_create_agent_policy.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

data "external" "elastic_add_aws_integration" {
  query = {
    kibana_endpoint  = ec_deployment.elastic_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_json_body = templatefile("${path.module}/../json_templates/aws_integration.json", 
    {
    "policy_id": data.external.elastic_create_policy.result.id,
    "access_key": var.aws_access_key,
    "access_secret": var.aws_secret_key,
    "aws_region": var.aws_region,
    }
    )
  }
  program = ["sh", "${path.module}/../lib/elastic_api/kb_add_integration_to_policy.sh" ]
  depends_on = [data.external.elastic_create_policy]
}

data "external" "elastic_add_python_integration" {
  query = {
    kibana_endpoint  = ec_deployment.elastic_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_json_body = templatefile("${path.module}/../json_templates/python-integration.json", 
    {
    "policy_id": data.external.elastic_create_policy.result.id
    }
    )
  }
  program = ["sh", "${path.module}/../lib/elastic_api/kb_add_integration_to_policy.sh" ]
  depends_on = [
    data.external.elastic_create_policy
  ]
}

# -------------------------------------------------------------
#  Load Rules
# -------------------------------------------------------------

data "external" "elastic_load_rules" {
  query = {
    kibana_endpoint  = ec_deployment.elastic_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
  }
  program = ["sh", "${path.module}/../lib/elastic_api/kb_load_detection_rules.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

data "external" "elastic_enable_rules" {
  query = {
    kibana_endpoint  = ec_deployment.elastic_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_json_body = templatefile("${path.module}/../json_templates/aws_rule_activation.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/kb_enable_detection_rules.sh" ]
  depends_on = [data.external.elastic_load_rules]
}

# -------------------------------------------------------------
#  Load Dashboards
# -------------------------------------------------------------
data "external" "elastic_upload_saved_objects" {
  query = {
	elastic_http_method = "POST"
    kibana_endpoint  = ec_deployment.elastic_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    so_file      		= "${path.module}/../dashboards/workshop3.ndjson"
  }
  program = ["sh", "${path.module}/../lib/elastic_api/kb_upload_saved_objects.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

data "external" "elastic_upload_saved_objects2" {
  query = {
	elastic_http_method = "POST"
    kibana_endpoint  = ec_deployment.elastic_deployment.kibana[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    so_file      		= "${path.module}/../dashboards/AWS-extension.ndjson"
  }
  program = ["sh", "${path.module}/../lib/elastic_api/kb_upload_saved_objects.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

# -------------------------------------------------------------
#  Load Index Template
# -------------------------------------------------------------

data "external" "elastic_index_template" {
  query = {
	  elastic_http_method = "PUT"
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_template_name = "logs-log.python"
    elastic_index_name = "logs-python-default"
    elastic_json_body      		= templatefile("${path.module}/../json_templates/python-index-template.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_create_index_template.sh" ]
  depends_on = [ec_deployment.elastic_deployment, data.external.elastic_add_python_integration]
}

# -------------------------------------------------------------
#  Load Ingest Pipelines
# -------------------------------------------------------------

data "external" "elastic_ingest_pipeline_apm" {
  query = {
	  elastic_http_method = "PUT"
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_pipeline_name = "traces-apm@custom"
    elastic_json_body      		= templatefile("${path.module}/../json_templates/apm-traces-ingest-pipeline.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_create_ingest_pipeline.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

data "external" "elastic_ingest_pipeline_cloudwatch" {
  query = {
	  elastic_http_method = "PUT"
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_pipeline_name = "logs-aws.cloudwatch_logs@custom"
    elastic_json_body      		= templatefile("${path.module}/../json_templates/cloudwatch-ingest-pipeline.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_create_ingest_pipeline.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

data "external" "elastic_ingest_pipeline_logs" {
  query = {
	  elastic_http_method = "PUT"
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_pipeline_name = "logs-log.log@custom"
    elastic_json_body      		= templatefile("${path.module}/../json_templates/custom-logs-ingest-pipeline.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_create_ingest_pipeline.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

data "external" "elastic_ingest_pipeline_lambda" {
  query = {
	  elastic_http_method = "PUT"
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_pipeline_name = "metrics-aws.lambda@custom"
    elastic_json_body      		= templatefile("${path.module}/../json_templates/lambda-metrics-ingest-pipeline.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_create_ingest_pipeline.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

# -------------------------------------------------------------
#  Create and Start transforms
# -------------------------------------------------------------

data "external" "elastic_create_transforms" {
  query = {
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    transform_name    = "service_summary"
    elastic_json_body = templatefile("${path.module}/../json_templates/service_transform.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_create_transform.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

data "external" "elastic_start_transforms" {
  query = {
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    transform_name    = "service_summary"
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_start_transform.sh" ]
  depends_on = [data.external.elastic_create_transforms]
}

