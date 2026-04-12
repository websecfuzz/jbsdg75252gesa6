# Installation Instructions

This guide explains how to install and test the SQLiFuzz framework.

## 1. Prerequisites
Ensure you have `git`, `python3`, `pip`, and `docker` installed on your system.

## 2. Installation Steps
Open a terminal in the project root and navigate to the scripts directory:
```bash
cd scripts/
./setup.sh
```
This script will install the necessary Python dependencies via `requirement.txt`.

Ensure the Docker daemon is running:
```bash
sudo systemctl start docker
```

## 3. Testing the Installation (Basic Usage)
To confirm the installation is successful and the environment is working correctly, you can run a quick test against one of the bundled Web applications Under Test (WUT).

For example, to test the Appwrite target with SQLiFuzz and Schemathesis:
```bash
cd scripts/
./sqlifuzz.sh appwrite 8080 /console/login openapi.json schemathesis
```

**Expected Output:**
1. Docker Compose will start the target application container.
2. The framework will initialize and log the fuzzing process.
3. Detected potential vulnerabilities will be saved in the `/final_result` directory. Check this folder after a few minutes to confirm that files are being written successfully, indicating that the fuzzer is interacting with the application.
