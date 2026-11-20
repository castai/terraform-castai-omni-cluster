locals {
  bucket = aws_s3_bucket.greetings.id
}

resource "null_resource" "demo" {
  triggers = {
    always = timestamp()
    joined = join(",", module.edge_join.joined)
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = abspath(local_file.kubeconfig.filename)
      BUCKET     = local.bucket
      ROLE_ARN   = aws_iam_role.greetings.arn
      REGION     = var.region
    }
    command = <<-EOT
      set -e
      kubectl create namespace omni-demo --dry-run=client -o yaml | kubectl apply -f -
      cat <<'YAML' | kubectl apply -f -
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: greeting-writer
        namespace: omni-demo
        annotations:
          # Cloud pods: EKS injects the token exchange for this annotation.
          # Edge pods: omni-connect's emulated pod identity agent honors
          # the very same annotation.
          eks.amazonaws.com/role-arn: ${aws_iam_role.greetings.arn}
      YAML
      cat <<'YAML' | kubectl apply -f -
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: greeting-writer
        namespace: omni-demo
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: greeting-writer
        template:
          metadata:
            labels:
              app: greeting-writer
          spec:
            serviceAccountName: greeting-writer
            containers:
              - name: writer
                image: public.ecr.aws/aws-cli/aws-cli:latest
                env:
                  - name: AWS_DEFAULT_REGION
                    value: ${var.region}
                  - name: BUCKET
                    value: ${local.bucket}
                command: ["sh", "-c"]
                args:
                  - |
                    set -e
                    while true; do
                      NAME="greeting-$$(date +%s).txt"
                      echo "Hello from a cloud pod at $$(date -u +%FT%TZ)" \
                        | aws s3 cp - "s3://$BUCKET/$NAME"
                      echo "wrote $$NAME"
                      sleep 5
                    done
      YAML
      cat <<'YAML' | kubectl apply -f -
      apiVersion: v1
      kind: Service
      metadata:
        name: greeting-reader
        namespace: omni-demo
      spec:
        selector:
          app: greeting-reader
        ports:
          - port: 8080
            targetPort: 8080
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: greeting-reader
        namespace: omni-demo
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: greeting-reader
        template:
          metadata:
            labels:
              app: greeting-reader
          spec:
            serviceAccountName: greeting-writer
            # Pin to the edge VM: this pod runs outside the cloud, on the
            # machine joined by omni-connect.
            nodeSelector:
              omni.cast.ai/role: edge
            tolerations:
              - key: omni.cast.ai/edge
                operator: Exists
                effect: NoSchedule
              - operator: Exists
                effect: NoExecute
            containers:
              - name: reader
                image: public.ecr.aws/aws-cli/aws-cli:latest
                env:
                  - name: AWS_DEFAULT_REGION
                    value: ${var.region}
                  - name: BUCKET
                    value: ${local.bucket}
                command: ["sh", "-c"]
                args:
                  - |
                    set -e
                    mkdir -p /tmp/www
                    echo 'it works - greetings from the cloud appear here' > /tmp/www/index.html
                    (cd /tmp/www && python3 -m http.server 8080) &
                    while true; do
                      LATEST=$$(aws s3 ls "s3://$BUCKET" | tail -1 | awk '{print $$4}')
                      if [ -n "$$LATEST" ]; then
                        BODY=$$(aws s3 cp "s3://$BUCKET/$$LATEST" -)
                        echo "$$BODY (read from $$LATEST on the edge VM)"
                        echo "$$BODY" > /tmp/www/index.html
                      fi
                      sleep 5
                    done
                ports:
                  - containerPort: 8080
      YAML
      echo
      echo "== the demo is up =="
      echo "watch the edge read what the cloud wrote:"
      echo "  kubectl -n omni-demo logs -f deploy/greeting-reader"
      echo "reach the edge pod from anywhere in the cluster (the omninet fabric):"
      echo "  kubectl -n omni-demo run curl --rm -it --image=curlimages/curl -- curl http://greeting-reader:8080"
      echo "exec into a pod running outside the cloud (the virtual node at work):"
      echo "  kubectl -n omni-demo exec -it deploy/greeting-reader -- aws s3 ls s3://$BUCKET | tail -1"
    EOT
  }
}
