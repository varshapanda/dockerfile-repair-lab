# Dockerfile Repair Lab — Debugging Notes

## 1. Project Overview

**Project:** Dockerfile Repair Lab (LU 4.2)

**Application:** Node.js and Express web application

**Objective:** Diagnose and repair the intentionally broken Dockerfile, fix build-context issues, optimize Docker layer caching, and verify that the containerized application builds and runs successfully.

**Git branch:** `fix/dockerfile-build`

**Final Docker image:** `app:fixed`

**Application port:** `8080`

---

## 2. Reproducing the Original Build Failure

### Command executed

```bash
docker build -t app:broken .
```

### Observed error

```text
ERROR: failed to build: failed to solve:
node:notfound: failed to resolve source metadata
for docker.io/library/node:notfound:
docker.io/library/node:notfound: not found
```

### Root cause

The original Dockerfile started with:

```dockerfile
FROM node:notfound
```

The image tag `node:notfound` was invalid, so Docker could not resolve the base image metadata from Docker Hub. The build failed before Docker could execute the remaining instructions.

### Fix applied

```dockerfile
FROM node:20-alpine
```

The replacement uses a valid Node.js 20 Alpine image. Alpine is a lightweight Linux distribution, which helps keep the base image relatively small.

---

## 3. Problems Identified and Repairs Applied

### Issue 1: Invalid base image

**Break family:** Base image

**Original instruction:**

```dockerfile
FROM node:notfound
```

**Problem:** Docker could not find the requested image tag.

**Repair:**

```dockerfile
FROM node:20-alpine
```

**Result:** Docker successfully resolved the base image.

### Issue 2: Incorrect working directory and instruction ordering

**Break family:** WORKDIR and paths

**Original instructions:**

```dockerfile
COPY . .
WORKDIR /wrong
```

**Problem:** Files were copied before the working directory was set, and the configured directory was incorrect for the intended application structure. This made the build less predictable and harder to maintain.

**Repair:**

```dockerfile
WORKDIR /app
```

The working directory is established before subsequent copy and installation instructions. Relative paths now resolve consistently under `/app`.

### Issue 3: Incorrect dependency installation

**Break family:** Dependencies

**Original instruction:**

```dockerfile
RUN npm install package-lock.json
```

**Problem:** The command incorrectly supplied the lockfile name as an npm install argument rather than installing the project's declared dependencies.

**Repair:**

```dockerfile
COPY package*.json ./
RUN npm install --omit=dev
```

**Result:** Dependencies declared in `package.json`, including Express, were installed successfully.

The `--omit=dev` option excludes development dependencies from the installed production dependency tree.

### Issue 4: Copying a nonexistent folder

**Break family:** Build context and file paths

**Original instruction:**

```dockerfile
COPY missing-folder ./missing-folder
```

**Problem:** The project did not contain the referenced folder. Docker could not copy files that were not present in the build context.

**Repair:** Removed the unnecessary instruction.

The application does not require this folder to start.

### Issue 5: Incorrect startup command

**Break family:** Startup command

**Original instruction:**

```dockerfile
CMD ["npm", "run", "production"]
```

**Problem:** The supplied `package.json` did not define a `production` script. The container would fail to start the application with this command.

**Repair:**

```dockerfile
CMD ["npm", "start"]
```

The existing npm script is:

```json
"scripts": {
  "start": "node app.js"
}
```

**Result:** The application starts using the existing script and listens on port 8080.

### Issue 6: Required source code excluded from the build context

**Break family:** Build context

**Original `.dockerignore` entry:**

```text
src
```

**Problem:** Docker excluded the `src` directory from the build context. When the Dockerfile attempted to copy `src/`, the build failed.

The observed error included:

```text
CopyIgnoredFile: Attempting to Copy file "src"
that is excluded by .dockerignore
```

And:

```text
"/src": not found
```

**Repair:** Removed `src` from `.dockerignore`.

The corrected `.dockerignore` is:

```text
node_modules
npm-debug.log*
.env
.git
.gitignore
.DS_Store
evidence
```

**Result:** Docker successfully copied the application route and utility files into the image.

---

## 4. Final Repaired Dockerfile

```dockerfile
# Use a lightweight, supported Node.js image
FROM node:20-alpine

# Set the correct working directory
WORKDIR /app

# Copy dependency manifests first for better layer caching
COPY package*.json ./

# Install application dependencies
RUN npm install --omit=dev

# Copy application files
COPY app.js ./app.js
COPY src/ ./src/
COPY public/ ./public/

# The application listens on port 8080
EXPOSE 8080

# Start the Express application
CMD ["npm", "start"]
```

---

## 5. Docker Build Optimization

The repaired Dockerfile improves the build process in several ways.

### Dependency layer caching

The dependency manifests are copied before application source files:

```dockerfile
COPY package*.json ./
RUN npm install --omit=dev
```

This allows Docker to reuse the dependency installation layer when the application source changes but the dependency manifests remain unchanged.

### Lightweight base image

```dockerfile
FROM node:20-alpine
```

The Alpine-based Node.js image reduces unnecessary operating-system components compared with many full-sized base images.

### Explicit application file copying

```dockerfile
COPY app.js ./app.js
COPY src/ ./src/
COPY public/ ./public/
```

Only the files and directories required by the application are copied into the image, instead of copying the entire repository indiscriminately.

### Smaller build context

The `.dockerignore` file excludes local dependencies, Git metadata, environment files, logs, and other unnecessary files from the build context.

The required `src` directory is not excluded.

---

## 6. Build Validation

### Command executed

```bash
docker build -t app:fixed .
```

### Observed result

The build completed successfully:

```text
[+] Building 5.3s (12/12) FINISHED
```

The output showed successful completion of the seven Dockerfile build steps, followed by image export and tagging.

The final image was tagged as:

```text
docker.io/library/app:fixed
```

**Validation status:** Successful.

---

## 7. Container Runtime Validation

### Command executed

```bash
docker run -d --name docker-repair-lab -p 8080:8080 app:fixed
```

### Observed result

Docker returned a container ID, indicating that the container was created and started.

The following command was used to verify the running container:

```bash
docker ps
```

Observed status:

```text
STATUS: Up 7 seconds
PORTS: 0.0.0.0:8080->8080/tcp
NAMES: docker-repair-lab
```

**Validation status:** The container was running when checked.

### Startup log validation

Command:

```bash
docker logs docker-repair-lab
```

Observed application log:

```text
> dockerfile-repair-lab@1.0.0 start
> node app.js

Server is running on port 8080
```

**Validation status:** Successful.

---

## 8. API Validation

### Command executed

```bash
curl http://localhost:8080/api/status
```

### Observed response

```json
{
  "status": "ok",
  "timestamp": "2026-10-16T10:07:38.045Z",
  "environment": "development"
}
```

The timestamp above is the observed example response from the test run.

### Result

- The API endpoint responded successfully.
- The returned status was `ok`.
- A timestamp was generated by the application.
- The environment was `development`, consistent with the absence of an explicitly configured `NODE_ENV`.

**Validation status:** Successful.

The web interface should also be checked in a browser at:

http://localhost:8080

Record the browser test as successful after visually confirming that the page loads.

---

## 9. Evidence Collected

The following evidence should be included in the repository after the screenshots have been captured:

```text
evidence/
├── 01-original-build-failure.png
├── 02-successful-build.png
├── 03-running-application.png
└── 04-api-validation.png
```

The evidence demonstrates:

1. The original base-image failure.
2. The successful repaired image build.
3. The running application in the browser.
4. The container or API runtime validation.

Only actual screenshots should be included. The filenames describe the intended evidence and do not imply that screenshots have already been saved.

---

## 10. Git and Pull Request

The work is being completed on:

```text
fix/dockerfile-build
```

The repaired Dockerfile and `.dockerignore` should be committed alongside these debugging notes and the captured evidence.

Recommended commit messages:

```text
fix: repair Dockerfile build failures
fix: include application source in build context
docs: add debugging notes and validation evidence
```

The branch should be pushed to the user's fork, and an open pull request should be created from `fix/dockerfile-build` into the fork's `main` branch.

**Pull request URL:** [Add the actual GitHub PR URL after creating it]

---

## 11. Conclusion

The original Dockerfile failed because of an invalid base image. Additional issues included incorrect working-directory configuration, dependency installation, a nonexistent folder reference, an invalid startup script, and exclusion of required source code from the Docker build context.

The repairs corrected these problems and improved Docker layer caching by installing dependencies before copying application source files.

The repaired image built successfully as `app:fixed`. The container remained running during the validation check, the server started on port 8080, and the `/api/status` endpoint returned a successful response.

The remaining submission tasks are to capture and commit the required screenshots, complete the Git commits, open the public GitHub pull request, and upload the 3–5 minute explanation video to Google Drive.
