resource "aws_ssm_document" "ecs-cwagent-sidecar-ec2" {
  name          = "ecs-cwagent-sidecar-ec2"
  document_type = "Command"

  content = <<DOC
  {
    "metrics": {
    "metrics_collected": {
      "statsd": {
        "service_address":":8125"
      }
    }
  },
  "logs": {
    "metrics_collected": {
      "emf": {}
    }
  },
  "csm": {
    "service_addresses": ["udp4://0.0.0.0:31000", "udp6://[::1]:31000"],
    "memory_limit_in_mb": 20
  }
}"
  }
DOC
}