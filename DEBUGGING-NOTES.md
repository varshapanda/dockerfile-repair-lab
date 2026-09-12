# Dockerfile Repair Debugging Notes

## Project

Dockerfile Repair Lab (LU 4.2)

## Objective

Repair the deliberately broken Dockerfile, resolve all build and runtime failures, optimize Docker layer caching, and verify that the application builds and runs successfully.

---

## Original Problems

The original Dockerfile contained several deliberate failures.

### 1. Invalid Base Image

Original:

```dockerfile
FROM node:notfound