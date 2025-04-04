# Deploy-ElasticEDR
Just a janky bash script with templated yaml files to deploy elasticEDR (elasticsearch + kibana) on a host for testing purposes

After the deployment is done, it is required that the user generates kibana encryption keys and places them in the `kibana.yml` file.

```bash
# Generate kibana encryption keys
/usr/share/kibana/bin/kibana-encryption-keys
```
