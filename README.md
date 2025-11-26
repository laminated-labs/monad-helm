# Monad Helm Chart

Deploy Monad validator or full nodes (same binary; a full node is simply an unregistered validator) on Kubernetes using the Helm chart contained in this repository. The chart provisions the services, persistent storage, sidecar scripts, and telemetry hooks required to operate a Monad node with automated snapshot restores and forkpoint management.

## Repository Layout
- `charts/monad/Chart.yaml` – chart metadata (version `1.0.7`, app version `v0.12.2`).
- `charts/monad/values.yaml` – default values for replica count, images, node configuration, and monitoring.
- `charts/monad/templates/` – Kubernetes manifests for the StatefulSet, Services, Secrets, PVCs, and optional monitoring resources.
- `charts/monad/configs/` – config files packaged into a ConfigMap (genesis data, validator set, OpenTelemetry collector config, node map, and sample `node.toml`, files need to be sourced from Monad validator documentation).
- `charts/monad/scripts/` – operational scripts mounted into the pod to reset storage, download forkpoints, and prune old artifacts.

## Prerequisites
- Kubernetes 1.25+ cluster with nodes that can expose host networking on port `8000` (the chart sets `hostNetwork: true`).
- Helm 3.10+ installed locally.
- Storage classes capable of provisioning the default PersistentVolumeClaims (`1.7Ti` NVMe filesystem and `1.7Ti` block volume). Override `pvc.yaml` settings if your environment differs.
- Worker nodes configured with huge pages (`HugePages-2Mi` and `HugePages-1Gi`) to satisfy the pod limits configured in the StatefulSet.
- Access to the required container images (`categoryxyz/monad-*`). Configure `imagePullSecrets` if the registry is private.

## Docker Image
A Dockerfile is provided to build the image with the necessary monad binaries. You can specify a different version by setting the `VERSION` build argument. The chart defaults align with mainnet-compatible images (app version `v0.12.2`).

## Installation
1. Clone this repository and change into it.
2. Create a custom values file (for example `my-values.yaml`) with your node identity, peer list, image tags, and secrets.
3. Follow the steps in the Monad documentation to download the necessary configuration files into `charts/monad/configs/` (this repo only includes the OpenTelemetry collector config by default).
    - `genesis.json` – the genesis block for the network.
    - `node.toml` - node configuration
    - `node-map.csv` - list of known peers.
    - `validators.toml` - validator set.
3. Deploy the chart:
   ```bash
   helm upgrade --install monad charts/monad -f my-values.yaml
   ```
4. Inspect the rendered manifests before deploying if desired:
   ```bash
   helm template monad charts/monad -f my-values.yaml
   ```

## Configuration Highlights
| Value | Description |
| ----- | ----------- |
| `replicaCount` | Number of Monad pods to run (defaults to `1`). |
| `imagePullSecrets.*` | Configure registry credentials; set `create: true` and provide `secret` (raw Docker config JSON, **not** base64) to generate the secret automatically. |
| `bft.image`, `execution.image`, `rpc.image`, `mpt.image` | Container images for the different Monad components; override tags to pin specific releases. |
| `node.*` | Populate node metadata and peer lists consumed by `configs/node.toml` (e.g., `node.name`, `node.address`, `node.peers`, `node.fullnodes`). |
| `secret.*` | Control how validator keys are mounted. Set `create: true`, provide base64-encoded `secp`, `bls`, and `keystorePassword` fields (note the keys are `secp`/`bls`, not `secpKey`/`blsKey`), or point `name` at an existing secret with the keys `id-secp`, `id-bls`, and `KEYSTORE_PASSWORD`. |
| `monitoring.enabled` | Renders a PodMonitor and OpenTelemetry collector sidecar (declared under the initContainers block), plus config for additional scrape targets via `monitoring.ports`. |
| `extraInitContainers`, `extraVolumes`, `extraVolumeMounts`, `extraObjects` | Inject additional operational logic or manifests without forking the chart. |

Refer to `charts/monad/values.yaml` for the full list of tunables.

## Secrets and Keys
- Validator nodes require Monad secp256k1 and BLS keypairs along with the keystore password. Provide them via `secret.name` (existing secret) or let the chart create a secret by setting `secret.create: true` and supplying the base64-encoded values in the `secret` block.
- The StatefulSet mounts the secret at `/monad/keys` and expects filenames `id-secp` and `id-bls` plus the `KEYSTORE_PASSWORD` environment variable. Never commit live keys into version control.

## Operational Scripts and Sentinel Files
The `monad-scripts` ConfigMap injects three helper scripts:
- `init.sh` – prepares the TrieDB block device, restores from the latest snapshot (using aria2/zstd utilities), and reacts to sentinel files.
- `initialize-configs.sh` – fetches the latest forkpoint and validator configurations when none exists or a soft reset is requested.
- `clear-old-artifacts.sh` – removes stale WAL, forkpoint, and ledger files after new data is detected.

Sentinel files placed inside the mounted volume toggle maintenance tasks:
- `/monad/HARD_RESET_SENTINEL_FILE` – wipe the ledger, re-create the TrieDB, and trigger a fresh snapshot restore.
- `/monad/RESTORE_FROM_SNAPSHOT_SENTINEL_FILE` – re-import the most recent snapshot without a full reset.
- `/monad/SOFT_RESET_SENTINEL_FILE` – download a fresh `forkpoint.toml` and `validators.toml`.

## Networking and Services
- The pod exposes TCP and UDP `8000` via host networking for BFT traffic. A headless Service publishes the same ports (plus the otel port) for discovery and optional external DNS annotations.
- RPC traffic binds to port `8080` on the host network only; the Service does not expose RPC. Add your own Service/Ingress if cluster-level access is required.

## Monitoring
When `monitoring.enabled: true` the chart:
- Runs an OpenTelemetry collector sidecar (declared under the initContainers block) with config from `configs/otel-collector-config.yaml`, exporting to the mainnet endpoint `https://otel-external.monadinfra.com:443` and exposing Prometheus metrics on `8889`.
- Creates a `PodMonitor` (for Prometheus Operator) and allows additional port scraping via `monitoring.ports`.
- Propagates `OTEL_ENDPOINT` to the BFT and RPC containers so they can emit traces/metrics.

## Development and Testing
- Use `helm lint charts/monad` to validate template syntax.
- Render templates locally with `helm template` to review generated manifests before applying them to a cluster.
- Update `version` and `appVersion` in `Chart.yaml` when you publish changes.

## Roadmap
- [ ] Publish container images built from our Dockerfile.
- [ ] Build the Monad binaries from source as part of the image build to ensure reproducible and secure releases.
- [ ] Open source our metrics sidecar application and include it in the published image.
- [ ] Incorporate MEV client support.
- [ ] Support pulling 3rd party snapshot

## License
This project is released under the [Apache License 2.0](LICENSE).
