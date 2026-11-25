~~~terminaloutput
yossi@Yossi-Laptop UCRT64 ~/projects/devops-assignment-teracyte (main)
$ ./start.sh
Docker image 'api-image' not found. Building...
[+] Building 31.9s (17/17) FINISHED                                                                                                                                                                                    docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                                                                   0.0s
 => => transferring dockerfile: 241B                                                                                                                                                                                                   0.0s
 => resolve image config for docker-image://docker.io/docker/buildkit-syft-scanner:stable-1                                                                                                                                            1.7s
 => [auth] docker/buildkit-syft-scanner:pull token for registry-1.docker.io                                                                                                                                                            0.0s
 => [internal] load metadata for ghcr.io/astral-sh/uv:python3.15-trixie-slim                                                                                                                                                           1.4s
 => [internal] load .dockerignore                                                                                                                                                                                                      0.0s
 => => transferring context: 68B                                                                                                                                                                                                       0.0s
 => [1/8] FROM ghcr.io/astral-sh/uv:python3.15-trixie-slim@sha256:3ee10471b12b57f6f86d03f68c44fbd4bb8d5540efa25ab3b89159e1216b1a70                                                                                                     4.0s
 => => resolve ghcr.io/astral-sh/uv:python3.15-trixie-slim@sha256:3ee10471b12b57f6f86d03f68c44fbd4bb8d5540efa25ab3b89159e1216b1a70                                                                                                     0.0s
 => => sha256:1ef9f2aa698dc0a8d0c35fe231ff2cd6d3e3665609991d1480c30338f0ce8ade 19.82MB / 19.82MB                                                                                                                                       1.7s
 => => sha256:95e91f534ac477f7a5ae3f1e6ac6b1a3a1f5b3287127d83f09b2ec456e29ca78 249B / 249B                                                                                                                                             0.5s
 => => sha256:56ea9ca2dc43dac76e7b3da138ffcba0b60a2bc456f9262be9e1c9bd37aad231 13.16MB / 13.16MB                                                                                                                                       3.0s
 => => sha256:f27677aa9900574e8590bf720b786f8967d88729197d0238afb61856abc186ce 1.29MB / 1.29MB                                                                                                                                         0.8s
 => => sha256:40748add9f4f6f944f334cbfc286590d6e93f60fb06f6ee7ffa1b894080ad861 29.84MB / 29.84MB                                                                                                                                       2.2s
 => => extracting sha256:40748add9f4f6f944f334cbfc286590d6e93f60fb06f6ee7ffa1b894080ad861                                                                                                                                              0.6s
 => => extracting sha256:f27677aa9900574e8590bf720b786f8967d88729197d0238afb61856abc186ce                                                                                                                                              0.1s
 => => extracting sha256:56ea9ca2dc43dac76e7b3da138ffcba0b60a2bc456f9262be9e1c9bd37aad231                                                                                                                                              0.3s
 => => extracting sha256:95e91f534ac477f7a5ae3f1e6ac6b1a3a1f5b3287127d83f09b2ec456e29ca78                                                                                                                                              0.0s
 => => extracting sha256:1ef9f2aa698dc0a8d0c35fe231ff2cd6d3e3665609991d1480c30338f0ce8ade                                                                                                                                              0.2s
 => [internal] load build context                                                                                                                                                                                                      0.1s
 => => transferring context: 191.84kB                                                                                                                                                                                                  0.0s
 => docker-image://docker.io/docker/buildkit-syft-scanner:stable-1                                                                                                                                                                     3.6s
 => => resolve docker.io/docker/buildkit-syft-scanner:stable-1                                                                                                                                                                         0.2s
 => => sha256:114c69ab61a7183a9760230837f905a72711cd9ad7dbbf6939e8e39830c25dbf 49.59MB / 49.59MB                                                                                                                                       2.9s
 => => extracting sha256:114c69ab61a7183a9760230837f905a72711cd9ad7dbbf6939e8e39830c25dbf                                                                                                                                              0.4s
 => [2/8] RUN apt-get update                                                                                                                                                                                                           2.5s
 => [3/8] RUN apt-get upgrade -y                                                                                                                                                                                                       2.2s
 => [4/8] RUN apt-get install -y curl jq                                                                                                                                                                                               4.0s
 => [5/8] WORKDIR /app                                                                                                                                                                                                                 0.0s
 => [6/8] COPY . /app                                                                                                                                                                                                                  0.0s
 => [7/8] RUN uv init --bare                                                                                                                                                                                                           0.4s
 => [8/8] RUN uv add -r requirements-local.txt                                                                                                                                                                                         4.4s
 => [linux/amd64] generating sbom using docker.io/docker/buildkit-syft-scanner:stable-1                                                                                                                                                1.8s
 => exporting to image                                                                                                                                                                                                                 8.6s
 => => exporting layers                                                                                                                                                                                                                3.5s
 => => exporting manifest sha256:2270566c332e03f84358150dd58c8e72fa951bbc1c56f393351455b5e213fc1f                                                                                                                                      0.0s
 => => exporting config sha256:a3155f418afd9a8aaceaa3beca1e83f289c76b505f6f96c5cf3896ecd41f352c                                                                                                                                        0.0s
 => => exporting attestation manifest sha256:31bf4c606e1386a1c93ccebc70f7fbe6427d722c7d5b813cc8464d77e9d15763                                                                                                                          0.0s
 => => exporting manifest list sha256:14d296ccd30eb4c59b05c1fd9cdc2b4a7b61c318c92a2fd957ee44405db5e656                                                                                                                                 0.0s
 => => naming to docker.io/library/api-image:latest                                                                                                                                                                                    0.0s
 => => unpacking to docker.io/library/api-image:latest                                                                                                                                                                                 2.7s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/j3cx4cwnv9vbju5vkhspuliec
[+] up 45/45
 ✔ Image redis:7                              Pulled                                                                                                                                                                                    6.1s
 ✔ Image postgres:16                          Pulled                                                                                                                                                                                   14.4s
 ✔ Image mongo:7                              Pulled                                                                                                                                                                                   17.7s
 ✔ Network devops-assignment-teracyte_default Created                                                                                                                                                                                   0.0s
 ✔ Volume data-model-lifecycle                Created                                                                                                                                                                                   0.0s
 ✔ Volume data-objects                        Created                                                                                                                                                                                   0.0s
 ✔ Container teracyte-mongo                   Healthy                                                                                                                                                                                   4.5s
 ✔ Container teracyte-redis                   Healthy                                                                                                                                                                                   3.6s
 ✔ Container teracyte-postgres                Healthy                                                                                                                                                                                   3.3s
 ✔ Container teracyte-celery                  Started                                                                                                                                                                                   4.2s
 ✔ Container teracyte-api                     Started                                                                                                                                                                                   6.3s

yossi@Yossi-Laptop UCRT64 ~/projects/devops-assignment-teracyte (main)
$ ./run-experiment.sh --export
Running experiment demo-local...
{
  "experiment_id": "demo-local",
  "image_id": "image-001",
  "mask_path": "/app/data/objects/masks/demo-local/image-001.png",
  "threshold": 127,
  "width": 3072,
  "height": 2048,
  "foreground_pixels": 3156788,
  "duration_seconds": 0.523
}
{
  "experiment_id": "demo-local",
  "image_id": "image-001",
  "foreground_fraction": 0.501758,
  "mean_intensity": 191.511,
  "model_sha256": "70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f",
  "duration_seconds": 0.131
}
{
  "experiment_id": "demo-local",
  "image_id": "image-002",
  "mask_path": "/app/data/objects/masks/demo-local/image-002.png",
  "threshold": 127,
  "width": 3072,
  "height": 2048,
  "foreground_pixels": 3156781,
  "duration_seconds": 0.477
}
{
  "experiment_id": "demo-local",
  "image_id": "image-002",
  "foreground_fraction": 0.501757,
  "mean_intensity": 191.519,
  "model_sha256": "70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f",
  "duration_seconds": 0.138
}
{
  "experiment_id": "demo-local",
  "image_id": "image-003",
  "mask_path": "/app/data/objects/masks/demo-local/image-003.png",
  "threshold": 127,
  "width": 3072,
  "height": 2048,
  "foreground_pixels": 3156823,
  "duration_seconds": 0.475
}
{
  "experiment_id": "demo-local",
  "image_id": "image-003",
  "foreground_fraction": 0.501764,
  "mean_intensity": 191.473,
  "model_sha256": "70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f",
  "duration_seconds": 0.135
}
{
  "experiment_id": "demo-local",
  "image_id": "image-004",
  "mask_path": "/app/data/objects/masks/demo-local/image-004.png",
  "threshold": 127,
  "width": 3072,
  "height": 2048,
  "foreground_pixels": 3157034,
  "duration_seconds": 0.478
}
{
  "experiment_id": "demo-local",
  "image_id": "image-004",
  "foreground_fraction": 0.501797,
  "mean_intensity": 191.5,
  "model_sha256": "70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f",
  "duration_seconds": 0.153
}
{
  "experiment_id": "demo-local",
  "image_id": "image-005",
  "mask_path": "/app/data/objects/masks/demo-local/image-005.png",
  "threshold": 127,
  "width": 3072,
  "height": 2048,
  "foreground_pixels": 3156496,
  "duration_seconds": 0.496
}
{
  "experiment_id": "demo-local",
  "image_id": "image-005",
  "foreground_fraction": 0.501712,
  "mean_intensity": 191.498,
  "model_sha256": "70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f",
  "duration_seconds": 0.171
}
{
  "experiment_id": "demo-local",
  "written": 5
}
{
  "experiment_id": "demo-local",
  "image_count": 5,
  "status": "COMPLETED"
}
{
  "task_id": "43218bdd-1b0c-4f31-a9e7-cb8b754a4dda",
  "status": "QUEUED"
}

yossi@Yossi-Laptop UCRT64 ~/projects/devops-assignment-teracyte (main)
~~~