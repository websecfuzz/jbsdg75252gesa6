# Artefact for "SQLiFuzz: Uncover SQL Injection in Any Web Applications"

## What is This?
This repository contains the artefact accompanying our paper submission. It includes:

- SQLiFuzz source code
- Web Under Test (WUT)
- Scripts to reproduce our experiments
- Documentation for setup and usage

## Repository Structure

- /crawler/ # Source code of custom crawler and fuzzer
- /scripts # Scripts to run the experiments
- /final_results/ # Final output from experiments
- /WUT # Web Under Test
- README.md # This file

## Getting Started

### Requirements

- Python 3
- Docker

### Setup Instructions
- Open directory /scripts in a terminal
- Run ./setup.sh to install required libraries
- Start Docker
  ```
  systemctl start docker
  ```

- Open all_sqlifuzz.sh to see the way to run the experiment.
- For example, if you want to test Appwrite with SQLiFuzz+Schemathesis, copy this command to the terminal:
  ```
  ./sqlifuzz.sh appwrite 8080 /console/login openapi.json schemathesis
  ```

- The experiment runs the target web application inside a Docker container. Once the web application is ready, Schemathesis is launched.
- The final results, including any detected BAC vulnerabilities, are saved in the final_result folder