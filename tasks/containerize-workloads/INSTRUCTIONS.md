## How to run the containerized workloads

### Requirements

- Docker installed on your machine
- A linux shell, preferably Bash

### Steps

1. Navigate to the root directory of the repository.
2. Run the start script using the command `./start.sh`, which will build and run the Docker containers.
3. If the required Docker image is missing, the script will automatically build it.
4. You can force rebuilding the Docker images by passing the `--build` flag to the start script:<br>`./start.sh --build`
5. You can also run the build process manually by executing the following command:<br>`./build.sh`
6. To run an experiment, execute the command:<br> `./run-experiment`<br>The results will be displayed in the terminal, in a readable format.
7. Without passing any options, the script will run the `demo-local` experiment.<br>The following options are available:
    * `--experiment-id <experiment_id>` to specify the experiment ID.
    * `--export` to queue the experiment for export.
8. You can also view the results of the experiment in the terminal, using the command<br>`./show-results.sh [experiment_id]`<br> The default experiment_id (`demo-local`) will be used if none is provided.

9. To run the analysis for a fresh experiment and verify its results end to end, execute:<br>`./verify-experiment.sh`<br>It exits nonzero on failure. See [verify-experiment/EVIDENCE.md](../verify-experiment/EVIDENCE.md) for options and exit codes.

10. To train, publish, gate and promote a model and run the analysis with it, use `./model-handoff.sh` and `MODEL_SELECTION_FILE`. See [support-teams/EVIDENCE.md](../support-teams/EVIDENCE.md).

### Shutting down the containers

To shut down the containers, execute the command:<br>`./stop.sh`

### Data location

The created data is stored in a persistent Docker Volume:
`data-objects`; published models, gate records and channels are in `data-model-registry`.

[Demonstration](EVIDENCE.md)

## Limitations
* The built Docker Image is not pushed to a registry. This could be added very easily to the build script but skipped because the functionality of the demo will not benefit from it.
* The containerization is implemented using Docker Compose, it is not recommended for production use, which should be implemented using Kubernetes.