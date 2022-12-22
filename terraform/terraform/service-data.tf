# -------------------------------------------------------------
#  Load Index Mapping
# -------------------------------------------------------------

data "external" "elastic_create_services_index" {
  query = {

    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_index_name    = "services"
    elastic_json_body = templatefile("${path.module}/../json_templates/services-index.json",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_create_mapping.sh" ]
  depends_on = [ec_deployment.elastic_deployment]
}

# -----------------------------------------------------------                                                                                                                                                              --
#  Load Data
# -------------------------------------------------------------

data "external" "elastic_fill_services_index" {
  query = {
    elastic_endpoint  = ec_deployment.elastic_deployment.elasticsearch[0].https_endpoint
    elastic_username  = ec_deployment.elastic_deployment.elasticsearch_username
    elastic_password  = ec_deployment.elastic_deployment.elasticsearch_password
    elastic_index_name    = "services"
    elastic_json_body = templatefile("${path.module}/../json_templates/services-data.ndjson",{})
  }
  program = ["sh", "${path.module}/../lib/elastic_api/es_bulk.sh" ]
  depends_on = [data.external.elastic_create_services_index]
}

