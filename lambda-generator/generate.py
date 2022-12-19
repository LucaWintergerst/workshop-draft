import pandas as pd
import math
import random
import hashlib
from random import randrange
from dotenv import load_dotenv
import os

from elasticsearch import Elasticsearch
from elasticsearch.helpers import streaming_bulk

from datetime import datetime
from dateutil.relativedelta import relativedelta

#date_rng = pd.date_range(start="10/19/2022", end=datetime.today().strftime('%m/%d/%Y').replace("/0", "/"), freq='5min')
date_rng = pd.date_range(
    start=(datetime.today()  - relativedelta(months=3)).strftime('%m/%d/%Y').replace("/0", "/"), 
    end=(datetime.today()).strftime('%m/%d/%Y').replace("/0", "/"), 
    freq='5min')


load_dotenv()

def process():
  # print( (datetime.today()  - relativedelta(months=12)).strftime('%m/%d/%Y').replace("/0", "/"))
  i = 0
  counter = 1

  metricRand = {
        'sample-app-dev-consumer': 1.75,
        'sample-app-dev-producer': 1.15,
        'other-function3': 3.2,
        'other-function4': 0.9
  }

  for date in date_rng:
    i = i+1

    # trend over time? 
    #     metric = 100  * (1 + i/500000)
    metric = 100 

    #some daily variance 
    multi = 1 + date.weekday()/60

    #different values on weekends
    if date.weekday() == 4:
      multi = 1.2
    if date.weekday() == 5:
      multi = 1.6
    if date.weekday() == 6:
      multi = 1.8


    #add anomaly for specific day
    if date.hour <= 12:
      metric = metric*2 + (metric * math.sin((date.hour * 60 +  date.minute) / 360 *math.pi/2)) * multi / 4
    if date.hour > 12:
      metric = metric*2 + (metric * math.sin(((24 - date.hour) * 60  - (date.minute)) / 360 *math.pi/2) * -1) * multi / 4
    metric = metric * random.uniform(0.75,1.25)
    if date.day == 7 and date.month == 6 and (date.hour == 7) and date.minute > 10:
      #1.003
      metric = metric * math.pow(0.992, counter)
      counter = counter + 2

    #print(date.isoformat())
    #print(metric * random.uniform(0.95,1.05) )

    metricOriginal = metric

    for function in ["sample-app-dev-consumer", "sample-app-dev-producer", "other-function3", "other-function4"]:
        #add anomaly for specific day
        metric = metricOriginal * metricRand[function]
        if date.hour <= 12:
            metric = metric*2 + (metric * math.sin((date.hour * 60 +  date.minute) / 360 *math.pi/2)) * multi / 4
        if date.hour > 12:
            metric = metric*2 + (metric * math.sin(((24 - date.hour) * 60  - (date.minute)) / 360 *math.pi/2) * -1) * multi / 4
            metric = metric * random.uniform(0.75,1.25)
        if date> (datetime.today()  - relativedelta(months=1)) and date < (datetime.today()  - relativedelta(months=1) + relativedelta(minutes=50)) and function == "sample-app-dev-consumer":
        #if date.day == 1 and date.month == 12 and (date.hour == 7) and date.minute > 10 and function == "function2":
        #1.003
            metric = metric * math.pow(2 - 0.902, counter)
            counter = counter + 2
        doc = {
            '_index': 'lambda-1',
            '_id': hashlib.md5(date.isoformat().encode()).hexdigest() + function,
            '@timestamp': date.isoformat(),
            "aws": {
                "cloudwatch": {
                    "namespace": "AWS/Lambda"
                },
                "dimensions": {
                    "FunctionName":function,
                    "Resource": function
                },
                "lambda": {
                    "metrics": {
                        "Duration": {
                            "avg": metric
                        },
                        "Errors": {
                            "avg": randrange(int(metric))
                        },
                        "Invocations": {
                            "avg": randrange(int(metric) * 10)
                        },
                        "Throttles": {
                            "avg": randrange(int(metric))
                        }
                    }
                }
            },
            "cloud": {
                "account": {
                    "id": "627959692251",
                    "name": "elastic-test"
                },
                "provider": "aws",
                "region": "us-west-2"
            },
            "event": {
                "dataset": "aws.lambda",
                "duration": 10650456766 * random.uniform(0.75,1.25),
                "module": "aws"
            },
            "metricset": {
                "name": "lambda",
                "period": 300000
            },
            "service": {
                "type": "aws"
            }
        }
        yield doc


es = Elasticsearch(
    cloud_id= os.environ["CLOUD_ID"], 
    basic_auth=(os.environ["USERNAME"], os.environ["PASSWORD"])
    )

cnt = 0

createBody = {
    "settings": {
      "index": {
        "number_of_replicas": "1",
        "number_of_shards": "1",
        "mapping": {
          "total_fields": {
            "limit": "10000"
          }
        },
        "routing": {
          "allocation": {
            "include": {
              "_tier_preference": "data_hot"
            }
          }
        },
        "codec": "best_compression",
        "query": {
          "default_field": [
            "cloud.image.id",
            "cloud.account.id",
            "cloud.account.name",
            "cloud.availability_zone",
            "cloud.instance.id",
            "cloud.instance.name",
            "cloud.machine.type",
            "cloud.provider",
            "cloud.region",
            "cloud.project.id",
            "host.os.build",
            "host.os.codename",
            "host.os.family",
            "host.os.kernel",
            "host.os.name",
            "host.os.platform",
            "host.os.version",
            "host.architecture",
            "host.domain",
            "host.hostname",
            "host.id",
            "host.mac",
            "host.name",
            "host.type",
            "ecs.version",
            "error.message",
            "service.type",
            "container.id",
            "container.image.name",
            "container.name",
            "aws.dimensions.FunctionName",
            "aws.dimensions.Resource",
            "aws.dimensions.ExecutedVersion",
            "aws.cloudwatch.namespace",
            "aws.s3.bucket.name"
          ]
        },
        "hidden": "true",
        "final_pipeline": ".fleet_final_pipeline-1",
        "lifecycle": {
          "name": "metrics"
        }
      }
    },
    "mappings": {
      "date_detection": False,
      "properties": {
        "elastic_agent": {
          "properties": {
            "version": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "snapshot": {
              "type": "boolean"
            },
            "id": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "container": {
          "properties": {
            "image": {
              "properties": {
                "name": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "labels": {
              "type": "object"
            },
            "id": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "name": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "service": {
          "properties": {
            "type": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "@timestamp": {
          "type": "date"
        },
        "aws": {
          "properties": {
            "s3": {
              "properties": {
                "bucket": {
                  "properties": {
                    "name": {
                      "ignore_above": 1024,
                      "type": "keyword"
                    }
                  }
                }
              }
            },
            "tags": {
              "properties": {
                "serverlessrepo:applicationId": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "aws:cloudformation:logical-id": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "aws:cloudformation:stack-id": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "*": {
                  "type": "object"
                },
                "lambda:createdBy": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "lambda-console:blueprint": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "aws:cloudformation:stack-name": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "serverlessrepo:semanticVersion": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "STAGE": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "dimensions": {
              "properties": {
                "*": {
                  "type": "object"
                },
                "Resource": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "FunctionName": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "ExecutedVersion": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "cloudwatch": {
              "properties": {
                "namespace": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "lambda": {
              "properties": {
                "metrics": {
                  "properties": {
                    "ProvisionedConcurrencySpilloverInvocations": {
                      "properties": {
                        "sum": {
                          "type": "long"
                        }
                      }
                    },
                    "ProvisionedConcurrencyUtilization": {
                      "properties": {
                        "max": {
                          "type": "long"
                        }
                      }
                    },
                    "Errors": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "UnreservedConcurrentExecutions": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "DeadLetterErrors": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "ProvisionedConcurrencyInvocations": {
                      "properties": {
                        "sum": {
                          "type": "long"
                        }
                      }
                    },
                    "Invocations": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "ProvisionedConcurrentExecutions": {
                      "properties": {
                        "max": {
                          "type": "long"
                        }
                      }
                    },
                    "DestinationDeliveryFailures": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "ConcurrentExecutions": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "Duration": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "IteratorAge": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    },
                    "Throttles": {
                      "properties": {
                        "avg": {
                          "type": "double"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "agent": {
          "properties": {
            "ephemeral_id": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "type": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "id": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "version": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "name": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "metricset": {
          "properties": {
            "name": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "period": {
              "type": "long"
            }
          }
        },
        "host": {
          "properties": {
            "domain": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "name": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "ip": {
              "type": "ip"
            },
            "hostname": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "mac": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "architecture": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "containerized": {
              "type": "boolean"
            },
            "type": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "os": {
              "properties": {
                "kernel": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "name": {
                  "ignore_above": 1024,
                  "fields": {
                    "text": {
                      "type": "match_only_text"
                    }
                  },
                  "type": "keyword"
                },
                "family": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "platform": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "version": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "build": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "codename": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "type": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "id": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "ecs": {
          "properties": {
            "version": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        },
        "error": {
          "properties": {
            "message": {
              "type": "match_only_text"
            }
          }
        },
        "data_stream": {
          "properties": {
            "type": {
              "type": "constant_keyword",
              "value": "metrics"
            },
            "namespace": {
              "type": "constant_keyword",
              "value": "default"
            },
            "dataset": {
              "type": "constant_keyword",
              "value": "aws.lambda"
            }
          }
        },
        "event": {
          "properties": {
            "duration": {
              "type": "long"
            },
            "agent_id_status": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "ingested": {
              "type": "date",
              "format": "strict_date_time_no_millis||strict_date_optional_time||epoch_millis"
            },
            "module": {
              "type": "constant_keyword",
              "value": "aws"
            },
            "dataset": {
              "type": "constant_keyword",
              "value": "aws.lambda"
            }
          }
        },
        "cloud": {
          "properties": {
            "project": {
              "properties": {
                "id": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "account": {
              "properties": {
                "id": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "name": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "availability_zone": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "image": {
              "properties": {
                "id": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "machine": {
              "properties": {
                "type": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "instance": {
              "properties": {
                "id": {
                  "ignore_above": 1024,
                  "type": "keyword"
                },
                "name": {
                  "ignore_above": 1024,
                  "type": "keyword"
                }
              }
            },
            "provider": {
              "ignore_above": 1024,
              "type": "keyword"
            },
            "region": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        }
      },
      "_meta": {
        "managed_by": "fleet",
        "managed": True,
        "package": {
          "name": "aws"
        }
      },
      "dynamic_templates": [
        {
          "strings_as_keyword": {
            "match_mapping_type": "string",
            "mapping": {
              "ignore_above": 1024,
              "type": "keyword"
            }
          }
        }
      ],
      "_data_stream_timestamp": {
        "enabled": True
      }
    }
}
try:
  es.indices.create(index='lambda-1',body=createBody)
  es.indices.put_alias(index='lambda-1', name='metrics-lambda')
except Exception as e:
  print(e)

for success, info in streaming_bulk(
                es,
                process(),
                chunk_size=10000
        ):
            if success:
                cnt += 1
                if cnt % 1000 == 0:
                    print('.')
            else:
                print('Doc failed', info)
