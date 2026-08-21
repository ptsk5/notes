# Images by tags steps

```bash
# get current registries.conf
renderedconfig=$(oc get machineconfigpool worker -o jsonpath='{.spec.configuration.name}')
oc get machineconfig $renderedconfig -o jsonpath='{.spec.config.storage.files[?(@.path=="/etc/containers/registries.conf")].contents.source}' | awk -F "base64," '{print $2}'|base64 -d > registries.conf

# convert to registries by tag
cp registries.conf registries-by-tag.conf
sed -i 's/pull-from-mirror = "tag-only"\|pull-from-mirror = "digest-only"/mirror-by-digest-only = false/g' registries-by-tag.conf
ENCODED_CONTENT=$(cat  registries-by-tag.conf| base64 -w0)

# prepare IDMS for use with HCP
curl -L "https://github.com/mikefarah/yq/releases/download/v4.53.4/yq_linux_amd64" -o /tmp/yq-v4 && chmod +x /tmp/yq-v4
oc get ImageDigestMirrorSet -oyaml | /tmp/yq-v4 '.items[] | .spec.imageDigestMirrors' > ~/jpetnik/vhcp/mgmt_icsp.yaml

# create configmap in multicluster-engine namespace for HCP nodepool can use ITMS
oc create -n multicluster-engine configmap custom-registries --from-file=ca-bundle.crt=CEEERTTT-HERE.crt --from-file=registries.conf

# create config map for machineconfig for hcp to use pull images by tag for nodepools
cat <<EOF_YAML | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: registry-per-tag
  namespace: clusters
data:
  config: |
    apiVersion: machineconfiguration.openshift.io/v1
    kind: MachineConfig
    metadata:
      name: 99-worker-mirror-by-digest-registries
    spec:
      config:
        ignition:
          config: {}
          security:
            tls: {}
          timeouts: {}
          version: 3.2.0
        networkd: {}
        passwd: {}
        storage:
          files:
            - path: /etc/containers/registries.conf.d/99-mirror-by-digest-registries.conf
              mode: 420
              overwrite: true
              contents:
                source: data:text/plain;charset=utf-8;base64,$ENCODED_CONTENT
EOF_YAML

# CREATE the cluster with node-pool-replicas 0 !!!
# <<HERE>>

# patch nodepool to use custom cm for hcp to pull by tags required for pulling catalogs by tag or any image per tag
oc patch  nodepool -n clusters ${CLUSTER_NAME}  --type=merge -p '{"spec": {"config": [{"name": "registry-per-tag"}], "replicas": '$WORKER_COUNT'}}'
```
